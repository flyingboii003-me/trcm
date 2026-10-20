-- Record prior snapshots when a plan is directly updated or deleted.
create or replace function public.capture_import_plan_history()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'private', 'pg_temp'
as $function$
declare
  v_snapshot jsonb;
  v_event text;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if tg_op='DELETE' then
    if not private.has_permission('daftar_plan','delete') then raise exception 'PERMISSION_DENIED'; end if;
    select jsonb_build_object(
      'plan',to_jsonb(old),
      'trips',coalesce((select jsonb_agg(to_jsonb(t) order by t.trip_number) from public.import_plan_trips t where t.plan_id=old.id),'[]'::jsonb),
      'items',coalesce((select jsonb_agg(to_jsonb(i) order by i.row_number) from public.import_plan_items i where i.plan_id=old.id),'[]'::jsonb)
    ) into v_snapshot;
    insert into public.import_plan_history(plan_id,source_plan_id,revision,event_type,changed_by,snapshot)
    values(old.id,old.id,old.revision,'deleted',auth.uid(),v_snapshot);
    return old;
  end if;

  -- Revision RPC records this transition with a richer revision event itself.
  if old.status='active' and new.status='superseded' then return new; end if;

  if to_jsonb(old) is distinct from to_jsonb(new) then
    if not private.has_permission('daftar_plan','update') then raise exception 'PERMISSION_DENIED'; end if;
    v_event := case when old.status is distinct from new.status then 'status_changed' else 'updated' end;
    select jsonb_build_object(
      'plan',to_jsonb(old),
      'trips',coalesce((select jsonb_agg(to_jsonb(t) order by t.trip_number) from public.import_plan_trips t where t.plan_id=old.id),'[]'::jsonb),
      'items',coalesce((select jsonb_agg(to_jsonb(i) order by i.row_number) from public.import_plan_items i where i.plan_id=old.id),'[]'::jsonb)
    ) into v_snapshot;
    insert into public.import_plan_history(plan_id,source_plan_id,revision,event_type,changed_by,snapshot)
    values(old.id,old.id,old.revision,v_event,auth.uid(),v_snapshot);
  end if;
  return new;
end;
$function$;

revoke all on function public.capture_import_plan_history() from public, anon, authenticated;
drop trigger if exists import_plans_capture_history on public.import_plans;
create trigger import_plans_capture_history
before update or delete on public.import_plans
for each row execute function public.capture_import_plan_history();
