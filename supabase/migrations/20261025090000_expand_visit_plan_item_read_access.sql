-- Let every role that can view visit history read the linked DO/Shipment snapshots.
-- Operational write permissions remain unchanged.
drop policy if exists visit_plan_items_select_permission on public.visit_plan_items;

create policy visit_plan_items_select_permission on public.visit_plan_items
for select to authenticated
using (
  private.has_permission('history','view')
  or private.has_permission('import_plan','view')
  or private.has_permission('start_loading','update')
  or private.has_permission('finish_loading','update')
);
