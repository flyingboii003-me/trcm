-- Remove Draft/revision-history workflow and support in-place Plan updates.
DROP TRIGGER IF EXISTS import_plans_capture_history ON public.import_plans;
DROP FUNCTION IF EXISTS public.capture_import_plan_history();
DROP FUNCTION IF EXISTS public.create_import_plan_revision(uuid, date, jsonb, text);
DROP TABLE IF EXISTS public.import_plan_history CASCADE;

UPDATE public.import_plans SET status='active' WHERE status='draft';
UPDATE public.import_plans SET status='cancelled' WHERE status='superseded';
ALTER TABLE public.import_plans ALTER COLUMN status SET DEFAULT 'active';
ALTER TABLE public.import_plans DROP CONSTRAINT IF EXISTS import_plans_status_check;
ALTER TABLE public.import_plans ADD CONSTRAINT import_plans_status_check
  CHECK (status = ANY (ARRAY['active'::text, 'cancelled'::text]));

CREATE OR REPLACE FUNCTION public.update_import_plan(p_plan_id uuid, p_operational_date date, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
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
  v_quantity numeric;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF NOT private.has_permission('daftar_plan', 'update') THEN
    RAISE EXCEPTION 'PERMISSION_DENIED';
  END IF;
  IF p_plan_id IS NULL OR p_operational_date IS NULL THEN
    RAISE EXCEPTION 'PLAN_AND_OPERATIONAL_DATE_REQUIRED';
  END IF;
  IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) = 0 THEN
    RAISE EXCEPTION 'PLAN_ROWS_REQUIRED';
  END IF;

  SELECT * INTO v_plan FROM public.import_plans WHERE id=p_plan_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PLAN_NOT_FOUND'; END IF;
  IF v_plan.status <> 'active' THEN RAISE EXCEPTION 'PLAN_MUST_BE_ACTIVE'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(
    v_plan.client_id::text || '|' || p_operational_date::text || '|' || v_plan.activity_type, 0
  ));

  IF EXISTS (
    SELECT 1 FROM public.visit_plan_items vpi
    JOIN public.import_plan_items i ON i.id=vpi.plan_item_id
    WHERE i.plan_id=v_plan.id
  ) THEN RAISE EXCEPTION 'PLAN_HAS_VISIT_LINKS'; END IF;

  IF v_plan.activity_type='inbound' AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_rows) incoming(value)
    JOIN public.import_plans p ON p.client_id=v_plan.client_id
      AND p.operational_date=p_operational_date AND p.activity_type='inbound'
      AND p.status='active' AND p.id<>v_plan.id
    JOIN public.import_plan_items i ON i.plan_id=p.id
    WHERE nullif(btrim(incoming.value->>'do_number'),'') IS NOT NULL
      AND upper(regexp_replace(btrim(i.do_number), '\s+', ' ', 'g')) =
          upper(regexp_replace(btrim(incoming.value->>'do_number'), '\s+', ' ', 'g'))
  ) THEN RAISE EXCEPTION 'PLAN_DO_EXISTS'; END IF;

  IF v_plan.activity_type='outbound' AND EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_rows) incoming(value)
    JOIN public.import_plans p ON p.client_id=v_plan.client_id
      AND p.operational_date=p_operational_date AND p.activity_type='outbound'
      AND p.status='active' AND p.id<>v_plan.id
    JOIN public.import_plan_items i ON i.plan_id=p.id
    WHERE nullif(btrim(incoming.value->>'shipment_number'),'') IS NOT NULL
      AND upper(regexp_replace(btrim(i.shipment_number), '\s+', ' ', 'g')) =
          upper(regexp_replace(btrim(incoming.value->>'shipment_number'), '\s+', ' ', 'g'))
  ) THEN RAISE EXCEPTION 'PLAN_SHIPMENT_EXISTS'; END IF;

  v_row_count := jsonb_array_length(p_rows);
  DELETE FROM public.import_plan_items WHERE plan_id=v_plan.id;
  DELETE FROM public.import_plan_trips WHERE plan_id=v_plan.id;
  UPDATE public.import_plans SET operational_date=p_operational_date,
    row_count=v_row_count, updated_at=now() WHERE id=v_plan.id;

  FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    v_row_number := v_row_number + 1;
    v_do := nullif(btrim(v_row->>'do_number'),'');
    v_shipment := nullif(btrim(v_row->>'shipment_number'),'');
    v_vendor := nullif(btrim(v_row->>'vendor'),'');
    v_plate := nullif(btrim(v_row->>'plate_number'),'');
    v_driver := nullif(btrim(v_row->>'driver_name'),'');
    v_truck_type := nullif(btrim(v_row->>'truck_type'),'');
    v_destination := nullif(btrim(v_row->>'destination'),'');

    IF v_plan.activity_type='inbound' THEN
      IF v_do IS NULL OR nullif(btrim(v_row->>'part_number'),'') IS NULL
         OR nullif(btrim(v_row->>'product_name'),'') IS NULL THEN
        RAISE EXCEPTION 'INBOUND_REQUIRED_FIELDS_MISSING pada baris %.', v_row_number;
      END IF;
      v_key := 'inbound|' || upper(regexp_replace(v_do, '\s+', ' ', 'g'));
    ELSE
      IF v_vendor IS NULL OR v_plate IS NULL OR v_driver IS NULL OR v_truck_type IS NULL
         OR v_destination IS NULL OR v_shipment IS NULL THEN
        RAISE EXCEPTION 'OUTBOUND_REQUIRED_FIELDS_MISSING pada baris %.', v_row_number;
      END IF;
      v_key := 'outbound|' || upper(regexp_replace(v_vendor, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_plate, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_driver, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_truck_type, '\s+', ' ', 'g')) || '|' ||
        upper(regexp_replace(v_destination, '\s+', ' ', 'g'));
    END IF;

    IF v_row->>'quantity' IS NULL OR btrim(v_row->>'quantity')='' THEN
      RAISE EXCEPTION 'QUANTITY_REQUIRED pada baris %.', v_row_number;
    END IF;
    v_quantity := (v_row->>'quantity')::numeric;
    IF v_quantity <= 0 THEN RAISE EXCEPTION 'QUANTITY_MUST_BE_POSITIVE pada baris %.', v_row_number; END IF;

    IF v_trip_ids ? v_key THEN
      v_trip_id := (v_trip_ids->>v_key)::uuid;
    ELSE
      v_trip_number := v_trip_number + 1;
      INSERT INTO public.import_plan_trips(plan_id,trip_number,vendor,plate_number,driver_name,truck_type,destination)
      VALUES(v_plan.id,v_trip_number,v_vendor,v_plate,v_driver,v_truck_type,v_destination)
      RETURNING id INTO v_trip_id;
      v_trip_ids := v_trip_ids || jsonb_build_object(v_key,v_trip_id::text);
    END IF;

    INSERT INTO public.import_plan_items(plan_id,trip_id,row_number,do_number,shipment_number,part_number,product_name,quantity)
    VALUES(v_plan.id,v_trip_id,v_row_number,
      CASE WHEN v_plan.activity_type='inbound' THEN v_do ELSE NULL END,
      CASE WHEN v_plan.activity_type='outbound' THEN v_shipment ELSE NULL END,
      nullif(btrim(v_row->>'part_number'),''),
      nullif(btrim(v_row->>'product_name'),''),
      v_quantity);
  END LOOP;

  RETURN jsonb_build_object('plan_id',v_plan.id,'client_id',v_plan.client_id,
    'operational_date',p_operational_date,'activity_type',v_plan.activity_type,
    'status','active','row_count',v_row_count,'trip_count',v_trip_number);
