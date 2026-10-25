-- Show linked DO/Shipment and processed status to every role with visit-history access.
drop policy if exists visit_plan_items_select_permission on public.visit_plan_items;
create policy visit_plan_items_select_permission on public.visit_plan_items
for select to authenticated
using (
  private.has_permission('history','view')
  or private.has_permission('import_plan','view')
  or private.has_permission('daftar_plan','view')
  or private.has_permission('start_loading','update')
  or private.has_permission('finish_loading','update')
);

drop policy if exists import_plan_items_select_permission on public.import_plan_items;
create policy import_plan_items_select_permission on public.import_plan_items
for select to authenticated
using (
  exists (
    select 1 from public.import_plans p
    where p.id = import_plan_items.plan_id
      and (
        private.has_permission('import_plan','view')
        or private.has_permission('daftar_plan','view')
        or private.has_permission('history','view')
      )
  )
);

drop policy if exists import_plan_trips_select_permission on public.import_plan_trips;
create policy import_plan_trips_select_permission on public.import_plan_trips
for select to authenticated
using (
  exists (
    select 1 from public.import_plans p
    where p.id = import_plan_trips.plan_id
      and (
        private.has_permission('import_plan','view')
        or private.has_permission('daftar_plan','view')
        or private.has_permission('history','view')
      )
  )
);

drop policy if exists import_plans_select_permission on public.import_plans;
create policy import_plans_select_permission on public.import_plans
for select to authenticated
using (
  private.has_permission('import_plan','view')
  or private.has_permission('daftar_plan','view')
  or private.has_permission('history','view')
);

-- Only admin can update or delete an existing Plan, including direct REST calls.
drop policy if exists import_plans_update_permission on public.import_plans;
create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'))
with check (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

drop policy if exists import_plans_delete_permission on public.import_plans;
create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

drop policy if exists import_plan_items_update_permission on public.import_plan_items;
create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'))
with check (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'))
with check (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (exists (select 1 from public.users u where u.id = auth.uid() and u.is_active and u.role::text = 'admin'));

create or replace function public.prevent_gatesec_shipment_changes_before_wh_out()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select u.role::text into v_role
  from public.users u
  where u.id = auth.uid() and u.is_active = true;

  if v_role = 'gatesec'
     and old.wh_in_at is not null
     and old.wh_out_at is null
     and (
       new.shipment_type is distinct from old.shipment_type
       or new.shipment_number is distinct from old.shipment_number
     ) then
    raise exception 'GATESEC_SHIPMENT_LOCKED_UNTIL_WH_OUT';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_gatesec_shipment_changes_before_wh_out() from public;
drop trigger if exists prevent_gatesec_shipment_changes_before_wh_out on public.visits;
create trigger prevent_gatesec_shipment_changes_before_wh_out
before update on public.visits
for each row execute function public.prevent_gatesec_shipment_changes_before_wh_out();
