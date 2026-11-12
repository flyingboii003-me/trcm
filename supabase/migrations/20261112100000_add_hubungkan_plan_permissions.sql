-- Separate Hubungkan Plan authorization from Daftar Plan.
-- Access is managed dynamically through User & Role (resources + role_permissions).

insert into public.roles (key, name, description)
values ('office_admin', 'Admin Office', 'Akses administrasi kantor.')
on conflict (key) do nothing;

insert into public.resources (key, name, type, route, sort_order, is_active)
values ('hubungkan_plan', 'Hubungkan Plan', 'page', 'pages/hubungkan-plan.html', 26, true)
on conflict (key) do update
set name = excluded.name,
    type = excluded.type,
    route = excluded.route,
    sort_order = excluded.sort_order,
    is_active = true;

-- Administrator retains full access to the new resource.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, res.id, p.id
from public.roles ro
cross join public.resources res
cross join public.permissions p
where ro.key = 'admin'
  and res.key = 'hubungkan_plan'
on conflict do nothing;

-- Initial access for Admin Office: view the page and link/unlink Plan items.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, res.id, p.id
from public.roles ro
cross join public.resources res
join public.permissions p on p.key in ('view', 'update')
where ro.key = 'office_admin'
  and res.key = 'hubungkan_plan'
on conflict do nothing;

-- The page reads visits, active Plans, Plan details, and existing links.
drop policy if exists hubungkan_plan_select_visits on public.visits;
create policy hubungkan_plan_select_visits on public.visits
for select to authenticated
using (private.has_permission('hubungkan_plan', 'view'));

drop policy if exists import_plans_select_permission on public.import_plans;
create policy import_plans_select_permission on public.import_plans
for select to authenticated
using (
  private.has_permission('import_plan', 'view')
  or private.has_permission('daftar_plan', 'view')
  or private.has_permission('history', 'view')
  or private.has_permission('hubungkan_plan', 'view')
);

drop policy if exists import_plan_items_select_permission on public.import_plan_items;
create policy import_plan_items_select_permission on public.import_plan_items
for select to authenticated
using (
  exists (
    select 1
    from public.import_plans p
    where p.id = import_plan_items.plan_id
      and (
        private.has_permission('import_plan', 'view')
        or private.has_permission('daftar_plan', 'view')
        or private.has_permission('history', 'view')
        or private.has_permission('hubungkan_plan', 'view')
      )
  )
);

drop policy if exists import_plan_trips_select_permission on public.import_plan_trips;
create policy import_plan_trips_select_permission on public.import_plan_trips
for select to authenticated
using (
  exists (
    select 1
    from public.import_plans p
    where p.id = import_plan_trips.plan_id
      and (
        private.has_permission('import_plan', 'view')
        or private.has_permission('daftar_plan', 'view')
        or private.has_permission('history', 'view')
        or private.has_permission('hubungkan_plan', 'view')
      )
  )
);

drop policy if exists visit_plan_items_select_permission on public.visit_plan_items;
create policy visit_plan_items_select_permission on public.visit_plan_items
for select to authenticated
using (
  private.has_permission('history', 'view')
  or private.has_permission('import_plan', 'view')
  or private.has_permission('daftar_plan', 'view')
  or private.has_permission('start_loading', 'update')
  or private.has_permission('finish_loading', 'update')
  or private.has_permission('hubungkan_plan', 'view')
);

-- The RPCs enforce the dedicated update permission. Keep them SECURITY DEFINER
-- so their scoped row locks work independently of operational UPDATE policies.
create or replace function public.manual_link_plan_items(
  p_visit_id uuid,
  p_plan_item_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, private, pg_temp
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
security definer
set search_path = public, private, pg_temp
as $$
declare
  v_deleted_id uuid;
begin
  if auth.uid() is null or not private.has_permission('hubungkan_plan', 'update') then
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
  where id = p_link_id
    and visit_id = p_visit_id
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'Hubungan DO/Shipment tidak ditemukan.';
  end if;

  return jsonb_build_object('visit_id', p_visit_id, 'unlinked_link_id', v_deleted_id);
end;
$$;

revoke all on function public.manual_link_plan_items(uuid, uuid[]) from public, anon;
revoke all on function public.manual_unlink_plan_link(uuid, uuid) from public, anon;
grant execute on function public.manual_link_plan_items(uuid, uuid[]) to authenticated;
grant execute on function public.manual_unlink_plan_link(uuid, uuid) to authenticated;
