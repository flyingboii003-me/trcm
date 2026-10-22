-- Keep document references and visit context after source Plan rows are deleted.
create or replace function public.capture_visit_plan_item_snapshot()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.plan_item_id is not null
     and (tg_op = 'INSERT' or new.plan_item_id is distinct from old.plan_item_id) then
    select i.do_number, i.shipment_number, t.trip_number, t.vendor, t.destination, p.activity_type
      into new.snapshot_do_number, new.snapshot_shipment_number, new.snapshot_trip_number,
           new.snapshot_vendor, new.snapshot_destination, new.snapshot_activity_type
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
before insert or update on public.visit_plan_items
for each row execute function public.capture_visit_plan_item_snapshot();