-- Ensure every authenticated role with read access to TRCM visits can
-- retrieve visit photos from the private Storage bucket.
--
-- Upload permissions remain governed by the existing INSERT policy. This
-- policy only grants SELECT (download / signed URL access) and does not make
-- the bucket public or grant upload, update, or delete access.
DROP POLICY IF EXISTS "operational roles can view visit photos" ON storage.objects;
DROP POLICY IF EXISTS "gatesec checker and admin can view visit photos" ON storage.objects;

CREATE POLICY "authenticated users can view visit photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'trcm-visit-photos'
  AND EXISTS (
    SELECT 1
    FROM public.visits v
    WHERE v.id::text = (storage.foldername(name))[1]
  )
);
