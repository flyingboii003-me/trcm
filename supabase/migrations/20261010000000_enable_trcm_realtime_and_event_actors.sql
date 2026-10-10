-- Enable the narrowly scoped tables used by TRCM operational realtime.
-- This migration is intentionally committed as source only; apply it through the reviewed deployment workflow.
DO $$
DECLARE
  table_name text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    RAISE EXCEPTION 'Publication supabase_realtime does not exist';
  END IF;

  FOREACH table_name IN ARRAY ARRAY['visits', 'visit_events', 'photos']
  LOOP
    IF to_regclass(format('public.%I', table_name)) IS NULL THEN
      RAISE EXCEPTION 'Required table public.% does not exist', table_name;
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = table_name
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', table_name);
    END IF;
  END LOOP;
END
$$;

-- Return only actor labels for visit events, without granting broad SELECT on public.users.
-- The existing visit_events SELECT policy exposes event history to authenticated users;
-- this function exposes only event fields and a display label, never account credentials.
CREATE OR REPLACE FUNCTION public.get_visit_event_actors(p_visit_id uuid)
RETURNS TABLE (
  event_id uuid,
  visit_id uuid,
  status public.visit_event_status,
  actor_display_name text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;

  IF p_visit_id IS NULL THEN
    RAISE EXCEPTION 'visit_id is required' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    ve.id,
    ve.visit_id,
    ve.status,
    COALESCE(NULLIF(btrim(u.full_name), ''), NULLIF(btrim(u.username), ''), 'Pengguna'),
    ve.created_at
  FROM public.visit_events AS ve
  LEFT JOIN public.users AS u ON u.id = ve.user_id
  WHERE ve.visit_id = p_visit_id
  ORDER BY ve.created_at ASC;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_visit_event_actors(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_visit_event_actors(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_visit_event_actors(uuid) TO authenticated;
