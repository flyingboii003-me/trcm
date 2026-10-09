-- Fix operational UPDATE policy and WH Out event validation.
-- WH Out keeps process_status = completed and is represented by wh_out_at + visit_events.status = wh_out.

drop policy if exists "operational can update visits" on public.visits;

create policy "operational can update visits" on public.visits
for update to authenticated
using (
  (process_status = 'wh_in' and private.has_permission('wh_in','update'))
  or (process_status = 'registered' and (private.has_permission('queue_parking','update') or private.has_permission('start_loading','update')))
  or (process_status = 'queue' and (private.has_permission('queue_parking','update') or private.has_permission('start_loading','update')))
  or (process_status = 'started' and (private.has_permission('start_loading','update') or private.has_permission('finish_loading','update')))
  or (process_status = 'completed' and private.has_permission('wh_out','update'))
)
with check (
  (process_status = 'wh_in' and private.has_permission('wh_in','update'))
  or (process_status = 'registered' and private.has_permission('wh_in','update'))
  or (process_status = 'queue' and (private.has_permission('queue_parking','update') or private.has_permission('start_loading','update')))
  or (process_status = 'started' and private.has_permission('start_loading','update'))
  or (process_status = 'completed' and (private.has_permission('finish_loading','update') or private.has_permission('wh_out','update')))
);

create or replace function private.enforce_visit_event()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  current_status public.process_status_type;
  current_wh_out_at timestamptz;
begin
  select v.process_status, v.wh_out_at
    into current_status, current_wh_out_at
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

  if new.status = 'wh_out' and (current_status <> 'completed' or current_wh_out_at is null) then
    raise exception 'WH Out event does not match visit completion state';
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
$$;
