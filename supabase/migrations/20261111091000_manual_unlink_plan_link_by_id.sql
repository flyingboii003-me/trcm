-- Izinkan pemutusan relasi berdasarkan ID relasi, termasuk snapshot historis
-- yang plan_item_id-nya sudah null karena Plan sumber dihapus.
create or replace function public.manual_unlink_plan_link(
  p_visit_id uuid,
  p_link_id uuid
)
returns jsonb
language plpgsql
security invoker
set search_path = public, private, pg_temp
as $$
declare
  v_deleted_id uuid;
begin
  if auth.uid() is null or not private.has_permission('daftar_plan', 'update') then
    raise exception 'Anda tidak memiliki izin untuk memutus hubungan Plan.';
  end if;

  perform 1
  from public.visits
  where id = p_visit_id
    and wh_out_at is null
  for update;

  if not found then
    raise exception 'Armada tidak ditemukan atau sudah WH Out.';
  end if;

  delete from public.visit_plan_items
  where id = p_link_id
    and visit_id = p_visit_id
  returning id into v_deleted_id;

  if v_deleted_id is null then
    raise exception 'Hubungan DO/Shipment tidak ditemukan.';
  end if;

  return jsonb_build_object('visit_id', p_visit_id, 'unlinked_link_id', v_deleted_id);
end;
$$;

revoke all on function public.manual_unlink_plan_link(uuid, uuid) from public, anon;
grant execute on function public.manual_unlink_plan_link(uuid, uuid) to authenticated;