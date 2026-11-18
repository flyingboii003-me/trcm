-- Allow users who can access Daftar Plan to load truck type options
-- in the manual Plan form, without broadening write permissions.
drop policy if exists "truck types select by operational access" on public.truck_types;

create policy "truck types select by operational access"
on public.truck_types
for select
to authenticated
using (
  private.has_permission('master_data', 'view')
  or private.has_permission('wh_in', 'view')
  or private.has_permission('daftar_plan', 'view')
);
