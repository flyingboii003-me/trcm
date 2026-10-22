-- TRCM plans track vehicle visits and document references, not cargo item details.
-- Keep one import_plan_items row per DO/Shipment reference.

create or replace function public.save_import_plan(
  p_client_id uuid,
  p_operational_date date,
  p_activity_type text,
  p_rows jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $function$
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
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not private.has_permission('import_plan', 'create') then
    raise exception 'PERMISSION_DENIED: tidak memiliki izin membuat Plan.';
  end if;
  if p_client_id is null or p_operational_date is null then raise exception 'CLIENT_AND_OPERATIONAL_DATE_REQUIRED'; end if;
  if p_activity_type not in ('inbound', 'outbound') then raise exception 'INVALID_ACTIVITY_TYPE'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then raise exception 'PLAN_ROWS_REQUIRED'; end if;
  if not exists (select 1 from public.clients c where c.id = p_client_id) then raise exception 'CLIENT_NOT_FOUND'; end if;

  v_row_count := jsonb_array_length(p_rows);
  perform pg_advisory_xact_lock(hashtextextended(p_client_id::text || '|' || p_operational_date::text || '|' || p_activity_type, 0));

  if p_activity_type = 'inbound' and exists (
    select 1 from jsonb_array_elements(p_rows) incoming(value)
    join public.import_plans p on p.client_id=p_client_id and p.operational_date=p_operational_date and p.activity_type='inbound' and p.status='active'
    join public.import_plan_items i on i.plan_id=p.id
    where nullif(btrim(incoming.value->>'do_number'),'') is not null
      and upper(regexp_replace(btrim(i.do_number), '\s+', ' ', 'g'))=upper(regexp_replace(btrim(incoming.value->>'do_number'), '\s+', ' ', 'g'))
  ) then raise exception using errcode='P0001', message='PLAN_DO_EXISTS', detail='Nomor DO sudah digunakan pada Plan Inbound aktif untuk klien dan tanggal ini.'; end if;

  if p_activity_type = 'outbound' and exists (
    select 1 from jsonb_array_elements(p_rows) incoming(value)
    join public.import_plans p on p.client_id=p_client_id and p.operational_date=p_operational_date and p.activity_type='outbound' and p.status='active'
    join public.import_plan_items i on i.plan_id=p.id
    where nullif(btrim(incoming.value->>'shipment_number'),'') is not null
      and upper(regexp_replace(btrim(i.shipment_number), '\s+', ' ', 'g'))=upper(regexp_replace(btrim(incoming.value->>'shipment_number'), '\s+', ' ', 'g'))
  ) then raise exception using errcode='P0001', message='PLAN_SHIPMENT_EXISTS', detail='Nomor Shipment sudah digunakan pada Plan Outbound aktif untuk klien dan tanggal ini.'; end if;

  insert into public.import_plans(client_id,operational_date,activity_type,revision,status,row_count,created_by,activated_at)
  values(p_client_id,p_operational_date,p_activity_type,1,'active',v_row_count,auth.uid(),now()) returning id into v_plan_id;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_row_number:=v_row_number+1;
    v_do:=nullif(btrim(v_row->>'do_number'),'');
    v_shipment:=nullif(btrim(v_row->>'shipment_number'),'');
    v_vendor:=nullif(btrim(v_row->>'vendor'),'');
    v_plate:=nullif(btrim(v_row->>'plate_number'),'');
    v_driver:=nullif(btrim(v_row->>'driver_name'),'');
    v_truck_type:=nullif(btrim(v_row->>'truck_type'),'');
    v_destination:=nullif(btrim(coalesce(v_row->>'destination',v_row->>'destination_city')),'');

    if p_activity_type='inbound' then
      if v_do is null then raise exception 'INBOUND_DO_REQUIRED pada baris %.',v_row_number; end if;
      v_key:='inbound|'||upper(regexp_replace(v_do,'\s+',' ','g'));
    else
      if v_vendor is null or v_plate is null or v_driver is null or v_truck_type is null or v_destination is null or v_shipment is null then
        raise exception 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.',v_row_number;
      end if;
      v_key:='outbound|'||upper(regexp_replace(v_vendor,'\s+',' ','g'))||'|'||
        upper(regexp_replace(v_plate,'\s+',' ','g'))||'|'||upper(regexp_replace(v_driver,'\s+',' ','g'))||'|'||
        upper(regexp_replace(v_truck_type,'\s+',' ','g'))||'|'||upper(regexp_replace(v_destination,'\s+',' ','g'));
    end if;

    if v_trip_ids ? v_key then
      v_trip_id:=(v_trip_ids->>v_key)::uuid;
    else
      v_trip_number:=v_trip_number+1;
      insert into public.import_plan_trips(plan_id,trip_number,vendor,plate_number,driver_name,truck_type,destination)
      values(v_plan_id,v_trip_number,v_vendor,v_plate,v_driver,v_truck_type,v_destination) returning id into v_trip_id;
      v_trip_ids:=v_trip_ids||jsonb_build_object(v_key,v_trip_id::text);
    end if;

    insert into public.import_plan_items(plan_id,trip_id,row_number,do_number,shipment_number)
    values(v_plan_id,v_trip_id,v_row_number,case when p_activity_type='inbound' then v_do else null end,
      case when p_activity_type='outbound' then v_shipment else null end);
  end loop;

  return jsonb_build_object('plan_id',v_plan_id,'client_id',p_client_id,'operational_date',p_operational_date,
    'activity_type',p_activity_type,'status','active','row_count',v_row_count,'trip_count',v_trip_number);
end;
$function$;

create or replace function public.update_import_plan(
  p_plan_id uuid,
  p_operational_date date,
  p_rows jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $function$
declare
  v_plan public.import_plans%rowtype;
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
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not private.has_permission('daftar_plan','update') then raise exception 'PERMISSION_DENIED'; end if;
  if p_plan_id is null or p_operational_date is null then raise exception 'PLAN_AND_OPERATIONAL_DATE_REQUIRED'; end if;
  if jsonb_typeof(p_rows)<>'array' or jsonb_array_length(p_rows)=0 then raise exception 'PLAN_ROWS_REQUIRED'; end if;

  select * into v_plan from public.import_plans where id=p_plan_id for update;
  if not found then raise exception 'PLAN_NOT_FOUND'; end if;
  if v_plan.status<>'active' then raise exception 'PLAN_MUST_BE_ACTIVE'; end if;
  perform pg_advisory_xact_lock(hashtextextended(v_plan.client_id::text||'|'||p_operational_date::text||'|'||v_plan.activity_type,0));

  if exists(select 1 from public.visit_plan_items vpi join public.import_plan_items i on i.id=vpi.plan_item_id where i.plan_id=v_plan.id)
    then raise exception 'PLAN_HAS_VISIT_LINKS'; end if;

  if v_plan.activity_type='inbound' and exists (
    select 1 from jsonb_array_elements(p_rows) incoming(value)
    join public.import_plans p on p.client_id=v_plan.client_id and p.operational_date=p_operational_date and p.activity_type='inbound' and p.status='active' and p.id<>v_plan.id
    join public.import_plan_items i on i.plan_id=p.id
    where nullif(btrim(incoming.value->>'do_number'),'') is not null
      and upper(regexp_replace(btrim(i.do_number),'\s+',' ','g'))=upper(regexp_replace(btrim(incoming.value->>'do_number'),'\s+',' ','g'))
  ) then raise exception 'PLAN_DO_EXISTS'; end if;

  if v_plan.activity_type='outbound' and exists (
    select 1 from jsonb_array_elements(p_rows) incoming(value)
    join public.import_plans p on p.client_id=v_plan.client_id and p.operational_date=p_operational_date and p.activity_type='outbound' and p.status='active' and p.id<>v_plan.id
    join public.import_plan_items i on i.plan_id=p.id
    where nullif(btrim(incoming.value->>'shipment_number'),'') is not null
      and upper(regexp_replace(btrim(i.shipment_number),'\s+',' ','g'))=upper(regexp_replace(btrim(incoming.value->>'shipment_number'),'\s+',' ','g'))
  ) then raise exception 'PLAN_SHIPMENT_EXISTS'; end if;

  v_row_count:=jsonb_array_length(p_rows);
  delete from public.import_plan_items where plan_id=v_plan.id;
  delete from public.import_plan_trips where plan_id=v_plan.id;
  update public.import_plans set operational_date=p_operational_date,row_count=v_row_count,updated_at=now() where id=v_plan.id;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_row_number:=v_row_number+1;
    v_do:=nullif(btrim(v_row->>'do_number'),'');
    v_shipment:=nullif(btrim(v_row->>'shipment_number'),'');
    v_vendor:=nullif(btrim(v_row->>'vendor'),'');
    v_plate:=nullif(btrim(v_row->>'plate_number'),'');
    v_driver:=nullif(btrim(v_row->>'driver_name'),'');
    v_truck_type:=nullif(btrim(v_row->>'truck_type'),'');
    v_destination:=nullif(btrim(coalesce(v_row->>'destination',v_row->>'destination_city')),'');

    if v_plan.activity_type='inbound' then
      if v_do is null then raise exception 'INBOUND_DO_REQUIRED pada baris %.',v_row_number; end if;
      v_key:='inbound|'||upper(regexp_replace(v_do,'\s+',' ','g'));
    else
      if v_vendor is null or v_plate is null or v_driver is null or v_truck_type is null or v_destination is null or v_shipment is null then
        raise exception 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.',v_row_number;
      end if;
      v_key:='outbound|'||upper(regexp_replace(v_vendor,'\s+',' ','g'))||'|'||
        upper(regexp_replace(v_plate,'\s+',' ','g'))||'|'||upper(regexp_replace(v_driver,'\s+',' ','g'))||'|'||
        upper(regexp_replace(v_truck_type,'\s+',' ','g'))||'|'||upper(regexp_replace(v_destination,'\s+',' ','g'));
    end if;

    if v_trip_ids ? v_key then v_trip_id:=(v_trip_ids->>v_key)::uuid;
    else
      v_trip_number:=v_trip_number+1;
      insert into public.import_plan_trips(plan_id,trip_number,vendor,plate_number,driver_name,truck_type,destination)
      values(v_plan.id,v_trip_number,v_vendor,v_plate,v_driver,v_truck_type,v_destination) returning id into v_trip_id;
      v_trip_ids:=v_trip_ids||jsonb_build_object(v_key,v_trip_id::text);
    end if;
    insert into public.import_plan_items(plan_id,trip_id,row_number,do_number,shipment_number)
    values(v_plan.id,v_trip_id,v_row_number,case when v_plan.activity_type='inbound' then v_do else null end,
      case when v_plan.activity_type='outbound' then v_shipment else null end);
  end loop;
  return jsonb_build_object('plan_id',v_plan.id,'client_id',v_plan.client_id,'operational_date',p_operational_date,
    'activity_type',v_plan.activity_type,'status','active','row_count',v_row_count,'trip_count',v_trip_number);
end;
$function$;

drop trigger if exists capture_visit_plan_item_snapshot on public.visit_plan_items;
drop function if exists public.capture_visit_plan_item_snapshot();

alter table public.import_plan_items
  drop column if exists part_number,
  drop column if exists product_name,
  drop column if exists quantity;

alter table public.visit_plan_items
  drop column if exists snapshot_part_number,
  drop column if exists snapshot_product_name,
  drop column if exists snapshot_quantity;
