-- Enforce the document-only Plan model at the database boundary.
create unique index if not exists import_plan_items_plan_do_unique
  on public.import_plan_items (plan_id, do_number)
  where do_number is not null;

create unique index if not exists import_plan_items_plan_shipment_unique
  on public.import_plan_items (plan_id, shipment_number)
  where shipment_number is not null;