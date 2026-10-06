-- TRCM Gate Security registration master-data revision
-- Executed against the TRCM Supabase project.
insert into public.vendors (name)
select name from (values
  ('SIL'),('BAJS'),('NCL'),('TPIL'),('SPIL'),('MGS'),
  ('MIF'),('LGL'),('SML'),('SPP'),('SHUTTLE CJ'),('LAINNYA')
) as seed(name)
where not exists (select 1 from public.vendors v where upper(v.name)=upper(seed.name));

insert into public.clients (name)
select name from (values ('Kimberly Clark'),('Modena'),('Henkel')) as seed(name)
where not exists (select 1 from public.clients c where upper(c.name)=upper(seed.name));

alter table public.visits rename column manifest_number to destination_city;
