-- Make WH In confirmation and queue/parking transitions atomic with their audit events.
create or replace function public.confirm_visit_wh_in(
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
  set wh_in_at = now()
  where id = p_visit_id
    and process_status = 'wh_in'
    and registered_at is not null
    and wh_in_at is null
    and wh_out_at is null
  returning id into v_visit_id;

  if v_visit_id is null then
    raise exception 'Armada sudah berubah status atau sudah dikonfirmasi WH In.';
  end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (v_visit_id, 'wh_in', auth.uid());

  return jsonb_build_object(
    'visit_id', v_visit_id,
    'process_status', 'wh_in',
    'wh_in', true
  );
end;
$$;

revoke all on function public.confirm_visit_wh_in(uuid) from public;
grant execute on function public.confirm_visit_wh_in(uuid) to authenticated;

create or replace function public.park_visit(
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
  set process_status = 'queue',
      final_status = 'parked'
  where id = p_visit_id
    and process_status = 'wh_in'
    and wh_in_at is not null
    and wh_out_at is null
  returning id into v_visit_id;

  if v_visit_id is null then
    raise exception 'Armada sudah berubah status atau belum dikonfirmasi WH In.';
  end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (v_visit_id, 'parked', auth.uid());

  return jsonb_build_object(
    'visit_id', v_visit_id,
    'process_status', 'queue',
    'parked', true
  );
end;
$$;

revoke all on function public.park_visit(uuid) from public;
grant execute on function public.park_visit(uuid) to authenticated;
