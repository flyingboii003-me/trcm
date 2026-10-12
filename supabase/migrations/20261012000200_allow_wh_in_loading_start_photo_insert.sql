-- Allow Checker to register start-loading photos for visits that are still in wh_in.
-- The Mulai Loading flow inserts the photo record before changing the visit status to started.
-- Keep the existing permission and uploaded_by checks intact.
DROP POLICY IF EXISTS "photo records require matching workflow permission" ON public.photos;

CREATE POLICY "photo records require matching workflow permission"
ON public.photos
FOR INSERT
TO authenticated
WITH CHECK (
  uploaded_by = (SELECT auth.uid())
  AND (
    (
      photo_type = 'registration'::photo_type
      AND (SELECT private.has_permission('wh_in'::text, 'upload'::text))
      AND EXISTS (
        SELECT 1
        FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (
            ARRAY['wh_in'::process_status_type, 'registered'::process_status_type]
          )
      )
    )
    OR
    (
      photo_type = 'loading_start'::photo_type
      AND (SELECT private.has_permission('start_loading'::text, 'upload'::text))
      AND EXISTS (
        SELECT 1
        FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (
            ARRAY[
              'registered'::process_status_type,
              'wh_in'::process_status_type,
              'queue'::process_status_type,
              'started'::process_status_type
            ]
          )
      )
    )
    OR
    (
      photo_type = 'loading_completion'::photo_type
      AND (SELECT private.has_permission('finish_loading'::text, 'upload'::text))
      AND EXISTS (
        SELECT 1
        FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (
            ARRAY['started'::process_status_type, 'completed'::process_status_type]
          )
      )
    )
  )
);
