-- Enforce authorization permissions at the database boundary.
-- Master Data and User & Role actions now use the same permission model as the UI.

create schema if not exists private;

create or replace function private.has_permission(p_resource_key text, p_permission_key text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select exists (
    select 1
    from public.users u
    join public.roles ro on ro.id = u.role_id
    join public.role_permissions rp on rp.role_id = ro.id
    join public.resources r on r.id = rp.resource_id
    join public.permissions p on p.id = rp.permission_id
    where u.id = auth.uid()
      and u.is_active = true
      and ro.is_active = true
      and r.is_active = true
      and p.key = p_permission_key
      and r.key = p_resource_key
  );
$function$;

revoke all on function private.has_permission(text,text) from public;
grant execute on function private.has_permission(text,text) to authenticated;

revoke execute on function public.has_role(user_role) from anon;

-- Master Data
-- SELECT remains available under the existing dashboard/read model.
-- Mutating operations are now governed by master_data permissions.

drop policy if exists "admin can insert master cards" on public.cards;
drop policy if exists "admin can update master cards" on public.cards;
drop policy if exists "admin can delete master cards" on public.cards;
create policy "master cards insert by permission" on public.cards for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "master cards update by permission" on public.cards for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "master cards delete by permission" on public.cards for delete to authenticated
using ((select private.has_permission('master_data','delete')));

drop policy if exists "admin can insert master vendors" on public.vendors;
drop policy if exists "admin can update master vendors" on public.vendors;
drop policy if exists "admin can delete master vendors" on public.vendors;
create policy "master vendors insert by permission" on public.vendors for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "master vendors update by permission" on public.vendors for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "master vendors delete by permission" on public.vendors for delete to authenticated
using ((select private.has_permission('master_data','delete')));

drop policy if exists "admin can insert master clients" on public.clients;
drop policy if exists "admin can update master clients" on public.clients;
drop policy if exists "admin can delete master clients" on public.clients;
create policy "master clients insert by permission" on public.clients for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "master clients update by permission" on public.clients for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "master clients delete by permission" on public.clients for delete to authenticated
using ((select private.has_permission('master_data','delete')));

drop policy if exists "admin can insert master gates" on public.gates;
drop policy if exists "admin can update master gates" on public.gates;
drop policy if exists "admin can delete master gates" on public.gates;
create policy "master gates insert by permission" on public.gates for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "master gates update by permission" on public.gates for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "master gates delete by permission" on public.gates for delete to authenticated
using ((select private.has_permission('master_data','delete')));

drop policy if exists "admin can insert master line numbers" on public.line_numbers;
drop policy if exists "admin can update master line numbers" on public.line_numbers;
drop policy if exists "admin can delete master line numbers" on public.line_numbers;
create policy "master line numbers insert by permission" on public.line_numbers for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "master line numbers update by permission" on public.line_numbers for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "master line numbers delete by permission" on public.line_numbers for delete to authenticated
using ((select private.has_permission('master_data','delete')));

drop policy if exists "truck_types_authenticated_select" on public.truck_types;
create policy "truck types select by permission" on public.truck_types for select to authenticated
using ((select private.has_permission('master_data','view')));
create policy "truck types insert by permission" on public.truck_types for insert to authenticated
with check ((select private.has_permission('master_data','create')));
create policy "truck types update by permission" on public.truck_types for update to authenticated
using ((select private.has_permission('master_data','update')))
with check ((select private.has_permission('master_data','update')));
create policy "truck types delete by permission" on public.truck_types for delete to authenticated
using ((select private.has_permission('master_data','delete')));

-- User & Role
drop policy if exists "authorization_users_admin" on public.users;
create policy "authorization users select by permission" on public.users for select to authenticated
using ((select private.has_permission('user_role','view')));
create policy "authorization users insert by permission" on public.users for insert to authenticated
with check ((select private.has_permission('user_role','create')));
create policy "authorization users update by permission" on public.users for update to authenticated
using ((select private.has_permission('user_role','update')))
with check ((select private.has_permission('user_role','update')));
create policy "authorization users delete by permission" on public.users for delete to authenticated
using ((select private.has_permission('user_role','delete')));

drop policy if exists "authorization_roles_admin" on public.roles;
create policy "authorization roles select by permission" on public.roles for select to authenticated
using ((select private.has_permission('user_role','view')));
create policy "authorization roles insert by permission" on public.roles for insert to authenticated
with check ((select private.has_permission('user_role','create')));
create policy "authorization roles update by permission" on public.roles for update to authenticated
using ((select private.has_permission('user_role','update')))
with check ((select private.has_permission('user_role','update')));
create policy "authorization roles delete by permission" on public.roles for delete to authenticated
using ((select private.has_permission('user_role','delete')));

drop policy if exists "authorization_resources_admin" on public.resources;
create policy "authorization resources select by permission" on public.resources for select to authenticated
using ((select private.has_permission('user_role','view')));
create policy "authorization resources insert by permission" on public.resources for insert to authenticated
with check ((select private.has_permission('user_role','create')));
create policy "authorization resources update by permission" on public.resources for update to authenticated
using ((select private.has_permission('user_role','update')))
with check ((select private.has_permission('user_role','update')));
create policy "authorization resources delete by permission" on public.resources for delete to authenticated
using ((select private.has_permission('user_role','delete')));

drop policy if exists "authorization_permissions_admin" on public.permissions;
create policy "authorization permissions select by permission" on public.permissions for select to authenticated
using ((select private.has_permission('user_role','view')));
create policy "authorization permissions insert by permission" on public.permissions for insert to authenticated
with check ((select private.has_permission('user_role','create')));
create policy "authorization permissions update by permission" on public.permissions for update to authenticated
using ((select private.has_permission('user_role','update')))
with check ((select private.has_permission('user_role','update')));
create policy "authorization permissions delete by permission" on public.permissions for delete to authenticated
using ((select private.has_permission('user_role','delete')));

drop policy if exists "authorization_role_permissions_admin" on public.role_permissions;
create policy "authorization role permissions select by permission" on public.role_permissions for select to authenticated
using ((select private.has_permission('user_role','view')));
create policy "authorization role permissions insert by permission" on public.role_permissions for insert to authenticated
with check ((select private.has_permission('user_role','update')));
create policy "authorization role permissions update by permission" on public.role_permissions for update to authenticated
using ((select private.has_permission('user_role','update')))
with check ((select private.has_permission('user_role','update')));
create policy "authorization role permissions delete by permission" on public.role_permissions for delete to authenticated
using ((select private.has_permission('user_role','update')));
