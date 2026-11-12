-- Hubungkan / putuskan DO atau Shipment secara manual tanpa mengubah lifecycle visit.
create unique index if not exists visit_plan_items_plan_item_id_unique
  on public.visit_plan_items (plan_item_id)
  where plan_item_id is not null;

drop policy if exists visit_plan_items_insert_permission on public.visit_plan_items;
create policy visit_plan_items_insert_permission
on public.visit_plan_items
for insert to authenticated
with check (
  (
    private.has_permission('start_loading', 'update')
    or private.has_permission('daftar_plan', 'update')
  )
  and exists (
    select 1
    from public.visits v
    join public.import_plan_items i on i.id = visit_plan_items.plan_item_id
    join public.import_plans p on p.id = i.plan_id
    where v.id = visit_plan_items.visit_id
      and v.wh_out_at is null
      and p.status = 'active'
      and p.client_id = v.client_id
      and p.activity_type = v.activity_type::text
      and not coalesce(i.manual_processed, false)
  )
);

drop policy if exists visit_plan_items_delete_permission on public.visit_plan_items;
create policy visit_plan_items_delete_permission
on public.visit_plan_items
for delete to authenticated
using (
  private.has_permission('import_plan', 'delete')
  or (
    private.has_permission('daftar_plan', 'update')
    and exists (
      select 1
      from public.visits v
      where v.id = visit_plan_items.visit_id
        and v.wh_out_at is null
    )
  )
);

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

create or replace function public.manual_unlink_plan_item(
  p_visit_id uuid,
  p_plan_item_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $$
declare
  v_visit_id uuid;
  v_deleted_count integer;
begin
  if auth.uid() is null or not private.has_permission('daftar_plan', 'update') then
    raise exception 'Anda tidak memiliki izin untuk memutus hubungan Plan.';
  end if;

  perform 1
  from public.visits
  where id = p_visit_id
    and wh_out_at is null
  for update;

  if not found then
    raise exception 'Armada tidak ditemukan atau sudah WH Out.';
  end if;

  delete from public.visit_plan_items
  where visit_id = p_visit_id
    and plan_item_id = p_plan_item_id;

  get diagnostics v_deleted_count = row_count;
  if v_deleted_count = 0 then
    raise exception 'Hubungan DO/Shipment tidak ditemukan.';
  end if;

  return jsonb_build_object(
    'visit_id', p_visit_id,
    'unlinked_plan_item_id', p_plan_item_id
  );
end;
$$;

revoke all on function public.manual_link_plan_items(uuid, uuid[]) from public, anon;
revoke all on function public.manual_unlink_plan_item(uuid, uuid) from public, anon;
grant execute on function public.manual_link_plan_items(uuid, uuid[]) to authenticated;
grant execute on function public.manual_unlink_plan_item(uuid, uuid) to authenticated;