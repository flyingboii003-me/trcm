-- Simpan snapshot detail DO/Shipment yang sudah ditautkan ke visit.
-- Link dan rincian historis tetap ada meskipun baris Plan/DO/Shipment dihapus.

alter table public.visit_plan_items
  add column if not exists snapshot_do_number text,
  add column if not exists snapshot_shipment_number text,
  add column if not exists snapshot_part_number text,
  add column if not exists snapshot_product_name text,
  add column if not exists snapshot_quantity numeric(14,3),
  add column if not exists snapshot_trip_number integer,
  add column if not exists snapshot_vendor text,
  add column if not exists snapshot_destination text,
  add column if not exists snapshot_activity_type text;

update public.visit_plan_items vpi
set snapshot_do_number = i.do_number,
    snapshot_shipment_number = i.shipment_number,
    snapshot_part_number = i.part_number,
    snapshot_product_name = i.product_name,
    snapshot_quantity = i.quantity,
    snapshot_trip_number = t.trip_number,
    snapshot_vendor = t.vendor,
    snapshot_destination = t.destination,
    snapshot_activity_type = p.activity_type
from public.import_plan_items i
join public.import_plans p on p.id = i.plan_id
left join public.import_plan_trips t on t.id = i.trip_id
where i.id = vpi.plan_item_id;

alter table public.visit_plan_items alter column plan_item_id drop not null;
alter table public.visit_plan_items drop constraint if exists visit_plan_items_plan_item_id_fkey;
alter table public.visit_plan_items
  add constraint visit_plan_items_plan_item_id_fkey
  foreign key (plan_item_id) references public.import_plan_items(id) on delete set null;

create or replace function public.capture_visit_plan_item_snapshot()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.plan_item_id is not null
     and (tg_op = 'INSERT' or new.plan_item_id is distinct from old.plan_item_id) then
    select i.do_number, i.shipment_number, i.part_number, i.product_name, i.quantity,
           t.trip_number, t.vendor, t.destination, p.activity_type
      into new.snapshot_do_number, new.snapshot_shipment_number,
           new.snapshot_part_number, new.snapshot_product_name, new.snapshot_quantity,
           new.snapshot_trip_number, new.snapshot_vendor, new.snapshot_destination,
           new.snapshot_activity_type
    from public.import_plan_items i
    join public.import_plans p on p.id = i.plan_id
    left join public.import_plan_trips t on t.id = i.trip_id
    where i.id = new.plan_item_id;
  end if;
  return new;
end;
$$;

drop trigger if exists capture_visit_plan_item_snapshot on public.visit_plan_items;
create trigger capture_visit_plan_item_snapshot
before insert or update of plan_item_id on public.visit_plan_items
for each row execute function public.capture_visit_plan_item_snapshot();

create index if not exists visit_plan_items_snapshot_do_idx on public.visit_plan_items (snapshot_do_number);
create index if not exists visit_plan_items_snapshot_shipment_idx on public.visit_plan_items (snapshot_shipment_number);
