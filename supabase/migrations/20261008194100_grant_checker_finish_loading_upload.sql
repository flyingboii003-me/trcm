-- Checker must be able to upload documentation during both loading stages.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'checker'
  and r.key = 'finish_loading'
  and p.key = 'upload'
on conflict do nothing;
