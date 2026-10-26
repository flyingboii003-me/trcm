-- Save the start-loading transition, event, and shipment links atomically.
-- A failure in any step rolls back the entire RPC transaction.
create or replace function public.start_loading_visit(
  p_visit_id uuid,
  p_gate_id uuid,
  p_line_number_id uuid,
  p_seal_number text,
  p_notes text,
  p_plan_item_ids uuid[] default '{}'::uuid[]
)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_updated_visit_id uuid;
begin
  update public.visits
  set gate_id = p_gate_id,
      line_number_id = p_line_number_id,
      seal_number = nullif(btrim(p_seal_number), ''),
      notes = nullif(btrim(p_notes), ''),
      process_status = 'started',
      final_status = 'processing',
      started_at = now()
  where id = p_visit_id
    and process_status in ('wh_in', 'queue')
    and wh_in_at is not null
    and wh_out_at is null
  returning id into v_updated_visit_id;

  if v_updated_visit_id is null then
    raise exception 'Status truck berubah atau WH In belum dikonfirmasi.';
  end if;

  insert into public.visit_events (visit_id, status, user_id)
  values (p_visit_id, 'started', auth.uid());

  insert into public.visit_plan_items (visit_id, plan_item_id, linked_by)
  select p_visit_id, selected.plan_item_id, auth.uid()
  from (
    select distinct unnest(coalesce(p_plan_item_ids, '{}'::uuid[])) as plan_item_id
  ) as selected;

  return jsonb_build_object(
    'visit_id', v_updated_visit_id,
    'process_status', 'started',
    'linked_plan_items', cardinality(coalesce(p_plan_item_ids, '{}'::uuid[]))
  );
end;
$$;

revoke all on function public.start_loading_visit(uuid, uuid, uuid, text, text, uuid[]) from public;
grant execute on function public.start_loading_visit(uuid, uuid, uuid, text, text, uuid[]) to authenticated;
