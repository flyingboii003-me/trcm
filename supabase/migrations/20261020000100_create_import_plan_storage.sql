-- Penyimpanan Plan terpisah dari lifecycle visits.
create table if not exists public.import_plans (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete restrict,
  operational_date date not null,
  activity_type text not null check (activity_type in ('inbound','outbound')),
  revision integer not null default 1 check (revision > 0),
  status text not null default 'draft' check (status in ('draft','active','superseded','cancelled')),
  row_count integer not null default 0 check (row_count >= 0),
  created_by uuid references public.users(id) on delete set null default auth.uid(),
  activated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (client_id, operational_date, activity_type, revision)
);

create index if not exists import_plans_created_by_idx on public.import_plans (created_by);

create unique index if not exists import_plans_one_active_per_scope
  on public.import_plans (client_id, operational_date, activity_type)
  where status = 'active';

create table if not exists public.import_plan_trips (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.import_plans(id) on delete cascade,
  trip_number integer not null check (trip_number > 0),
  vendor text,
  plate_number text,
  driver_name text,
  truck_type text,
  destination text,
  created_at timestamptz not null default now(),
  unique (plan_id, trip_number),
  unique (id, plan_id)
);

create table if not exists public.import_plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.import_plans(id) on delete cascade,
  trip_id uuid,
  row_number integer not null check (row_number > 0),
  do_number text,
  shipment_number text,
  part_number text,
  product_name text,
  quantity numeric(14,3),
  created_at timestamptz not null default now(),
  check (quantity is null or quantity > 0),
  unique (plan_id, row_number),
  foreign key (trip_id, plan_id)
    references public.import_plan_trips(id, plan_id) on delete restrict
);

create index if not exists import_plan_items_trip_plan_idx on public.import_plan_items (trip_id, plan_id);
create index if not exists import_plan_items_plan_id_idx
  on public.import_plan_items (plan_id);
create index if not exists import_plan_items_shipment_idx
  on public.import_plan_items (plan_id, upper(btrim(shipment_number)))
  where shipment_number is not null and btrim(shipment_number) <> '';

-- Shipment yang sama dalam satu Plan Outbound hanya boleh memiliki kombinasi
-- vendor, plat, dan tujuan yang konsisten. Duplikasi pada kombinasi yang sama
-- tetap disimpan sebagai baris terpisah dan tidak dijumlahkan otomatis.
create or replace function public.validate_import_plan_shipment_trip()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_activity_type text;
  v_vendor text;
  v_plate text;
  v_destination text;
begin
  select p.activity_type, t.vendor, t.plate_number, t.destination
    into v_activity_type, v_vendor, v_plate, v_destination
  from public.import_plans p
  left join public.import_plan_trips t
    on t.id = new.trip_id and t.plan_id = new.plan_id
  where p.id = new.plan_id;

  if v_activity_type = 'outbound'
     and nullif(btrim(new.shipment_number), '') is not null then
    if new.trip_id is null then
      raise exception 'Setiap detail Shipment Outbound harus terkait dengan trip.';
    end if;

    if exists (
      select 1
      from public.import_plan_items other_item
      join public.import_plan_trips other_trip
        on other_trip.id = other_item.trip_id
       and other_trip.plan_id = other_item.plan_id
      where other_item.plan_id = new.plan_id
        and other_item.id is distinct from new.id
        and upper(btrim(other_item.shipment_number)) = upper(btrim(new.shipment_number))
        and (
          upper(btrim(coalesce(other_trip.vendor, ''))) <> upper(btrim(coalesce(v_vendor, '')))
          or upper(btrim(coalesce(other_trip.plate_number, ''))) <> upper(btrim(coalesce(v_plate, '')))
          or upper(btrim(coalesce(other_trip.destination, ''))) <> upper(btrim(coalesce(v_destination, '')))
        )
    ) then
      raise exception 'Shipment yang sama tidak boleh berada pada trip dengan vendor, plat nomor, atau tujuan berbeda dalam satu Plan.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists validate_import_plan_shipment_trip on public.import_plan_items;
create trigger validate_import_plan_shipment_trip
before insert or update of plan_id, trip_id, shipment_number
on public.import_plan_items
for each row execute function public.validate_import_plan_shipment_trip();

