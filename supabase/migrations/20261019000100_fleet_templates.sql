create table if not exists public.fleet_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  driver_name text not null,
  driver_phone text,
  plate_number text not null,
  container_num text,
  truck_type text not null,
  vendor text not null,
  client_id uuid references public.clients(id) on delete set null,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fleet_templates_name_idx on public.fleet_templates (name);
create index if not exists fleet_templates_plate_number_idx on public.fleet_templates (plate_number);

alter table public.fleet_templates enable row level security;

insert into public.resources (key, name, type, route, sort_order)
values ('fleet_templates', 'Template Armada', 'action', 'pages/registrasi-armada.html', 35)
on conflict (key) do update set name = excluded.name, type = excluded.type, route = excluded.route;

insert into public.role_permissions (role_id, resource_id, permission_id)
select r.id, res.id, p.id
from public.roles r
cross join public.resources res
cross join public.permissions p
where r.key = 'admin' and res.key = 'fleet_templates'
on conflict do nothing;

insert into public.role_permissions (role_id, resource_id, permission_id)
select r.id, res.id, p.id
from public.roles r
cross join public.resources res
cross join public.permissions p
where r.key = 'gatesec' and res.key = 'fleet_templates' and p.key in ('view', 'create', 'update', 'delete')
on conflict do nothing;

drop policy if exists fleet_templates_select on public.fleet_templates;
create policy fleet_templates_select on public.fleet_templates
for select to authenticated
using (private.has_permission('fleet_templates', 'view'));

drop policy if exists fleet_templates_insert on public.fleet_templates;
create policy fleet_templates_insert on public.fleet_templates
for insert to authenticated
with check (private.has_permission('fleet_templates', 'create'));

drop policy if exists fleet_templates_update on public.fleet_templates;
create policy fleet_templates_update on public.fleet_templates
for update to authenticated
using (private.has_permission('fleet_templates', 'update'))
with check (private.has_permission('fleet_templates', 'update'));

drop policy if exists fleet_templates_delete on public.fleet_templates;
create policy fleet_templates_delete on public.fleet_templates
for delete to authenticated
using (private.has_permission('fleet_templates', 'delete'));

grant select, insert, update, delete on public.fleet_templates to authenticated;
