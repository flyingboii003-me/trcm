-- Enforce Plan/Shipment selection scope on the database side.
-- UI filters are helpful, but RPC callers must not be able to attach another
-- client's/activity's Plan rows or rows already processed by another visit.
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
  v_plan_id uuid;
  v_updated_visit_id uuid;
  v_selected_ids uuid[];
  v_distinct_count integer;
  v_valid_count integer;
begin
  select *
    into v_visit
  from public.visits
  where id = p_visit_id
    and process_status in ('wh_in', 'queue')
    and wh_in_at is not null
    and wh_out_at is null
  for update;

  if not found then
    raise exception 'Status truck berubah atau WH In belum dikonfirmasi.';
  end if;

  select coalesce(array_agg(distinct selected.plan_item_id), '{}'::uuid[]),
         count(distinct selected.plan_item_id)::integer
    into v_selected_ids, v_distinct_count
  from unnest(coalesce(p_plan_item_ids, '{}'::uuid[])) as selected(plan_item_id)
  where selected.plan_item_id is not null;

  if cardinality(v_selected_ids) <> coalesce(cardinality(p_plan_item_ids), 0) then
    raise exception 'Daftar Plan/Shipment mengandung ID kosong atau duplikat.';
  end if;

  if cardinality(v_selected_ids) > 0 then
    -- Serialize attempts to attach the same Plan item to different visits.
    perform 1
    from public.import_plan_items i
    where i.id = any(v_selected_ids)
    order by i.id
    for update;

    select i.plan_id
      into v_plan_id
    from public.import_plan_items i
    join public.import_plans p on p.id = i.plan_id
    where i.id = any(v_selected_ids)
      and p.status = 'active'
      and p.client_id = v_visit.client_id
      and p.activity_type = lower(v_visit.activity_type)
      and not coalesce(i.manual_processed, false)
      and not exists (
        select 1
        from public.visit_plan_items linked
        where linked.plan_item_id = i.id
      )
    order by i.plan_id
    limit 1;

    select count(*)::integer
      into v_valid_count
    from public.import_plan_items i
    join public.import_plans p on p.id = i.plan_id
    where i.id = any(v_selected_ids)
      and p.status = 'active'
      and p.client_id = v_visit.client_id
      and p.activity_type = lower(v_visit.activity_type)
      and not coalesce(i.manual_processed, false)
      and not exists (
        select 1
        from public.visit_plan_items linked
        where linked.plan_item_id = i.id
      );

    if v_valid_count <> cardinality(v_selected_ids) or v_plan_id is null then
      raise exception 'Plan/Shipment tidak aktif, tidak sesuai klien atau aktivitas, atau sudah diproses.';
    end if;

    if exists (
      select 1
      from public.import_plan_items i
      where i.id = any(v_selected_ids)
        and i.plan_id <> v_plan_id
    ) then
      raise exception 'Pilih Shipment dari satu Plan aktif saja.';
    end if;
  end if;

  update public.visits
  set gate_id = p_gate_id,
      line_number_id = p_line_number_id,
      seal_number = nullif(btrim(p_seal_number), ''),
      notes = nullif(btrim(p_notes), ''),
      process_status = 'started',
      final_status = 'processing',
      started_at = now()
  where id = p_visit_id
    and process_status in ('wh_in', 'queue')
    and wh_in_at is not null
    and wh_out_at is null
  returning id into v_updated_visit_id;

  if v_updated_visit_id is null then
    raise exception 'Status truck berubah atau WH In belum dikonfirmasi.';
  end if;

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
