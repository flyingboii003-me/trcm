-- Operational RLS for visits, visit_events and photos.
-- The policies below use the centralized permission matrix and preserve the
-- existing authenticated SELECT behavior for dashboard/history.

drop policy if exists "gatesec and admin can create visits" on public.visits;
drop policy if exists "gatesec and admin can delete visits" on public.visits;
drop policy if exists "gatesec and admin can update visits" on public.visits;
drop policy if exists "checker and admin can update visits" on public.visits;
drop policy if exists "operational can insert visits" on public.visits;
drop policy if exists "operational can update visits" on public.visits;
drop policy if exists "operational can delete visits" on public.visits;

create policy "operational can insert visits" on public.visits
for insert to authenticated
with check ((select private.has_permission('wh_in','create')));

create policy "operational can update visits" on public.visits
for update to authenticated
using (
  (process_status = 'wh_in' and (select private.has_permission('wh_in','update')))
  or
  (process_status = 'registered' and (
    (select private.has_permission('queue_parking','update'))
    or (select private.has_permission('start_loading','update'))
  ))
  or
  (process_status = 'queue' and (
    (select private.has_permission('queue_parking','update'))
    or (select private.has_permission('start_loading','update'))
  ))
  or
  (process_status = 'started' and (
    (select private.has_permission('start_loading','update'))
    or (select private.has_permission('finish_loading','update'))
  ))
  or
  (process_status = 'completed' and (select private.has_permission('wh_out','update')))
)
with check (
  (process_status = 'wh_in' and (select private.has_permission('wh_in','update')))
  or
  (process_status = 'registered' and (select private.has_permission('wh_in','update')))
  or
  (process_status = 'queue' and (select private.has_permission('queue_parking','update')))
  or
  (process_status = 'started' and (select private.has_permission('start_loading','update')))
  or
  (process_status = 'completed' and (select private.has_permission('finish_loading','update')))
);

create policy "operational can delete visits" on public.visits
for delete to authenticated
using (false);

drop policy if exists "checker and admin can create visit events" on public.visit_events;
drop policy if exists "gatesec and admin can create visit events" on public.visit_events;
create policy "operational can create visit events" on public.visit_events
for insert to authenticated
with check (
  (status = 'wh_in' and (select private.has_permission('wh_in','update')))
  or
  (status = 'registered' and (select private.has_permission('wh_in','update')))
  or
  (status = 'parked' and (select private.has_permission('queue_parking','update')))
  or
  (status = 'processing' and (
    (select private.has_permission('queue_parking','update'))
    or (select private.has_permission('start_loading','update'))
  ))
  or
  (status = 'started' and (select private.has_permission('start_loading','update')))
  or
  (status = 'completed' and (select private.has_permission('finish_loading','update')))
  or
  (status = 'wh_out' and (select private.has_permission('wh_out','update')))
);

drop policy if exists "checker and admin can create photo records" on public.photos;
drop policy if exists "checker and admin can delete photo records" on public.photos;
create policy "checker can create photo records by loading permission" on public.photos
for insert to authenticated
with check (
  (select private.has_permission('start_loading','upload'))
  or
  (select private.has_permission('finish_loading','upload'))
);

create policy "checker can delete photo records by loading permission" on public.photos
for delete to authenticated
using (
  (select private.has_permission('start_loading','upload'))
  or
  (select private.has_permission('finish_loading','upload'))
);
