-- Prevent unauthenticated callers from invoking the operational loading RPC.
revoke execute on function public.start_loading_visit(uuid, uuid, uuid, text, text, uuid[]) from anon;
