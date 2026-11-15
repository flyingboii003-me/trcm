-- Allow authorized Hubungkan Plan users to link active Plan items across activity types.
-- Client ownership, active status, processing state, duplicate links, and visit lifecycle remain enforced.

create or replace function public.manual_link_plan_items(
  p_visit_id uuid,
  p_plan_item_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_visit public.visits%rowtype;
  v_selected_ids uuid[];
  v_valid_count integer;
begin
  if auth.uid() is null or not private.has_permission('hubungkan_plan', 'update') then
    raise exception 'Anda tidak memiliki izin untuk menghubungkan Plan.';
  end if;

  select * into v_visit
  from public.visits
  where id = p_visit_id
    and wh_out_at is null
  for update;

  if not found then
    raise exception 'Armada tidak ditemukan atau sudah WH Out.';
  end if;

  select coalesce(array_agg(selected.plan_item_id order by selected.plan_item_id), '{}'::uuid[])
  into v_selected_ids
  from (
    select distinct supplied.plan_item_id
    from unnest(coalesce(p_plan_item_ids, '{}'::uuid[])) as supplied(plan_item_id)
    where supplied.plan_item_id is not null
  ) selected;

  if cardinality(v_selected_ids) = 0
     or cardinality(v_selected_ids) <> coalesce(cardinality(p_plan_item_ids), 0) then
    raise exception 'Pilih minimal satu DO/Shipment yang valid dan jangan memilih data duplikat.';
  end if;

  perform 1
  from public.import_plan_items i
  where i.id = any(v_selected_ids)
  order by i.id
  for update;

  select count(*)::integer
  into v_valid_count
  from public.import_plan_items i
  join public.import_plans p on p.id = i.plan_id
  where i.id = any(v_selected_ids)
    and p.status = 'active'
    and p.client_id = v_visit.client_id
    and not coalesce(i.manual_processed, false)
    and not exists (
      select 1
      from public.visit_plan_items linked
      where linked.plan_item_id = i.id
    );

  if v_valid_count <> cardinality(v_selected_ids) then
    raise exception 'DO/Shipment tidak aktif, tidak sesuai klien, sudah diproses, atau sudah terhubung ke armada lain.';
  end if;

  insert into public.visit_plan_items (visit_id, plan_item_id, linked_by)
  select p_visit_id, selected.plan_item_id, auth.uid()
  from unnest(v_selected_ids) as selected(plan_item_id);

  return jsonb_build_object(
    'visit_id', p_visit_id,
    'linked_plan_items', cardinality(v_selected_ids)
  );
end;
$$;

revoke all on function public.manual_link_plan_items(uuid, uuid[]) from public, anon;
grant execute on function public.manual_link_plan_items(uuid, uuid[]) to authenticated;
