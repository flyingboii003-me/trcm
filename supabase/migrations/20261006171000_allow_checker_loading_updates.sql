do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='visits'
      and policyname='checker and admin can update visits'
  ) then
    create policy "checker and admin can update visits"
      on public.visits
      for update to authenticated
      using (has_role('checker'::user_role) or has_role('admin'::user_role))
      with check (has_role('checker'::user_role) or has_role('admin'::user_role));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='visit_events'
      and policyname='checker and admin can create visit events'
  ) then
    create policy "checker and admin can create visit events"
      on public.visit_events
      for insert to authenticated
      with check (has_role('checker'::user_role) or has_role('admin'::user_role));
  end if;
end
$$;
