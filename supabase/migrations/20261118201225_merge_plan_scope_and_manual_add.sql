-- Gabungkan Plan Kimberly Clark 17 Nov 2026 yang sudah memiliki relasi Visit,
-- lalu sediakan satu jalur append atomik untuk impor dan penambahan manual.
begin;

do $merge_legacy_plan$
declare
  v_client_id uuid;
  v_canonical_id uuid;
  v_source_id uuid;
  v_active_count integer;
  v_canonical_rows integer;
  v_source_rows integer;
  v_trip_offset integer;
  v_item_offset integer;
  v_link_count_before integer;
  v_link_count_after integer;
begin
  select c.id into v_client_id
  from public.clients c
  where lower(btrim(c.name)) = lower('Kimberly Clark');

  if v_client_id is null then
    raise exception 'KIMBERLY_CLARK_CLIENT_NOT_FOUND';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    v_client_id::text || '|2026-11-17|inbound', 0
  ));

  select count(*)::integer into v_active_count
  from public.import_plans p
  where p.client_id = v_client_id
    and p.operational_date = date '2026-11-17'
    and p.activity_type = 'inbound'
    and p.status = 'active';

  if v_active_count = 0 then
    -- Aman untuk deployment ulang setelah data sudah direkonsiliasi.
    return;
  end if;

  if v_active_count <> 2 then
    raise exception 'KIMBERLY_CLARK_PLAN_SCOPE_EXPECTED_TWO_ACTIVE_PLANS_FOUND_%', v_active_count;
  end if;

  select p.id, p.row_count into v_canonical_id, v_canonical_rows
  from public.import_plans p
  where p.client_id = v_client_id
    and p.operational_date = date '2026-11-17'
    and p.activity_type = 'inbound'
    and p.status = 'active'
  order by p.created_at asc, p.id asc
  limit 1;

  select p.id, p.row_count into v_source_id, v_source_rows
  from public.import_plans p
  where p.client_id = v_client_id
    and p.operational_date = date '2026-11-17'
    and p.activity_type = 'inbound'
    and p.status = 'active'
    and p.id <> v_canonical_id
  order by p.created_at asc, p.id asc
  limit 1;

  select count(*)::integer into v_link_count_before
  from public.visit_plan_items vpi
  join public.import_plan_items i on i.id = vpi.plan_item_id
  where i.plan_id in (v_canonical_id, v_source_id);

  select coalesce(max(t.trip_number), 0)::integer into v_trip_offset
  from public.import_plan_trips t
  where t.plan_id = v_canonical_id;

  select coalesce(max(i.row_number), 0)::integer into v_item_offset
  from public.import_plan_items i
  where i.plan_id = v_canonical_id;

  create temporary table _trcm_plan_item_trip_map on commit drop as
  select i.id as item_id, i.trip_id as source_trip_id, i.row_number as source_row_number
  from public.import_plan_items i
  where i.plan_id = v_source_id;

  -- Lepaskan sementara FK komposit (trip_id, plan_id), tanpa mengubah ID item.
  update public.import_plan_items
  set trip_id = null
  where plan_id = v_source_id;

  update public.import_plan_items
  set plan_id = v_canonical_id,
      row_number = row_number + v_item_offset
  where plan_id = v_source_id;

  update public.import_plan_trips
  set plan_id = v_canonical_id,
      trip_number = trip_number + v_trip_offset
  where plan_id = v_source_id;

  update public.import_plan_items i
  set trip_id = m.source_trip_id
  from _trcm_plan_item_trip_map m
  where i.id = m.item_id;

  update public.import_plans
  set row_count = v_canonical_rows + v_source_rows,
      updated_at = now()
  where id = v_canonical_id;

  -- Header lama tetap disimpan untuk audit; seluruh trip dan item sudah dipindah.
  update public.import_plans
  set status = 'cancelled',
      row_count = 0,
      updated_at = now()
  where id = v_source_id;

  select count(*)::integer into v_link_count_after
  from public.visit_plan_items vpi
  join public.import_plan_items i on i.id = vpi.plan_item_id
  where i.plan_id = v_canonical_id;

  if v_link_count_after <> v_link_count_before then
    raise exception 'PLAN_VISIT_LINK_COUNT_CHANGED_DURING_MERGE';
  end if;

  if (select count(*) from public.import_plan_items where plan_id = v_canonical_id) <> v_canonical_rows + v_source_rows then
    raise exception 'PLAN_ITEM_COUNT_MISMATCH_AFTER_MERGE';
  end if;
end;
$merge_legacy_plan$;

