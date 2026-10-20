create or replace function public.save_import_plan(
  p_client_id uuid,
  p_operational_date date,
  p_activity_type text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_plan_id uuid;
  v_trip_id uuid;
  v_trip_ids jsonb := '{}'::jsonb;
  v_row jsonb;
  v_key text;
  v_trip_number integer := 0;
  v_row_number integer := 0;
  v_row_count integer;
  v_do text;
  v_shipment text;
  v_vendor text;
  v_plate text;
  v_driver text;
  v_truck_type text;
  v_destination text;
  v_quantity numeric;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not private.has_permission('import_plan', 'create') then
    raise exception 'PERMISSION_DENIED: tidak memiliki izin membuat Plan.';
  end if;
  if p_client_id is null or p_operational_date is null then raise exception 'CLIENT_AND_OPERATIONAL_DATE_REQUIRED'; end if;
  if p_activity_type not in ('inbound', 'outbound') then raise exception 'INVALID_ACTIVITY_TYPE'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then raise exception 'PLAN_ROWS_REQUIRED'; end if;

  v_row_count := jsonb_array_length(p_rows);
  perform pg_advisory_xact_lock(hashtextextended(
    p_client_id::text || '|' || p_operational_date::text || '|' || p_activity_type, 0
  ));

  if exists (
    select 1 from public.import_plans p
    where p.client_id = p_client_id and p.operational_date = p_operational_date
      and p.activity_type = p_activity_type and p.status = 'active'
  ) then
    raise exception using errcode = 'P0001', message = 'PLAN_ACTIVE_EXISTS',
      detail = 'Plan aktif sudah ada untuk klien, tanggal, dan jenis Plan ini. Tidak ada data yang diubah.';
  end if;
  if not exists (select 1 from public.clients c where c.id = p_client_id) then raise exception 'CLIENT_NOT_FOUND'; end if;

  insert into public.import_plans (client_id, operational_date, activity_type, revision, status, row_count, created_by, activated_at)
  values (
    p_client_id, p_operational_date, p_activity_type,
    coalesce((select max(p.revision) + 1 from public.import_plans p
      where p.client_id = p_client_id and p.operational_date = p_operational_date and p.activity_type = p_activity_type), 1),
    'active', v_row_count, auth.uid(), now()
  ) returning id into v_plan_id;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    v_row_number := v_row_number + 1;
    v_do := nullif(btrim(v_row->>'do_number'), '');
    v_shipment := nullif(btrim(v_row->>'shipment_number'), '');
    v_vendor := nullif(btrim(v_row->>'vendor'), '');
    v_plate := nullif(btrim(v_row->>'plate_number'), '');
    v_driver := nullif(btrim(v_row->>'driver_name'), '');
    v_truck_type := nullif(btrim(v_row->>'truck_type'), '');
    v_destination := nullif(btrim(v_row->>'destination'), '');

    if p_activity_type = 'inbound' then
      if v_do is null or nullif(btrim(v_row->>'part_number'), '') is null or nullif(btrim(v_row->>'product_name'), '') is null then
        raise exception 'INBOUND_REQUIRED_FIELDS_MISSING pada baris %.', v_row_number;
      end if;
      v_key := 'inbound|' || upper(regexp_replace(btrim(v_do), E'\\s+', ' ', 'g'));
    else
      if v_vendor is null or v_plate is null or v_driver is null or v_truck_type is null or v_destination is null or v_shipment is null then
        raise exception 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.', v_row_number;
      end if;
      v_key := 'outbound|' ||
        upper(regexp_replace(v_vendor, E'\\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_plate, E'\\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_driver, E'\\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_truck_type, E'\\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_destination, E'\\s+', ' ', 'g'));
    end if;

    if v_row->>'quantity' is null or btrim(v_row->>'quantity') = '' then raise exception 'QUANTITY_REQUIRED pada baris %.', v_row_number; end if;
    v_quantity := (v_row->>'quantity')::numeric;
    if v_quantity <= 0 then raise exception 'QUANTITY_MUST_BE_POSITIVE pada baris %.', v_row_number; end if;

    if v_trip_ids ? v_key then
      v_trip_id := (v_trip_ids->>v_key)::uuid;
    else
      v_trip_number := v_trip_number + 1;
      insert into public.import_plan_trips (plan_id, trip_number, vendor, plate_number, driver_name, truck_type, destination)
      values (v_plan_id, v_trip_number, v_vendor, v_plate, v_driver, v_truck_type, v_destination)
      returning id into v_trip_id;
      v_trip_ids := v_trip_ids || jsonb_build_object(v_key, v_trip_id::text);
    end if;

    insert into public.import_plan_items (plan_id, trip_id, row_number, do_number, shipment_number, part_number, product_name, quantity)
    values (
      v_plan_id, v_trip_id, v_row_number,
      case when p_activity_type = 'inbound' then v_do else null end,
      case when p_activity_type = 'outbound' then v_shipment else null end,
      nullif(btrim(v_row->>'part_number'), ''),
      nullif(btrim(v_row->>'product_name'), ''),
      v_quantity
    );
  end loop;

  return jsonb_build_object('plan_id', v_plan_id, 'client_id', p_client_id,
    'operational_date', p_operational_date, 'activity_type', p_activity_type,
    'status', 'active', 'row_count', v_row_count, 'trip_count', v_trip_number);
end;
$$;
revoke all on function public.save_import_plan(uuid, date, text, jsonb) from public, anon;
grant execute on function public.save_import_plan(uuid, date, text, jsonb) to authenticated;
