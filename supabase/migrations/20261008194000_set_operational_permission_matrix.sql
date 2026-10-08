-- Operational permission matrix derived from PRD TRCM v2.
-- Gatesec: create/update registration and perform WH Out.
-- Checker: perform Mulai Loading, upload its documentation, and Selesai Loading.
-- Existing read-only dashboard/history permissions are preserved.

delete from public.role_permissions rp
using public.roles ro, public.resources r
where rp.role_id = ro.id
  and rp.resource_id = r.id
  and ro.key in ('gatesec','checker')
  and r.key in ('wh_in','wh_out','queue_parking','start_loading','finish_loading');

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'gatesec'
  and r.key = 'wh_in'
  and p.key in ('create','update');

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'gatesec'
  and r.key = 'wh_out'
  and p.key = 'update';

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'checker'
  and r.key = 'start_loading'
  and p.key in ('update','upload');

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'checker'
  and r.key = 'finish_loading'
  and p.key = 'update';