create table if not exists public.visit_plan_items (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.visits(id) on delete cascade,
  plan_item_id uuid not null references public.import_plan_items(id) on delete restrict,
  linked_by uuid references public.users(id) on delete set null default auth.uid(),
  linked_at timestamptz not null default now(),
  unique (visit_id, plan_item_id)
);

create index if not exists visit_plan_items_linked_by_idx on public.visit_plan_items (linked_by);
create index if not exists visit_plan_items_visit_id_idx
  on public.visit_plan_items (visit_id);
create index if not exists visit_plan_items_plan_item_id_idx
  on public.visit_plan_items (plan_item_id);

-- Resource permission terpisah agar akses Plan tidak bergantung pada Master Data.
insert into public.resources (key, name, type, route, sort_order, is_active)
values ('import_plan', 'Impor Plan', 'page', 'pages/impor-plan.html', 25, true)
on conflict (key) do update
set name = excluded.name, route = excluded.route, is_active = true;

insert into public.role_permissions (role_id, resource_id, permission_id)
select r.id, res.id, p.id
from public.roles r
join public.resources res on res.key = 'import_plan'
join public.permissions p on p.key in ('view','create','update','delete','upload','export')
where r.key = 'admin'
on conflict do nothing;

insert into public.role_permissions (role_id, resource_id, permission_id)
select r.id, res.id, p.id
from public.roles r
join public.resources res on res.key = 'import_plan'
join public.permissions p on p.key = 'view'
where r.key = 'checker'
on conflict do nothing;

alter table public.import_plans enable row level security;
alter table public.import_plan_trips enable row level security;
alter table public.import_plan_items enable row level security;
alter table public.visit_plan_items enable row level security;

grant select, insert, update, delete on public.import_plans to authenticated;
grant select, insert, update, delete on public.import_plan_trips to authenticated;
grant select, insert, update, delete on public.import_plan_items to authenticated;
grant select, insert, delete on public.visit_plan_items to authenticated;

drop policy if exists import_plans_select_permission on public.import_plans;
create policy import_plans_select_permission on public.import_plans
for select to authenticated
using (private.has_permission('import_plan','view'));

drop policy if exists import_plans_insert_permission on public.import_plans;
create policy import_plans_insert_permission on public.import_plans
for insert to authenticated
with check (private.has_permission('import_plan','create'));

drop policy if exists import_plans_update_permission on public.import_plans;
create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (private.has_permission('import_plan','update'))
with check (private.has_permission('import_plan','update'));

drop policy if exists import_plans_delete_permission on public.import_plans;
create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (private.has_permission('import_plan','delete'));

drop policy if exists import_plan_trips_select_permission on public.import_plan_trips;
create policy import_plan_trips_select_permission on public.import_plan_trips
for select to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','view')
));

drop policy if exists import_plan_trips_insert_permission on public.import_plan_trips;
create policy import_plan_trips_insert_permission on public.import_plan_trips
for insert to authenticated
with check (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','create')
));

drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','update')
))
with check (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','update')
));

drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','delete')
));

drop policy if exists import_plan_items_select_permission on public.import_plan_items;
create policy import_plan_items_select_permission on public.import_plan_items
for select to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','view')
));

drop policy if exists import_plan_items_insert_permission on public.import_plan_items;
create policy import_plan_items_insert_permission on public.import_plan_items
for insert to authenticated
with check (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','create')
));

drop policy if exists import_plan_items_update_permission on public.import_plan_items;
create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','update')
))
with check (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','update')
));

drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (exists (
  select 1 from public.import_plans p where p.id = plan_id
  and private.has_permission('import_plan','delete')
));

drop policy if exists visit_plan_items_select_permission on public.visit_plan_items;
create policy visit_plan_items_select_permission on public.visit_plan_items
for select to authenticated
using (
  private.has_permission('import_plan','view')
  or private.has_permission('start_loading','update')
  or private.has_permission('finish_loading','update')
);

drop policy if exists visit_plan_items_insert_permission on public.visit_plan_items;
create policy visit_plan_items_insert_permission on public.visit_plan_items
for insert to authenticated
with check (
  private.has_permission('start_loading','update')
  and exists (
    select 1 from public.import_plan_items i
    join public.import_plans p on p.id = i.plan_id
    where i.id = plan_item_id and p.status = 'active'
  )
);

drop policy if exists visit_plan_items_delete_permission on public.visit_plan_items;
create policy visit_plan_items_delete_permission on public.visit_plan_items
for delete to authenticated
using (private.has_permission('import_plan','delete'));
