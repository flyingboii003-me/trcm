-- Allow Admin and Gate Security to move WH In/registered visits into queue.
-- The queue_parking.update permission remains required for both roles.

create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $function$
declare
  actor_role_key text;
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
    select ro.key into actor_role_key
    from public.users u
    join public.roles ro on ro.id = u.role_id
    where u.id = auth.uid() and u.is_active = true and ro.is_active = true;

    if coalesce(actor_role_key, '') not in ('gatesec','admin')
       or not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move a registered truck to queue/parking';
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
    select ro.key into actor_role_key
    from public.users u
    join public.roles ro on ro.id = u.role_id
    where u.id = auth.uid() and u.is_active = true and ro.is_active = true;

    if coalesce(actor_role_key, '') not in ('gatesec','admin')
       or not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move a registered truck to queue/parking';
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
$function$;
