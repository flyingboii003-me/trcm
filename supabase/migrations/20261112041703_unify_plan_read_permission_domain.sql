-- Introduce a single data permission for reading the complete Plan domain.
-- Importer identity remains part of plan_data; no plan_creator_data resource is created.

begin;

-- Extend the resource taxonomy without changing existing page/action resources.
alter table public.resources
  drop constraint if exists resources_type_check;

alter table public.resources
  add constraint resources_type_check
  check (type = any (array['page'::text, 'action'::text, 'data'::text]));

insert into public.resources (key, name, description, type, sort_order, is_active)
values (
  'plan_data',
  'Data Plan',
  'Akses baca domain Plan: header, item, trip, dan metadata importer.',
  'data',
  0,
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  type = 'data',
  is_active = true,
  updated_at = now();

-- Preserve existing Plan-read capability: every role that currently has view
-- access through one of the legacy Plan-related page permissions receives
-- plan_data.view. This does not grant any page permission or write operation.
insert into public.role_permissions (role_id, resource_id, permission_id)
select distinct
  rp.role_id,
  plan_resource.id,
  view_permission.id
from public.role_permissions rp
join public.resources legacy_resource
  on legacy_resource.id = rp.resource_id
join public.permissions legacy_permission
  on legacy_permission.id = rp.permission_id
join public.resources plan_resource
  on plan_resource.key = 'plan_data'
join public.permissions view_permission
  on view_permission.key = 'view'
where legacy_permission.key = 'view'
  and legacy_resource.key in ('import_plan', 'daftar_plan', 'history', 'hubungkan_plan')
on conflict (role_id, resource_id, permission_id) do nothing;

-- Replace page-permission-based Plan reads with the single domain permission.
drop policy if exists import_plans_select_permission on public.import_plans;
create policy import_plans_select_permission
on public.import_plans
for select
to authenticated
using (private.has_permission('plan_data', 'view'));

drop policy if exists import_plan_items_select_permission on public.import_plan_items;
create policy import_plan_items_select_permission
on public.import_plan_items
for select
to authenticated
using (
  exists (
    select 1
    from public.import_plans p
    where p.id = import_plan_items.plan_id
      and private.has_permission('plan_data', 'view')
  )
);

drop policy if exists import_plan_trips_select_permission on public.import_plan_trips;
create policy import_plan_trips_select_permission
on public.import_plan_trips
for select
to authenticated
using (
  exists (
    select 1
    from public.import_plans p
    where p.id = import_plan_trips.plan_id
      and private.has_permission('plan_data', 'view')
  )
);

-- Importer profile rows follow the same Plan data permission and are limited
-- to users who created at least one Plan. No separate creator permission.
drop policy if exists "users select plan creators by import plan permission" on public.users;
create policy "users select plan creators by plan data permission"
on public.users
for select
to authenticated
using (
  private.has_permission('plan_data', 'view')
  and exists (
    select 1
    from public.import_plans p
    where p.created_by = users.id
  )
);

commit;
