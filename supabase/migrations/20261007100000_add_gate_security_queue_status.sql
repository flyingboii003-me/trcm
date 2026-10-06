-- Add the Gate Security queue state used after WH In.
do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    where t.typname = 'process_status_type'
      and e.enumlabel = 'queue'
  ) then
    alter type public.process_status_type add value 'queue' after 'wh_in';
  end if;
end
$$;