create or replace function public.add_manual_plan_rows(
  p_client_id uuid,
  p_operational_date date,
  p_activity_type text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $function$
declare
  v_plan_id uuid;
  v_plan_count integer;
  v_row jsonb;
  v_do text;
  v_shipment text;
  v_vendor text;
  v_plate text;
  v_driver text;
  v_truck_type text;
  v_destination text;
  v_trip_id uuid;
  v_trip_key text;
  v_added_rows integer := 0;
  v_new_trips integer := 0;
  v_next_row_number integer;
  v_next_trip_number integer;
  v_total_rows integer;
  v_total_trips integer;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED';
  end if;
  if not private.has_permission('import_plan', 'create') then
    raise exception 'PERMISSION_DENIED: tidak memiliki izin membuat atau menambahkan Plan.';
  end if;
  if p_client_id is null or p_operational_date is null then
    raise exception 'CLIENT_AND_OPERATIONAL_DATE_REQUIRED';
  end if;
  if p_activity_type not in ('inbound', 'outbound') then
    raise exception 'INVALID_ACTIVITY_TYPE';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'PLAN_ROWS_REQUIRED';
  end if;
  if not exists (select 1 from public.clients c where c.id = p_client_id) then
    raise exception 'CLIENT_NOT_FOUND';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(
    p_client_id::text || '|' || p_operational_date::text || '|' || p_activity_type, 0
  ));

  select count(*)::integer
  into v_plan_count
  from public.import_plans p
  where p.client_id = p_client_id
    and p.operational_date = p_operational_date
    and p.activity_type = p_activity_type
    and p.status = 'active';

  if v_plan_count = 1 then
    select p.id into v_plan_id
    from public.import_plans p
    where p.client_id = p_client_id
      and p.operational_date = p_operational_date
      and p.activity_type = p_activity_type
      and p.status = 'active'
    order by p.created_at asc, p.id asc
    limit 1;
  end if;

  if v_plan_count > 1 then
    raise exception using
      errcode = 'P0001',
      message = 'PLAN_SCOPE_AMBIGUOUS',
      detail = 'Terdapat lebih dari satu Plan aktif pada klien, tanggal operasional, dan aktivitas ini. Gabungkan Plan terlebih dahulu.';
  end if;

  -- Validasi duplikasi di dalam kiriman sebelum menulis data.
  if p_activity_type = 'inbound' then
    if exists (
      select 1
      from jsonb_array_elements(p_rows) incoming(value)
      group by upper(regexp_replace(btrim(incoming.value->>'do_number'), '\s+', ' ', 'g'))
      having nullif(upper(regexp_replace(btrim(incoming.value->>'do_number'), '\s+', ' ', 'g')), '') is null
         or count(*) > 1
    ) then
      raise exception 'PLAN_DO_DUPLICATE_IN_REQUEST';
    end if;
    if exists (
      select 1
      from jsonb_array_elements(p_rows) incoming(value)
      join public.import_plan_items i on i.plan_id = v_plan_id
      where v_plan_id is not null
        and nullif(btrim(incoming.value->>'do_number'), '') is not null
        and upper(regexp_replace(btrim(i.do_number), '\s+', ' ', 'g')) =
            upper(regexp_replace(btrim(incoming.value->>'do_number'), '\s+', ' ', 'g'))
    ) then
      raise exception using errcode = 'P0001', message = 'PLAN_DO_EXISTS',
        detail = 'Nomor DO sudah digunakan pada Plan aktif untuk klien dan tanggal ini.';
    end if;
  else
    if exists (
      select 1
      from jsonb_array_elements(p_rows) incoming(value)
      group by upper(regexp_replace(btrim(incoming.value->>'shipment_number'), '\s+', ' ', 'g'))
      having nullif(upper(regexp_replace(btrim(incoming.value->>'shipment_number'), '\s+', ' ', 'g')), '') is null
         or count(*) > 1
    ) then
      raise exception 'PLAN_SHIPMENT_DUPLICATE_IN_REQUEST';
    end if;
    if exists (
      select 1
      from jsonb_array_elements(p_rows) incoming(value)
      join public.import_plan_items i on i.plan_id = v_plan_id
      where v_plan_id is not null
        and nullif(btrim(incoming.value->>'shipment_number'), '') is not null
        and upper(regexp_replace(btrim(i.shipment_number), '\s+', ' ', 'g')) =
            upper(regexp_replace(btrim(incoming.value->>'shipment_number'), '\s+', ' ', 'g'))
    ) then
      raise exception using errcode = 'P0001', message = 'PLAN_SHIPMENT_EXISTS',
        detail = 'Nomor Shipment sudah digunakan pada Plan aktif untuk klien dan tanggal ini.';
    end if;
  end if;

  if v_plan_id is null then
    insert into public.import_plans (
      client_id, operational_date, activity_type, status, row_count, created_by, activated_at
    ) values (
      p_client_id, p_operational_date, p_activity_type, 'active', 0, auth.uid(), now()
    ) returning id into v_plan_id;
  end if;

  select coalesce(max(i.row_number), 0) + 1
  into v_next_row_number
  from public.import_plan_items i
  where i.plan_id = v_plan_id;

  select coalesce(max(t.trip_number), 0) + 1
  into v_next_trip_number
  from public.import_plan_trips t
  where t.plan_id = v_plan_id;

  for v_row in select value from jsonb_array_elements(p_rows)
  loop
    v_do := nullif(btrim(v_row->>'do_number'), '');
    v_shipment := nullif(btrim(v_row->>'shipment_number'), '');
    v_vendor := nullif(btrim(v_row->>'vendor'), '');
    v_plate := nullif(btrim(v_row->>'plate_number'), '');
    v_driver := nullif(btrim(v_row->>'driver_name'), '');
    v_truck_type := nullif(btrim(v_row->>'truck_type'), '');
    v_destination := nullif(btrim(coalesce(v_row->>'destination', v_row->>'destination_city')), '');

    if p_activity_type = 'inbound' then
      if v_do is null then
        raise exception 'INBOUND_DO_REQUIRED pada baris %.', v_added_rows + 1;
      end if;

      insert into public.import_plan_trips (
        plan_id, trip_number, vendor, plate_number, driver_name, truck_type, destination
      ) values (
        v_plan_id, v_next_trip_number, null, null, null, null, null
      ) returning id into v_trip_id;

      v_next_trip_number := v_next_trip_number + 1;
      v_new_trips := v_new_trips + 1;
    else
      if v_vendor is null or v_plate is null or v_driver is null
         or v_truck_type is null or v_destination is null or v_shipment is null then
        raise exception 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.', v_added_rows + 1;
      end if;

      v_trip_key :=
        upper(regexp_replace(v_vendor, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_plate, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_driver, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_truck_type, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_destination, '\s+', ' ', 'g'));

      select t.id into v_trip_id
      from public.import_plan_trips t
      where t.plan_id = v_plan_id
        and upper(regexp_replace(btrim(coalesce(t.vendor, '')), '\s+', ' ', 'g')) = upper(regexp_replace(v_vendor, '\s+', ' ', 'g'))
        and upper(regexp_replace(btrim(coalesce(t.plate_number, '')), '\s+', ' ', 'g')) = upper(regexp_replace(v_plate, '\s+', ' ', 'g'))
        and upper(regexp_replace(btrim(coalesce(t.driver_name, '')), '\s+', ' ', 'g')) = upper(regexp_replace(v_driver, '\s+', ' ', 'g'))
        and upper(regexp_replace(btrim(coalesce(t.truck_type, '')), '\s+', ' ', 'g')) = upper(regexp_replace(v_truck_type, '\s+', ' ', 'g'))
        and upper(regexp_replace(btrim(coalesce(t.destination, '')), '\s+', ' ', 'g')) = upper(regexp_replace(v_destination, '\s+', ' ', 'g'))
      order by t.trip_number
      limit 1;

      if v_trip_id is null then
        insert into public.import_plan_trips (
          plan_id, trip_number, vendor, plate_number, driver_name, truck_type, destination
        ) values (
          v_plan_id, v_next_trip_number, v_vendor, v_plate, v_driver, v_truck_type, v_destination
        ) returning id into v_trip_id;
        v_next_trip_number := v_next_trip_number + 1;
        v_new_trips := v_new_trips + 1;
      end if;
    end if;

    insert into public.import_plan_items (
      plan_id, trip_id, row_number, do_number, shipment_number
    ) values (
      v_plan_id, v_trip_id, v_next_row_number,
      case when p_activity_type = 'inbound' then v_do else null end,
      case when p_activity_type = 'outbound' then v_shipment else null end
    );

    v_next_row_number := v_next_row_number + 1;
    v_added_rows := v_added_rows + 1;
  end loop;

  update public.import_plans
  set row_count = row_count + v_added_rows,
      updated_at = now()
  where id = v_plan_id
  returning row_count into v_total_rows;

  select count(*)::integer into v_total_trips
  from public.import_plan_trips t
  where t.plan_id = v_plan_id;

  return jsonb_build_object(
    'plan_id', v_plan_id,
    'client_id', p_client_id,
    'operational_date', p_operational_date,
    'activity_type', p_activity_type,
    'status', 'active',
    'added_row_count', v_added_rows,
    'row_count', v_total_rows,
    'added_trip_count', v_new_trips,
    'trip_count', v_total_trips
  );
end;
$function$;

create or replace function public.save_import_plan(
  p_client_id uuid,
  p_operational_date date,
  p_activity_type text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $function$
begin
  return public.add_manual_plan_rows(
    p_client_id,
    p_operational_date,
    p_activity_type,
    p_rows
  );
end;
$function$;

revoke all on function public.add_manual_plan_rows(uuid, date, text, jsonb) from public, anon;
revoke all on function public.save_import_plan(uuid, date, text, jsonb) from public, anon;
grant execute on function public.add_manual_plan_rows(uuid, date, text, jsonb) to authenticated;
grant execute on function public.save_import_plan(uuid, date, text, jsonb) to authenticated;

commit;
