-- Preserve snapshots for import-plan revisions.
create table if not exists public.import_plan_history (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid,
  source_plan_id uuid,
  revision integer not null check (revision > 0),
  event_type text not null check (event_type in ('created', 'revised', 'updated', 'status_changed', 'deleted')),
  changed_by uuid references public.users(id) on delete set null,
  snapshot jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists import_plan_history_plan_id_created_at_idx
  on public.import_plan_history (plan_id, created_at desc);

alter table public.import_plan_history enable row level security;

drop policy if exists import_plan_history_select_admin on public.import_plan_history;
create policy import_plan_history_select_admin on public.import_plan_history
  for select to authenticated
  using (private.has_permission('daftar_plan','view'));

drop policy if exists import_plan_history_insert_admin on public.import_plan_history;
create policy import_plan_history_insert_admin on public.import_plan_history
  for insert to authenticated
  with check (private.has_permission('daftar_plan','update'));

create or replace function public.create_import_plan_revision(
  p_source_plan_id uuid,
  p_operational_date date,
  p_rows jsonb,
  p_status text default 'active'
) returns jsonb
language plpgsql
set search_path to 'public', 'private', 'pg_temp'
as $function$
declare
  v_source public.import_plans%rowtype;
  v_new_plan_id uuid;
  v_new_trip_id uuid;
  v_row jsonb;
  v_trip_key text;
  v_trip_map jsonb := '{}'::jsonb;
  v_trip_number integer := 0;
  v_row_number integer := 0;
  v_row_count integer;
  v_revision integer;
  v_source_snapshot jsonb;
  v_new_snapshot jsonb;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not private.has_permission('daftar_plan', 'update')
     or not private.has_permission('import_plan', 'create') then raise exception 'PERMISSION_DENIED'; end if;
  if p_operational_date is null then raise exception 'OPERATIONAL_DATE_REQUIRED'; end if;
  if p_status not in ('active','draft','cancelled') then raise exception 'INVALID_PLAN_STATUS'; end if;
  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows)=0 then raise exception 'PLAN_ROWS_REQUIRED'; end if;

  select * into v_source from public.import_plans where id=p_source_plan_id for update;
  if not found then raise exception 'PLAN_NOT_FOUND'; end if;
  if v_source.status <> 'active' then raise exception 'REVISION_SOURCE_MUST_BE_ACTIVE'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_source.client_id::text||'|'||v_source.operational_date::text||'|'||v_source.activity_type,0));
  perform pg_advisory_xact_lock(hashtextextended(v_source.client_id::text||'|'||p_operational_date::text||'|'||v_source.activity_type,0));

  if exists (select 1 from public.visit_plan_items vpi join public.import_plan_items i on i.id=vpi.plan_item_id where i.plan_id=v_source.id) then
    raise exception 'PLAN_HAS_VISIT_LINKS';
  end if;
  if p_status='active' and exists (
    select 1 from public.import_plans p where p.client_id=v_source.client_id
      and p.operational_date=p_operational_date and p.activity_type=v_source.activity_type
      and p.status='active' and p.id<>v_source.id
  ) then raise exception 'PLAN_ACTIVE_EXISTS'; end if;

  select jsonb_build_object(
    'plan', to_jsonb(v_source),
    'trips', coalesce((select jsonb_agg(to_jsonb(t) order by t.trip_number) from public.import_plan_trips t where t.plan_id=v_source.id),'[]'::jsonb),
    'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.row_number) from public.import_plan_items i where i.plan_id=v_source.id),'[]'::jsonb)
  ) into v_source_snapshot;

  v_row_count := jsonb_array_length(p_rows);
  select coalesce(max(revision),0)+1 into v_revision from public.import_plans
    where client_id=v_source.client_id and operational_date=p_operational_date and activity_type=v_source.activity_type;

  insert into public.import_plans (client_id,operational_date,activity_type,revision,status,row_count,created_by,activated_at)
  values (v_source.client_id,p_operational_date,v_source.activity_type,v_revision,p_status,v_row_count,auth.uid(),
    case when p_status='active' then now() else null end)
  returning id into v_new_plan_id;

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_row_number := v_row_number + 1;
    if v_source.activity_type='inbound' then
      if nullif(btrim(v_row->>'do_number'),'') is null
        or nullif(btrim(v_row->>'part_number'),'') is null
        or nullif(btrim(v_row->>'product_name'),'') is null then
        raise exception 'INBOUND_REQUIRED_FIELDS_MISSING pada baris %.',v_row_number;
      end if;
      v_trip_key := 'inbound|'||upper(regexp_replace(btrim(v_row->>'do_number'),'\s+',' ','g'));
    else
      if nullif(btrim(v_row->>'vendor'),'') is null or nullif(btrim(v_row->>'plate_number'),'') is null
        or nullif(btrim(v_row->>'driver_name'),'') is null or nullif(btrim(v_row->>'truck_type'),'') is null
        or nullif(btrim(v_row->>'destination'),'') is null or nullif(btrim(v_row->>'shipment_number'),'') is null then
        raise exception 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.',v_row_number;
      end if;
      v_trip_key := 'outbound|'||upper(regexp_replace(btrim(v_row->>'vendor'),'\s+',' ','g'))||'|'||
        upper(regexp_replace(btrim(v_row->>'plate_number'),'\s+',' ','g'))||'|'||
        upper(regexp_replace(btrim(v_row->>'driver_name'),'\s+',' ','g'))||'|'||
        upper(regexp_replace(btrim(v_row->>'truck_type'),'\s+',' ','g'))||'|'||
        upper(regexp_replace(btrim(v_row->>'destination'),'\s+',' ','g'));
    end if;
    if coalesce((v_row->>'quantity')::numeric,0)<=0 then raise exception 'QUANTITY_MUST_BE_POSITIVE pada baris %.',v_row_number; end if;

    if not (v_trip_map ? v_trip_key) then
      v_trip_number := v_trip_number+1;
      insert into public.import_plan_trips(plan_id,trip_number,vendor,plate_number,driver_name,truck_type,destination)
      values(v_new_plan_id,v_trip_number,nullif(btrim(v_row->>'vendor'),''),nullif(btrim(v_row->>'plate_number'),''),
        nullif(btrim(v_row->>'driver_name'),''),nullif(btrim(v_row->>'truck_type'),''),nullif(btrim(v_row->>'destination'),''))
      returning id into v_new_trip_id;
      v_trip_map := v_trip_map || jsonb_build_object(v_trip_key,v_new_trip_id::text);
    else
      v_new_trip_id := (v_trip_map->>v_trip_key)::uuid;
    end if;

    insert into public.import_plan_items(plan_id,trip_id,row_number,do_number,shipment_number,part_number,product_name,quantity)
    values(v_new_plan_id,v_new_trip_id,v_row_number,
      case when v_source.activity_type='inbound' then nullif(btrim(v_row->>'do_number'),'') else null end,
      case when v_source.activity_type='outbound' then nullif(btrim(v_row->>'shipment_number'),'') else null end,
      nullif(btrim(v_row->>'part_number'),''),nullif(btrim(v_row->>'product_name'),''),(v_row->>'quantity')::numeric);
  end loop;

  if p_status='active' then
    update public.import_plans set status='superseded',updated_at=now() where id=v_source.id and status='active';
  end if;

  select jsonb_build_object(
    'plan', (select to_jsonb(p) from public.import_plans p where p.id=v_new_plan_id),
    'trips', coalesce((select jsonb_agg(to_jsonb(t) order by t.trip_number) from public.import_plan_trips t where t.plan_id=v_new_plan_id),'[]'::jsonb),
    'items', coalesce((select jsonb_agg(to_jsonb(i) order by i.row_number) from public.import_plan_items i where i.plan_id=v_new_plan_id),'[]'::jsonb)
  ) into v_new_snapshot;

  insert into public.import_plan_history(plan_id,source_plan_id,revision,event_type,changed_by,snapshot)
  values(v_source.id,v_source.id,v_source.revision,'revised',auth.uid(),v_source_snapshot),
        (v_new_plan_id,v_source.id,v_revision,'created',auth.uid(),v_new_snapshot);

  return jsonb_build_object('source_plan_id',v_source.id,'plan_id',v_new_plan_id,'client_id',v_source.client_id,
    'operational_date',p_operational_date,'activity_type',v_source.activity_type,'revision',v_revision,
    'status',p_status,'row_count',v_row_count,'trip_count',v_trip_number);
end;
$function$;

grant select, insert on public.import_plan_history to authenticated;
grant execute on function public.create_import_plan_revision(uuid,date,jsonb,text) to authenticated;
