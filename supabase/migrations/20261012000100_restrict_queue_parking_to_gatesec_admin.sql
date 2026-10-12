-- Restrict the Kunjungan Armada queue page to Gate Security and Admin.
-- Checker reads eligible visits and starts loading from the dedicated Mulai Loading page.
delete from public.role_permissions rp
using public.roles ro, public.resources res, public.permissions p
where rp.role_id = ro.id
  and rp.resource_id = res.id
  and rp.permission_id = p.id
  and ro.key = 'checker'
  and res.key in ('wh_in', 'queue_parking', 'wh_out')
  and p.key = 'view';

-- Keep the dedicated loading workflow available to Checker.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, res.id, p.id
from public.roles ro
join public.resources res on res.key = 'start_loading'
join public.permissions p on p.key in ('view', 'update', 'upload')
where ro.key = 'checker'
on conflict do nothing;

-- Ensure Gate Security can view and operate the queue page.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, res.id, p.id
from public.roles ro
join public.resources res on res.key = 'queue_parking'
join public.permissions p on p.key in ('view', 'update')
where ro.key = 'gatesec'
on conflict do nothing;
