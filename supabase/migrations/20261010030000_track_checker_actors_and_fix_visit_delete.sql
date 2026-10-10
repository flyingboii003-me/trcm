-- Record authenticated users who upload loading photos and honor history delete permissions.
ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS uploaded_by uuid REFERENCES public.users(id) ON DELETE SET NULL;

ALTER TABLE public.photos
  ALTER COLUMN uploaded_by SET DEFAULT auth.uid();

-- Existing records stay NULL; new uploads identify the authenticated actor.
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
          AND v.process_status = 'started'::public.process_status_type
      )
    )
    OR
    (
      photo_type = 'loading_completion'::public.photo_type
      AND private.has_permission('finish_loading', 'upload')
      AND EXISTS (
        SELECT 1 FROM public.visits v
        WHERE v.id = photos.visit_id
          AND v.process_status = ANY (ARRAY['started'::public.process_status_type, 'completed'::public.process_status_type])
      )
    )
  )
);

-- The previous policy was hard-coded to FALSE, so role permission changes could never allow deletes.
DROP POLICY IF EXISTS "operational can delete visits" ON public.visits;
CREATE POLICY "operational can delete visits"
ON public.visits
FOR DELETE
TO authenticated
USING (private.has_permission('history', 'delete'));
