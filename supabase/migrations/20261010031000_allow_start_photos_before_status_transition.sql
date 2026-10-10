-- Loading-start photos are uploaded as part of the start-loading form before
-- the visit status is patched to "started". Permit that authenticated action
-- for visits the Checker can start, while retaining the start_loading:upload check.
DROP POLICY IF EXISTS "loading photo records require matching permission and visit sta" ON public.photos;
CREATE POLICY "loading photo records require matching permission and visit sta"
ON public.photos
FOR INSERT
TO authenticated
WITH CHECK (
  uploaded_by = (SELECT auth.uid())
  AND (
    (
      photo_type = 'loading_start'::public.photo_type
      AND private.has_permission('start_loading', 'upload')
      AND EXISTS (
        SELECT 1 FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (ARRAY[
            'registered'::public.process_status_type,
            'queue'::public.process_status_type,
            'started'::public.process_status_type
          ])
      )
    )
    OR
    (
      photo_type = 'loading_completion'::public.photo_type
      AND private.has_permission('finish_loading', 'upload')
      AND EXISTS (
        SELECT 1 FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (ARRAY[
            'started'::public.process_status_type,
            'completed'::public.process_status_type
          ])
      )
    )
  )
);
