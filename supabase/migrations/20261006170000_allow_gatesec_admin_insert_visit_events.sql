do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'visit_events'
      and policyname = 'gatesec and admin can create visit events'
  ) then
    create policy "gatesec and admin can create visit events"
      on public.visit_events
      for insert
      to authenticated
      with check (has_role('gatesec'::user_role) or has_role('admin'::user_role));
  end if;
end
$$;
