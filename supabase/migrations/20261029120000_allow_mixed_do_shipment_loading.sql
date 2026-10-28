-- Allow one truck visit to link inbound DOs and outbound Shipments from active Plans.
-- Keep client, active-status, unprocessed-item and single-visit safety checks.
create or replace function public.start_loading_visit(
  p_visit_id uuid,
  p_gate_id uuid,
  p_line_number_id uuid,
  p_seal_number text,
  p_notes text,
  p_plan_item_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_visit public.visits%rowtype;
  v_updated_visit_id uuid;
  v_selected_ids uuid[];
  v_valid_count integer;
begin
  if p_gate_id is null or p_line_number_id is null then
    raise exception 'Gerbang dan line wajib dipilih.';
  end if;

  perform 1 from public.gates g where g.id = p_gate_id;
  if not found then raise exception 'Gerbang yang dipilih tidak ditemukan.'; end if;

  perform 1 from public.line_numbers ln
  where ln.id = p_line_number_id and ln.gate_id = p_gate_id;
  if not found then raise exception 'Line tidak ditemukan atau tidak termasuk dalam gerbang yang dipilih.'; end if;

  select * into v_visit from public.visits
  where id = p_visit_id and process_status in ('wh_in', 'queue')
    and wh_in_at is not null and wh_out_at is null
  for update;
  if not found then raise exception 'Status truck berubah atau WH In belum dikonfirmasi.'; end if;

  select coalesce(array_agg(selected.plan_item_id order by selected.plan_item_id), '{}'::uuid[])
  into v_selected_ids
  from (
    select distinct plan_item_id
    from unnest(coalesce(p_plan_item_ids, '{}'::uuid[])) as supplied(plan_item_id)
    where plan_item_id is not null
  ) selected;

  if cardinality(v_selected_ids) <> coalesce(cardinality(p_plan_item_ids), 0) then
    raise exception 'Daftar DO/Shipment mengandung ID kosong atau duplikat.';
  end if;

  if cardinality(v_selected_ids) > 0 then
    perform 1 from public.import_plan_items i
    where i.id = any(v_selected_ids)
    order by i.id
    for update;

    select count(*)::integer into v_valid_count
    from public.import_plan_items i
    join public.import_plans p on p.id = i.plan_id
    where i.id = any(v_selected_ids)
      and p.status = 'active'
      and p.client_id = v_visit.client_id
      and p.activity_type in ('inbound', 'outbound')
      and not coalesce(i.manual_processed, false)
      and not exists (
        select 1 from public.visit_plan_items linked
        where linked.plan_item_id = i.id
      );

    if v_valid_count <> cardinality(v_selected_ids) then
      raise exception 'DO/Shipment tidak aktif, tidak sesuai klien, atau sudah diproses.';
    end if;
  end if;

  update public.visits set gate_id = p_gate_id, line_number_id = p_line_number_id,
    seal_number = nullif(btrim(p_seal_number), ''), notes = nullif(btrim(p_notes), ''),
    process_status = 'started', final_status = 'processing', started_at = now()
  where id = p_visit_id and process_status in ('wh_in', 'queue')
    and wh_in_at is not null and wh_out_at is null
  returning id into v_updated_visit_id;
  if v_updated_visit_id is null then raise exception 'Status truck berubah atau WH In belum dikonfirmasi.'; end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (v_updated_visit_id, 'started', auth.uid());

  insert into public.visit_plan_items (visit_id, plan_item_id, linked_by)
  select v_updated_visit_id, selected.plan_item_id, auth.uid()
  from unnest(v_selected_ids) as selected(plan_item_id);

  return jsonb_build_object(
    'visit_id', v_updated_visit_id,
    'process_status', 'started',
    'linked_plan_items', cardinality(v_selected_ids)
  );
end;
$$;
revoke all on function public.start_loading_visit(uuid, uuid, uuid, text, text, uuid[]) from public;
grant execute on function public.start_loading_visit(uuid, uuid, uuid, text, text, uuid[]) to authenticated;
