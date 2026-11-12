-- Pertahankan validasi RLS lama untuk Mulai Loading; validasi tambahan
-- khusus Hubungkan Plan manual tidak mengubah perilaku workflow yang sudah ada.
drop policy if exists visit_plan_items_insert_permission on public.visit_plan_items;
create policy visit_plan_items_insert_permission
on public.visit_plan_items
for insert to authenticated
with check (
  (
    private.has_permission('start_loading', 'update')
    and exists (
      select 1
      from public.import_plan_items i
      join public.import_plans p on p.id = i.plan_id
      where i.id = visit_plan_items.plan_item_id
        and p.status = 'active'
    )
  )
  or (
    private.has_permission('daftar_plan', 'update')
    and exists (
      select 1
      from public.visits v
      join public.import_plan_items i on i.id = visit_plan_items.plan_item_id
      join public.import_plans p on p.id = i.plan_id
      where v.id = visit_plan_items.visit_id
        and v.wh_out_at is null
        and p.status = 'active'
        and p.client_id = v.client_id
        and p.activity_type = v.activity_type::text
        and not coalesce(i.manual_processed, false)
    )
  )
);