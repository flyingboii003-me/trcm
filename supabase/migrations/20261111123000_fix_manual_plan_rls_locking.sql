-- Manual Plan linking runs with daftar_plan:update, which is intentionally
-- independent from operational visit UPDATE permissions. Keep the row locks,
-- but execute these narrowly-scoped RPCs as their postgres owner so RLS UPDATE
-- policies do not hide otherwise-readable visits during SELECT ... FOR SHARE.
-- Both functions retain explicit auth.uid() and daftar_plan:update checks.

alter function public.manual_link_plan_items(uuid, uuid[]) security definer;
alter function public.manual_unlink_plan_link(uuid, uuid) security definer;
