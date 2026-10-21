-- Gunakan permission resource Daftar Plan untuk perubahan dari halaman daftar.
drop policy if exists import_plans_update_permission on public.import_plans;
create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (private.has_permission('daftar_plan','update'))
with check (private.has_permission('daftar_plan','update'));

drop policy if exists import_plans_delete_permission on public.import_plans;
create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (private.has_permission('daftar_plan','delete'));

drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','update')))
with check (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','update')));

drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','delete')));

drop policy if exists import_plan_items_update_permission on public.import_plan_items;
create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','update')))
with check (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','update')));

drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (exists(select 1 from public.import_plans p where p.id=plan_id and private.has_permission('daftar_plan','delete')));