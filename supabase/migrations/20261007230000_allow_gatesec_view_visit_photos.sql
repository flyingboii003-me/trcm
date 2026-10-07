-- Allow operational roles to open visit photos from detail views.
drop policy if exists "checker and admin can view visit photos" on storage.objects;

create policy "gatesec checker and admin can view visit photos"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'trcm-visit-photos'
  and (
    select has_role('gatesec'::user_role)
    or has_role('checker'::user_role)
    or has_role('admin'::user_role)
  )
);
