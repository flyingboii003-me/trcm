-- Plan edits/deletes are admin-only, including direct REST access and the update RPC.
drop policy if exists import_plans_update_permission on public.import_plans;
create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists import_plans_delete_permission on public.import_plans;
create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (public.is_admin());

drop policy if exists import_plan_items_update_permission on public.import_plan_items;
create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (public.is_admin());

drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (public.is_admin());

-- Gate Security cannot change shipment identifiers after WH In until WH Out.
create or replace function public.prevent_gatesec_shipment_changes_before_wh_out()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select r.key into v_role
  from public.users u
  join public.roles r on r.id = u.role_id
  where u.id = auth.uid() and u.is_active = true and r.is_active = true;

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

drop trigger if exists prevent_gatesec_shipment_changes_before_wh_out on public.visits;
create trigger prevent_gatesec_shipment_changes_before_wh_out
before update on public.visits
for each row execute function public.prevent_gatesec_shipment_changes_before_wh_out();
