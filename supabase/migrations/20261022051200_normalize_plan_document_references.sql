-- Normalize legacy item-level imports to one row per DO/Shipment reference.
-- Remove duplicate visit links before remapping IDs to avoid the visit/document unique constraint.
with ranked_links as (
  select v.id,
         row_number() over (
           partition by v.visit_id, i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by v.linked_at, v.id
         ) as rn
  from public.visit_plan_items v
  join public.import_plan_items i on i.id=v.plan_item_id
  where coalesce(i.do_number, i.shipment_number) is not null
)
delete from public.visit_plan_items v
using ranked_links r
where v.id=r.id and r.rn>1;

with ranked as (
  select i.id, i.plan_id,
         row_number() over (
           partition by i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by (exists(select 1 from public.visit_plan_items v where v.plan_item_id=i.id)) desc,
                    i.created_at, i.id
         ) as rn,
         first_value(i.id) over (
           partition by i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by (exists(select 1 from public.visit_plan_items v where v.plan_item_id=i.id)) desc,
                    i.created_at, i.id
         ) as canonical_id
  from public.import_plan_items i
  where coalesce(i.do_number, i.shipment_number) is not null
)
update public.visit_plan_items vpi
set plan_item_id = ranked.canonical_id
from ranked
where ranked.rn > 1 and vpi.plan_item_id = ranked.id;

with ranked as (
  select i.id, i.manual_processed,
         row_number() over (
           partition by i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by (exists(select 1 from public.visit_plan_items v where v.plan_item_id=i.id)) desc,
                    i.created_at, i.id
         ) as rn,
         first_value(i.id) over (
           partition by i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by (exists(select 1 from public.visit_plan_items v where v.plan_item_id=i.id)) desc,
                    i.created_at, i.id
         ) as canonical_id
  from public.import_plan_items i
  where coalesce(i.do_number, i.shipment_number) is not null
)
update public.import_plan_items canonical
set manual_processed = coalesce(canonical.manual_processed,false) or exists (
  select 1 from ranked where ranked.canonical_id=canonical.id and ranked.manual_processed is true
)
where canonical.id in (select canonical_id from ranked where rn=1);

with ranked as (
  select i.id,
         row_number() over (
           partition by i.plan_id, coalesce(i.do_number, i.shipment_number)
           order by (exists(select 1 from public.visit_plan_items v where v.plan_item_id=i.id)) desc,
                    i.created_at, i.id
         ) as rn
  from public.import_plan_items i
  where coalesce(i.do_number, i.shipment_number) is not null
)
delete from public.import_plan_items i
using ranked
where i.id=ranked.id and ranked.rn>1;

update public.import_plans p
set row_count = (select count(*) from public.import_plan_items i where i.plan_id=p.id),
    updated_at = now()
where exists (select 1 from public.import_plan_items i where i.plan_id=p.id);