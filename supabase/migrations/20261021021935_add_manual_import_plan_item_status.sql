alter table public.import_plan_items
  add column if not exists manual_processed boolean not null default false;
