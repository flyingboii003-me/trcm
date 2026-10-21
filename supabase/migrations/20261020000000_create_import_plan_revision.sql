create or replace function public.create_import_plan_revision(
  p_source_plan_id uuid,
  p_operational_date date
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
declare
  v_source public.import_plans%rowtype;
  v_new_plan_id uuid;
  v_new_trip_id uuid;
  v_trip record;
  v_trip_map jsonb := '{}'::jsonb;
  v_trip_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if not private.has_permission('daftar_plan', 'update')
     or not private.has_permission('import_plan', 'create') then
    raise exception 'PERMISSION_DENIED';
  end if;
  if p_operational_date is null then
    raise exception 'OPERATIONAL_DATE_REQUIRED';
  end if;

  select * into v_source
  from public.import_plans
  where id = p_source_plan_id
  for update;

  if not found then raise exception 'PLAN_NOT_FOUND'; end if;
  if v_source.status <> 'active' then raise exception 'REVISION_SOURCE_MUST_BE_ACTIVE'; end if;

  perform pg_advisory_xact_lock(hashtextextended(
    v_source.client_id::text || '|' || v_source.operational_date::text || '|' || v_source.activity_type, 0
  ));
  perform pg_advisory_xact_lock(hashtextextended(
    v_source.client_id::text || '|' || p_operational_date::text || '|' || v_source.activity_type, 0
  ));

  if exists (
    select 1
    from public.visit_plan_items vpi
    join public.import_plan_items i on i.id = vpi.plan_item_id
    where i.plan_id = v_source.id
  ) then
    raise exception 'PLAN_HAS_VISIT_LINKS';
  end if;

  if exists (
    select 1 from public.import_plans p
    where p.client_id = v_source.client_id
      and p.operational_date = p_operational_date
      and p.activity_type = v_source.activity_type
      and p.status = 'active'
      and p.id <> v_source.id
  ) then
    raise exception 'PLAN_ACTIVE_EXISTS';
  end if;

  -- Supersede the source in the same transaction before creating its replacement.
  update public.import_plans
  set status = 'superseded', updated_at = now()
  where id = v_source.id and status = 'active';

  insert into public.import_plans (
    client_id, operational_date, activity_type, revision, status, row_count, created_by, activated_at
  )
  values (
    v_source.client_id, p_operational_date, v_source.activity_type,
    coalesce((
      select max(p.revision) + 1 from public.import_plans p
      where p.client_id = v_source.client_id
        and p.operational_date = p_operational_date
        and p.activity_type = v_source.activity_type
    ), 1),
    'active', v_source.row_count, auth.uid(), now()
  )
  returning id into v_new_plan_id;

  for v_trip in
    select * from public.import_plan_trips
    where plan_id = v_source.id
    order by trip_number
  loop
    insert into public.import_plan_trips (
      plan_id, trip_number, vendor, plate_number, driver_name, truck_type, destination
    )
    values (
      v_new_plan_id, v_trip.trip_number, v_trip.vendor, v_trip.plate_number,
      v_trip.driver_name, v_trip.truck_type, v_trip.destination
    )
    returning id into v_new_trip_id;

    v_trip_map := jsonb_set(v_trip_map, array[v_trip.id::text], to_jsonb(v_new_trip_id::text), true);
    v_trip_count := v_trip_count + 1;
  end loop;

  insert into public.import_plan_items (
    plan_id, trip_id, row_number, do_number, shipment_number, part_number, product_name, quantity
  )
  select
    v_new_plan_id,
    case when i.trip_id is null then null else (v_trip_map->>i.trip_id::text)::uuid end,
    i.row_number, i.do_number, i.shipment_number, i.part_number, i.product_name, i.quantity
  from public.import_plan_items i
  where i.plan_id = v_source.id
  order by i.row_number;

  return jsonb_build_object(
    'source_plan_id', v_source.id,
    'plan_id', v_new_plan_id,
    'client_id', v_source.client_id,
    'operational_date', p_operational_date,
    'activity_type', v_source.activity_type,
    'revision', (select revision from public.import_plans where id = v_new_plan_id),
    'status', 'active',
    'row_count', v_source.row_count,
    'trip_count', v_trip_count
  );
end;
$function$;

revoke all on function public.create_import_plan_revision(uuid, date) from public, anon;
grant execute on function public.create_import_plan_revision(uuid, date) to authenticated;
