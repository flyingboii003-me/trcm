-- Record WH Out timestamp and audit event atomically.
-- WH Out preserves process_status='completed'; wh_out_at marks the outbound transition.
create or replace function public.record_visit_wh_out(
  p_visit_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_visit_id uuid;
begin
  update public.visits
  set wh_out_at = now()
  where id = p_visit_id
    and process_status = 'completed'
    and completed_at is not null
    and wh_out_at is null
  returning id into v_visit_id;

  if v_visit_id is null then
    raise exception 'Armada sudah berubah status atau sudah diproses WH Out.';
  end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (v_visit_id, 'wh_out', auth.uid());

  return jsonb_build_object(
    'visit_id', v_visit_id,
    'process_status', 'completed',
    'wh_out', true
  );
end;
$$;

revoke all on function public.record_visit_wh_out(uuid) from public;
grant execute on function public.record_visit_wh_out(uuid) to authenticated;
