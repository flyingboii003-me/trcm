-- Operational roles need view permission for the resources whose pages
-- they are expected to see in the sidebar. Action permissions alone are not
-- sufficient because menu visibility is driven by the centralized view check.

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'gatesec'
  and r.key in ('wh_in','queue_parking','wh_out')
  and p.key = 'view'
on conflict do nothing;

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'checker'
  and r.key in ('queue_parking','start_loading','finish_loading')
  and p.key = 'view'
on conflict do nothing;
