alter table public.fleet_templates
  add column if not exists license_type text,
  add column if not exists license_num text,
  add column if not exists license_exp date,
  add column if not exists vehicle_exp date,
  add column if not exists vehicle_inspect_exp date,
  add column if not exists kir_expired boolean not null default false;
