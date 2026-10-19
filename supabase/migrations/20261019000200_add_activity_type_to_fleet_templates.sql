alter table public.fleet_templates
  add column if not exists activity_type text;

alter table public.fleet_templates
  drop constraint if exists fleet_templates_activity_type_check;

alter table public.fleet_templates
  add constraint fleet_templates_activity_type_check
  check (activity_type is null or activity_type in ('inbound', 'outbound'));
