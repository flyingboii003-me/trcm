-- Operational workflow permissions:
-- Gate Security can move registered trucks into queue/parking and, when the
-- loading dock is empty, bypass the queue directly to Start Loading.
-- Checker can manage queue/parking and move a queued truck into loading.
insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key in ('gatesec','checker')
  and r.key = 'queue_parking'
  and p.key = 'update'
on conflict do nothing;

insert into public.role_permissions (role_id, resource_id, permission_id)
select ro.id, r.id, p.id
from public.roles ro
cross join public.resources r
cross join public.permissions p
where ro.key = 'gatesec'
  and r.key = 'start_loading'
  and p.key = 'update'
on conflict do nothing;
