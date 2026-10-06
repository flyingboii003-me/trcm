-- Expand the card master to the SID001-SID999 range and rename the visit direction field.
insert into public.cards (card_number, is_active)
select 'SID' || lpad(gs::text, 3, '0'), true
from generate_series(1, 999) as gs
where not exists (
  select 1 from public.cards c
  where c.card_number = 'SID' || lpad(gs::text, 3, '0')
);

alter table public.visits rename column destination to activity_type;
