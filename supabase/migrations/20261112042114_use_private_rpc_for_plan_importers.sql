-- Replace the SECURITY DEFINER view with a narrowly scoped RPC.
-- The private helper returns only importer display fields and checks the caller's
-- current auth.uid() plus plan_data.view. The public wrapper is SECURITY INVOKER.

begin;

drop view if exists public.plan_importers;

create or replace function private.get_plan_importers(p_plan_ids uuid[])
returns table (
  plan_id uuid,
  username text,
  full_name text
)
language sql
stable
security definer
set search_path = pg_catalog, public, private
as $function$
  select
    p.id as plan_id,
    u.username,
    u.full_name
  from public.import_plans p
  join public.users u
    on u.id = p.created_by
  where p.id = any(coalesce(p_plan_ids, array[]::uuid[]))
    and auth.uid() is not null
    and private.has_permission('plan_data', 'view');
$function$;

revoke all on function private.get_plan_importers(uuid[]) from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.get_plan_importers(uuid[]) to authenticated;

create or replace function public.get_plan_importers(p_plan_ids uuid[])
returns table (
  plan_id uuid,
  username text,
  full_name text
)
language sql
stable
security invoker
set search_path = pg_catalog, public, private
as $function$
  select *
  from private.get_plan_importers(p_plan_ids);
$function$;

revoke all on function public.get_plan_importers(uuid[]) from public, anon;
grant execute on function public.get_plan_importers(uuid[]) to authenticated;

commit;
