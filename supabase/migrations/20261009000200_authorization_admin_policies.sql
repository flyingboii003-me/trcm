create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.users u
    join public.roles r on r.id=u.role_id
    where u.id=auth.uid() and u.is_active=true and r.key='admin' and r.is_active=true
  );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

alter table public.users enable row level security;
alter table public.roles enable row level security;
alter table public.resources enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;

drop policy if exists "authorization_users_admin" on public.users;
create policy "authorization_users_admin" on public.users for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authorization_roles_admin" on public.roles;
create policy "authorization_roles_admin" on public.roles for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authorization_resources_admin" on public.resources;
create policy "authorization_resources_admin" on public.resources for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authorization_permissions_admin" on public.permissions;
create policy "authorization_permissions_admin" on public.permissions for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "authorization_role_permissions_admin" on public.role_permissions;
create policy "authorization_role_permissions_admin" on public.role_permissions for all to authenticated using (public.is_admin()) with check (public.is_admin());
