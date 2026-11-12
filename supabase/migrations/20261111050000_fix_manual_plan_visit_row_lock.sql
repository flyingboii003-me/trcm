-- Allow manual Plan linking/unlinking without requiring operational UPDATE access on visits.
-- FOR SHARE keeps the visit row stable against concurrent WH Out updates while relying on SELECT RLS.

create or replace function public.manual_link_plan_items(
  p_visit_id uuid,
  p_plan_item_ids uuid[]
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $$
declare
  v_visit public.visits%rowtype;
  v_selected_ids uuid[];
  v_valid_count integer;
begin
  if auth.uid() is null or not private.has_permission('daftar_plan', 'update') then
    raise exception 'Anda tidak memiliki izin untuk menghubungkan Plan.';
  end if;

  select * into v_visit
  from public.visits
  where id = p_visit_id
    and wh_out_at is null
  for share;

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
    and p.activity_type = v_visit.activity_type::text
    and not coalesce(i.manual_processed, false)
    and not exists (
      select 1
      from public.visit_plan_items linked
      where linked.plan_item_id = i.id
    );

  if v_valid_count <> cardinality(v_selected_ids) then
    raise exception 'DO/Shipment tidak aktif, tidak sesuai klien atau aktivitas, sudah diproses, atau sudah terhubung ke armada lain.';
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

create or replace function public.manual_unlink_plan_link(
  p_visit_id uuid,
  p_link_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $$
declare
  v_deleted_id uuid;
begin
  if auth.uid() is null or not private.has_permission('daftar_plan', 'update') then
    raise exception 'Anda tidak memiliki izin untuk memutus hubungan Plan.';
  end if;

  perform 1
  from public.visits
  where id = p_visit_id
    and wh_out_at is null
  for share;

  if not found then
    raise exception 'Armada tidak ditemukan atau sudah WH Out.';
  end if;

  delete from public.visit_plan_items
  where id = p_link_id
    and visit_id = p_visit_id
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'Hubungan DO/Shipment tidak ditemukan.';
  end if;

  return jsonb_build_object('visit_id', p_visit_id, 'unlinked_link_id', v_deleted_id);
end;
$$;
