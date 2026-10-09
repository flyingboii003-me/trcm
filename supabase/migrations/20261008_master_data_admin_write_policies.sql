-- TRCM Master Data admin write policies
-- Allows authenticated admin users to create, update, and delete master data.
-- Read access remains governed by the existing authenticated SELECT policies.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and role = 'admin'::public.user_role
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

drop policy if exists "admin can insert master cards" on public.cards;
create policy "admin can insert master cards" on public.cards
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update master cards" on public.cards;
create policy "admin can update master cards" on public.cards
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete master cards" on public.cards;
create policy "admin can delete master cards" on public.cards
  for delete to authenticated
  using (public.is_admin());

drop policy if exists "admin can insert master vendors" on public.vendors;
create policy "admin can insert master vendors" on public.vendors
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update master vendors" on public.vendors;
create policy "admin can update master vendors" on public.vendors
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete master vendors" on public.vendors;
create policy "admin can delete master vendors" on public.vendors
  for delete to authenticated
  using (public.is_admin());

drop policy if exists "admin can insert master clients" on public.clients;
create policy "admin can insert master clients" on public.clients
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update master clients" on public.clients;
create policy "admin can update master clients" on public.clients
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete master clients" on public.clients;
create policy "admin can delete master clients" on public.clients
  for delete to authenticated
  using (public.is_admin());

drop policy if exists "admin can insert master gates" on public.gates;
create policy "admin can insert master gates" on public.gates
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update master gates" on public.gates;
create policy "admin can update master gates" on public.gates
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete master gates" on public.gates;
create policy "admin can delete master gates" on public.gates
  for delete to authenticated
  using (public.is_admin());

drop policy if exists "admin can insert master line numbers" on public.line_numbers;
create policy "admin can insert master line numbers" on public.line_numbers
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists "admin can update master line numbers" on public.line_numbers;
create policy "admin can update master line numbers" on public.line_numbers
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "admin can delete master line numbers" on public.line_numbers;
create policy "admin can delete master line numbers" on public.line_numbers
  for delete to authenticated
  using (public.is_admin());
