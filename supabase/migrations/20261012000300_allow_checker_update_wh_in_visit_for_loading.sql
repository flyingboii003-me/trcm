-- Allow users with start_loading:update to transition visits from wh_in to started.
-- Keep the existing WITH CHECK clause and all other status/permission rules intact.
ALTER POLICY "operational can update visits"
ON public.visits
USING (
  (
    process_status = 'wh_in'::process_status_type
    AND (
      private.has_permission('wh_in', 'update')
      OR private.has_permission('start_loading', 'update')
    )
  )
  OR (
    process_status = 'registered'::process_status_type
    AND (
      private.has_permission('queue_parking', 'update')
      OR private.has_permission('start_loading', 'update')
    )
  )
  OR (
    process_status = 'queue'::process_status_type
    AND (
      private.has_permission('queue_parking', 'update')
      OR private.has_permission('start_loading', 'update')
    )
  )
  OR (
    process_status = 'started'::process_status_type
    AND (
      private.has_permission('start_loading', 'update')
      OR private.has_permission('finish_loading', 'update')
    )
  )
  OR (
    process_status = 'completed'::process_status_type
    AND private.has_permission('wh_out', 'update')
  )
);
