-- Keep importer metadata inside plan_data while exposing only display fields.
begin;

drop policy if exists "users select plan creators by plan data permission" on public.users;

create or replace view public.plan_importers
with (security_barrier = true)
as
select
  p.id as plan_id,
  u.username,
  u.full_name
from public.import_plans p
join public.users u
  on u.id = p.created_by
where p.created_by is not null
  and private.has_permission('plan_data', 'view');

comment on view public.plan_importers is
  'Minimal importer display projection for Plans; access requires plan_data.view.';

revoke all on public.plan_importers from public, anon, authenticated;
grant select on public.plan_importers to authenticated;

commit;
