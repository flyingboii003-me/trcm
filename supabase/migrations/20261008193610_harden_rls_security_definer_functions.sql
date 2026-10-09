-- Harden SECURITY DEFINER helpers.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
grant execute on function public.rls_auto_enable() to postgres;

alter function public.set_updated_at() set search_path = public, pg_temp;