END;
$function$


REVOKE ALL ON FUNCTION public.update_import_plan(uuid, date, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_import_plan(uuid, date, jsonb) TO authenticated;

-- Permit an authorized Plan editor to replace that Plan's own detail rows.
DROP POLICY IF EXISTS import_plan_items_delete_permission ON public.import_plan_items;
CREATE POLICY import_plan_items_delete_permission ON public.import_plan_items
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.import_plans p
    WHERE p.id=import_plan_items.plan_id
      AND (private.has_permission('daftar_plan','delete') OR private.has_permission('daftar_plan','update'))
  ));

DROP POLICY IF EXISTS import_plan_items_insert_permission ON public.import_plan_items;
CREATE POLICY import_plan_items_insert_permission ON public.import_plan_items
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.import_plans p
    WHERE p.id=import_plan_items.plan_id
      AND (private.has_permission('import_plan','create') OR private.has_permission('daftar_plan','update'))
  ));

DROP POLICY IF EXISTS import_plan_trips_delete_permission ON public.import_plan_trips;
CREATE POLICY import_plan_trips_delete_permission ON public.import_plan_trips
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.import_plans p
    WHERE p.id=import_plan_trips.plan_id
      AND (private.has_permission('daftar_plan','delete') OR private.has_permission('daftar_plan','update'))
  ));

DROP POLICY IF EXISTS import_plan_trips_insert_permission ON public.import_plan_trips;
CREATE POLICY import_plan_trips_insert_permission ON public.import_plan_trips
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.import_plans p
    WHERE p.id=import_plan_trips.plan_id
      AND (private.has_permission('import_plan','create') OR private.has_permission('daftar_plan','update'))
  ));
