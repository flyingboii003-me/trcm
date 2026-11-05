-- Allow role keys managed in public.roles to be assigned to user profiles.
-- public.users.role_id is the authorization source of truth; role remains a
-- text compatibility mirror for legacy code paths.

-- These legacy admin-only policies reference users.role and must be recreated
-- after changing the column type.
drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
drop policy if exists import_plan_items_update_permission on public.import_plan_items;
drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
drop policy if exists import_plans_delete_permission on public.import_plans;
drop policy if exists import_plans_update_permission on public.import_plans;

alter table public.users
  alter column role type text
  using role::text;

create or replace function public.has_role(required_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = required_role::text
  );
$function$;

-- Preserve the previous admin-only restrictions using role_id, the canonical
-- role relationship, instead of the compatibility role column.
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (public.is_admin());

create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (public.is_admin());

create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (public.is_admin());

create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (public.is_admin())
with check (public.is_admin());
