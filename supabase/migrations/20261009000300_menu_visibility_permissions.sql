create or replace function public.get_my_menu_permissions()
returns table(resource_key text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct r.key
  from public.users u
  join public.roles ro on ro.id = u.role_id
  join public.role_permissions rp on rp.role_id = ro.id
  join public.resources r on r.id = rp.resource_id
  join public.permissions p on p.id = rp.permission_id
  where u.id = auth.uid()
    and u.is_active = true
    and ro.is_active = true
    and r.is_active = true
    and p.key = 'view';
$$;

revoke all on function public.get_my_menu_permissions() from public, anon;
grant execute on function public.get_my_menu_permissions() to authenticated;