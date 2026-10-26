-- Complete the loading transition and its audit event in one transaction.
create or replace function public.finish_loading_visit(
  p_visit_id uuid,
  p_notes text
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_completed_visit_id uuid;
begin
  update public.visits
  set notes = nullif(btrim(p_notes), ''),
      process_status = 'completed',
      final_status = 'completed',
      completed_at = now()
  where id = p_visit_id
    and process_status = 'started'
    and started_at is not null
    and wh_out_at is null
  returning id into v_completed_visit_id;

  if v_completed_visit_id is null then
    raise exception 'Status truck berubah atau proses Loading belum dimulai.';
  end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (v_completed_visit_id, 'completed', auth.uid());

  return jsonb_build_object(
    'visit_id', v_completed_visit_id,
    'process_status', 'completed'
  );
end;
$$;

revoke all on function public.finish_loading_visit(uuid, text) from public;
grant execute on function public.finish_loading_visit(uuid, text) to authenticated;
