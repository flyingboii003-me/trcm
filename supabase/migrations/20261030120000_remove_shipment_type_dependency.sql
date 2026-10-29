-- Keep Gate Security's shipment-number lock without depending on visits.shipment_type.
-- Historical migrations retain their original definitions; this migration replaces the live function.
create or replace function public.prevent_gatesec_shipment_changes_before_wh_out()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  select u.role::text into v_role
  from public.users u
  where u.id = auth.uid() and u.is_active = true;

  if v_role = 'gatesec'
     and old.wh_in_at is not null
     and old.wh_out_at is null
     and new.shipment_number is distinct from old.shipment_number then
    raise exception 'GATESEC_SHIPMENT_LOCKED_UNTIL_WH_OUT';
  end if;

  return new;
end;
$$;

revoke all on function public.prevent_gatesec_shipment_changes_before_wh_out() from public, anon, authenticated;
