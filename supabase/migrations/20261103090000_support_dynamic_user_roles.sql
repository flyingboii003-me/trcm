-- Allow role keys managed in public.roles to be assigned to user profiles.
-- public.users.role_id is the authorization source of truth; role remains a
-- text compatibility mirror for legacy code paths.

alter table public.users
  alter column role type text
  using role::text;

create or replace function public.has_role(required_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
  select exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = required_role::text
  );
$function$;
