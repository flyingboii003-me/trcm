-- Allow authenticated callers to evaluate the existing permission helper used by RLS and save_import_plan.
-- The helper returns only a boolean for the requested permission.
grant usage on schema private to authenticated;
grant execute on function private.has_permission(text, text) to authenticated;
