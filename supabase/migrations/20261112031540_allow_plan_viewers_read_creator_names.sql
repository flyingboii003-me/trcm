-- Allow users who can view imported Plans to read the display names
-- of the users who created those Plans. Keep access limited to plan creators.
drop policy if exists "users select plan creators by import plan permission" on public.users;
create policy "users select plan creators by import plan permission"
on public.users
for select
to authenticated
using (
  private.has_permission('import_plan', 'view')
  and exists (
    select 1
    from public.import_plans p
    where p.created_by = users.id
  )
);
