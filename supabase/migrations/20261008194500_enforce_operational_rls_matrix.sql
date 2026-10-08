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

create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  if new.process_status = old.process_status then
    return new;
  end if;

  if old.process_status = 'wh_in' and new.process_status = 'registered' then
    if not (select private.has_permission('wh_in','update')) then
      raise exception 'Not authorized to register this visit';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'queue' then
    if not (select private.has_permission('queue_parking','update')) then
      raise exception 'Not authorized to move this visit to queue/parking';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'started' then
    if not (select private.has_permission('start_loading','update')) then
      raise exception 'Not authorized to bypass queue and start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'queue' and new.process_status = 'started' then
    if not (select private.has_permission('start_loading','update')) then
      raise exception 'Not authorized to start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'started' and new.process_status = 'completed' then
    if not (select private.has_permission('finish_loading','update')) then
      raise exception 'Not authorized to finish loading';
    end if;
    return new;
  end if;

  raise exception 'Invalid visit status transition: % -> %', old.process_status, new.process_status;
end;
$function$;

drop trigger if exists trg_enforce_visit_transition on public.visits;
create trigger trg_enforce_visit_transition
before update of process_status on public.visits
for each row
execute function private.enforce_visit_transition();

create or replace function private.enforce_visit_event()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  current_status public.process_status_type;
begin
  select v.process_status
    into current_status
  from public.visits v
  where v.id = new.visit_id;

  if current_status is null then
    raise exception 'Visit not found for event';
  end if;

  if new.status = 'wh_in' and current_status <> 'wh_in' then
    raise exception 'WH In event does not match visit status';
  end if;

  if new.status = 'registered' and current_status <> 'registered' then
    raise exception 'Registered event does not match visit status';
  end if;

  if new.status = 'parked' and current_status <> 'queue' then
    raise exception 'Parked event does not match visit status';
  end if;

  if new.status = 'processing' and current_status <> 'started' then
    raise exception 'Processing event does not match visit status';
  end if;

  if new.status = 'started' and current_status <> 'started' then
    raise exception 'Started event does not match visit status';
  end if;

  if new.status = 'completed' and current_status <> 'completed' then
    raise exception 'Completed event does not match visit status';
  end if;

  if new.status = 'wh_out' and current_status <> 'completed' then
    raise exception 'WH Out event does not match visit status';
  end if;

  if new.status = 'cancelled' then
    raise exception 'Cancelled events are not allowed through the operational API';
  end if;

  if new.user_id is null then
    new.user_id := auth.uid();
  elsif new.user_id <> auth.uid() then
    raise exception 'Event user_id must match the authenticated user';
  end if;

  return new;
end;
$function$;

drop trigger if exists trg_enforce_visit_event on public.visit_events;
create trigger trg_enforce_visit_event
before insert on public.visit_events
for each row
execute function private.enforce_visit_event();

revoke all on function private.enforce_visit_transition() from public;
grant execute on function private.enforce_visit_transition() to authenticated;
revoke all on function private.enforce_visit_event() from public;
grant execute on function private.enforce_visit_event() to authenticated;
