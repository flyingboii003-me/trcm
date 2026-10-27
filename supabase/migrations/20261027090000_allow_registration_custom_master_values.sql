-- Allow users who can register inbound visits to add master values through registration.
-- RLS remains enabled; this adds the existing operational create permission as an alternative.
CREATE POLICY "registration can insert vendors"
ON public.vendors
FOR INSERT
TO authenticated
WITH CHECK (
  private.has_permission('master_data', 'create')
  OR private.has_permission('wh_in', 'create')
);

CREATE POLICY "registration can insert truck types"
ON public.truck_types
FOR INSERT
TO authenticated
WITH CHECK (
  private.has_permission('master_data', 'create')
  OR private.has_permission('wh_in', 'create')
);
