-- Allow the actual operational workflow to move directly from wh_in.
-- Gate Security may move wh_in -> queue or bypass queue -> started.
-- Existing registered transitions remain supported for compatibility.

create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $$
begin
  if new.process_status = old.process_status then
    return new;
  end if;

  if old.process_status = 'wh_in' and new.process_status = 'registered' then
    if not private.has_permission('wh_in','update') then
      raise exception 'Not authorized to register this visit';
    end if;
    return new;
  end if;

  if old.process_status = 'wh_in' and new.process_status = 'queue' then
    if not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move this visit to queue/parking';
    end if;
    return new;
  end if;

  if old.process_status = 'wh_in' and new.process_status = 'started' then
    if not private.has_permission('start_loading','update') then
      raise exception 'Not authorized to bypass queue and start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'queue' then
    if not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move this visit to queue/parking';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'started' then
    if not private.has_permission('start_loading','update') then
      raise exception 'Not authorized to bypass queue and start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'queue' and new.process_status = 'started' then
    if not private.has_permission('start_loading','update') then
      raise exception 'Not authorized to start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'started' and new.process_status = 'completed' then
    if not private.has_permission('finish_loading','update') then
      raise exception 'Not authorized to finish loading';
    end if;
    return new;
  end if;

  raise exception 'Invalid visit status transition: % -> %', old.process_status, new.process_status;
end;
$$;
