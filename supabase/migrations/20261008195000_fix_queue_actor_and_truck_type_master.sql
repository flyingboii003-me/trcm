-- Restrict WH In -> queue/parking to Gate Security and allow operational
-- registration forms to read active truck types.

drop policy if exists "truck types select by permission" on public.truck_types;

create policy "truck types select by operational access" on public.truck_types
for select to authenticated
using (
  private.has_permission('master_data','view')
  or private.has_permission('wh_in','view')
);

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
    if not exists (
      select 1
      from public.users u
      join public.roles ro on ro.id = u.role_id
      where u.id = auth.uid()
        and u.is_active = true
        and ro.is_active = true
        and ro.key = 'gatesec'
    ) or not private.has_permission('queue_parking','update') then
      raise exception 'Only Gate Security can move a registered truck to queue/parking';
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
    if not exists (
      select 1
      from public.users u
      join public.roles ro on ro.id = u.role_id
      where u.id = auth.uid()
        and u.is_active = true
        and ro.is_active = true
        and ro.key = 'gatesec'
    ) or not private.has_permission('queue_parking','update') then
      raise exception 'Only Gate Security can move a registered visit to queue/parking';
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
