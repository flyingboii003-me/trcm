-- Centralized action/button permission RPC for the TRCM frontend.
-- The function returns only the active authenticated user's effective role permissions.

create or replace function public.get_my_permissions()
returns table(resource_key text, permission_key text)
language sql
stable
security definer
set search_path = public
as $function$
  select distinct r.key, p.key
  from public.users u
  join public.roles ro on ro.id = u.role_id
  join public.role_permissions rp on rp.role_id = ro.id
  join public.resources r on r.id = rp.resource_id
  join public.permissions p on p.id = rp.permission_id
  where u.id = auth.uid()
    and auth.uid() is not null
    and u.is_active = true
    and ro.is_active = true
    and r.is_active = true;
$function$;

revoke all on function public.get_my_permissions() from public;
revoke execute on function public.get_my_permissions() from anon;
grant execute on function public.get_my_permissions() to authenticated;

create or replace function public.get_my_menu_permissions()
returns table(resource_key text)
language sql
stable
security definer
set search_path = public
as $function$
  select distinct r.key
  from public.users u
  join public.roles ro on ro.id = u.role_id
  join public.role_permissions rp on rp.role_id = ro.id
  join public.resources r on r.id = rp.resource_id
  join public.permissions p on p.id = rp.permission_id
  where u.id = auth.uid()
    and auth.uid() is not null
    and u.is_active = true
    and ro.is_active = true
    and r.is_active = true
    and p.key = 'view';
$function$;

revoke execute on function public.get_my_menu_permissions() from anon;
grant execute on function public.get_my_menu_permissions() to authenticated;
