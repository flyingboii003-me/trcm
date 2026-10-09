create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.resources (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  type text not null default 'page' check (type in ('page','action')),
  parent_id uuid references public.resources(id) on delete set null,
  route text,
  icon text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  resource_id uuid not null references public.resources(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (role_id, resource_id, permission_id)
);

alter table public.users add column if not exists full_name text;
alter table public.users add column if not exists role_id uuid references public.roles(id) on delete restrict;
alter table public.users add column if not exists is_active boolean not null default true;

insert into public.roles (key,name,description) values
('admin','Administrator','Akses administrasi dan pengelolaan sistem.'),
('gatesec','Gate Security','Akses operasional Gate Security.'),
('checker','Checker','Akses operasional Checker.'),
('viewer','Viewer','Akses baca untuk monitoring.')
on conflict (key) do update set name=excluded.name,description=excluded.description;

insert into public.permissions (key,name,description) values
('view','View','Melihat resource.'),
('create','Create','Membuat data.'),
('update','Update','Mengubah data.'),
('delete','Delete','Menghapus data.'),
('upload','Upload','Mengunggah file atau foto.'),
('export','Export','Mengekspor data.')
on conflict (key) do update set name=excluded.name,description=excluded.description;

insert into public.resources (key,name,type,route,sort_order) values
('dashboard','Dashboard','page','pages/dashboard.html',10),
('master_data','Master Data','page','pages/master-data.html',20),
('wh_in','WH In','page','pages/registrasi-armada.html',30),
('queue_parking','Antri / Parkir','page','pages/antri-parkir.html',40),
('start_loading','Mulai Loading','page','pages/mulai-loading.html',50),
('finish_loading','Selesai Loading','page','pages/selesai-loading.html',60),
('wh_out','WH Out','page','pages/wh-out.html',70),
('live_view','Live View','page','pages/live-view.html',80),
('history','Riwayat','page','pages/riwayat.html',85),
('user_role','User & Role','page','pages/user-role.html',90)
on conflict (key) do update set name=excluded.name,route=excluded.route;

update public.users u set role_id=r.id from public.roles r where r.key=u.role::text and u.role_id is null;
update public.users set full_name=coalesce(nullif(full_name,''),username) where full_name is null or full_name='';

insert into public.role_permissions(role_id,resource_id,permission_id)
select r.id,res.id,p.id from public.roles r cross join public.resources res cross join public.permissions p
where r.key='admin' on conflict do nothing;

insert into public.role_permissions(role_id,resource_id,permission_id)
select r.id,res.id,p.id from public.roles r join public.resources res on res.key in ('dashboard','wh_in','queue_parking','wh_out','history') join public.permissions p on p.key='view'
where r.key='gatesec' on conflict do nothing;

insert into public.role_permissions(role_id,resource_id,permission_id)
select r.id,res.id,p.id from public.roles r join public.resources res on res.key in ('dashboard','start_loading','finish_loading','history') join public.permissions p on p.key='view'
where r.key='checker' on conflict do nothing;

insert into public.role_permissions(role_id,resource_id,permission_id)
select r.id,res.id,p.id from public.roles r join public.resources res on res.key in ('dashboard','history','live_view') join public.permissions p on p.key='view'
where r.key='viewer' on conflict do nothing;
