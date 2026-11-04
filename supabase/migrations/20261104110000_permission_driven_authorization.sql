-- Replace role-name authorization with resource/action permissions.
-- The permission helper checks active user, role, resource, and assigned action.

drop policy if exists import_plans_update_permission on public.import_plans;
create policy import_plans_update_permission on public.import_plans
for update to authenticated
using (private.has_permission('daftar_plan', 'update'))
with check (private.has_permission('daftar_plan', 'update'));

drop policy if exists import_plans_delete_permission on public.import_plans;
create policy import_plans_delete_permission on public.import_plans
for delete to authenticated
using (
  private.has_permission('daftar_plan', 'update')
  or private.has_permission('daftar_plan', 'delete')
);

drop policy if exists import_plan_items_update_permission on public.import_plan_items;
create policy import_plan_items_update_permission on public.import_plan_items
for update to authenticated
using (private.has_permission('daftar_plan', 'update'))
with check (private.has_permission('daftar_plan', 'update'));

drop policy if exists import_plan_items_delete_permission on public.import_plan_items;
create policy import_plan_items_delete_permission on public.import_plan_items
for delete to authenticated
using (private.has_permission('daftar_plan', 'delete'));

drop policy if exists import_plan_trips_update_permission on public.import_plan_trips;
create policy import_plan_trips_update_permission on public.import_plan_trips
for update to authenticated
using (private.has_permission('daftar_plan', 'update'))
with check (private.has_permission('daftar_plan', 'update'));

drop policy if exists import_plan_trips_delete_permission on public.import_plan_trips;
create policy import_plan_trips_delete_permission on public.import_plan_trips
for delete to authenticated
using (private.has_permission('daftar_plan', 'delete'));

-- Queue transitions are controlled by queue_parking.update, not role keys.
create or replace function private.enforce_visit_transition()
returns trigger
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
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
    if old.wh_in_at is null or new.wh_in_at is null then
      raise exception 'WH In must be confirmed before moving a truck to queue/parking';
    end if;
    if not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move a registered truck to queue/parking';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'queue' then
    if old.wh_in_at is null or new.wh_in_at is null then
      raise exception 'WH In must be confirmed before moving a truck to queue/parking';
    end if;
    if not private.has_permission('queue_parking','update') then
      raise exception 'Not authorized to move a registered truck to queue/parking';
    end if;
    return new;
  end if;

  if old.process_status = 'registered' and new.process_status = 'started' then
    raise exception 'WH In must be confirmed before starting loading';
  end if;

  if old.process_status = 'wh_in' and new.process_status = 'started' then
    if old.wh_in_at is null or new.wh_in_at is null then
      raise exception 'WH In must be confirmed before starting loading';
    end if;
    if not private.has_permission('start_loading','update') then
      raise exception 'Not authorized to bypass queue and start loading';
    end if;
    return new;
  end if;

  if old.process_status = 'queue' and new.process_status = 'started' then
    if old.wh_in_at is null or new.wh_in_at is null then
      raise exception 'WH In must be confirmed before starting loading';
    end if;
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
