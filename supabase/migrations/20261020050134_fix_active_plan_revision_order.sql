do $$
declare
  v_def text;
  v_old_insert text := $old$  insert into public.import_plans (client_id,operational_date,activity_type,revision,status,row_count,created_by,activated_at)
  values (v_source.client_id,p_operational_date,v_source.activity_type,v_revision,p_status,v_row_count,auth.uid(),
    case when p_status='active' then now() else null end)
  returning id into v_new_plan_id;$old$;
  v_new_insert text := $new$  -- Release the source scope before inserting an active revision.
  -- The transaction rolls this change back if any later step fails.
  if p_status='active' then
    update public.import_plans set status='superseded',updated_at=now()
    where id=v_source.id and status='active';
  end if;

  insert into public.import_plans (client_id,operational_date,activity_type,revision,status,row_count,created_by,activated_at)
  values (v_source.client_id,p_operational_date,v_source.activity_type,v_revision,p_status,v_row_count,auth.uid(),
    case when p_status='active' then now() else null end)
  returning id into v_new_plan_id;$new$;
  v_old_later text := $old$  if p_status='active' then
    update public.import_plans set status='superseded',updated_at=now() where id=v_source.id and status='active';
  end if;

$old$;
begin
  select pg_get_functiondef('public.create_import_plan_revision(uuid,date,jsonb,text)'::regprocedure) into v_def;
  if position(v_old_insert in v_def)=0 then raise exception 'Expected revision insert block not found; migration aborted'; end if;
  if position(v_old_later in v_def)=0 then raise exception 'Expected source supersede block not found; migration aborted'; end if;
  v_def := replace(v_def, v_old_insert, v_new_insert);
  v_def := replace(v_def, v_old_later, '');
  execute v_def;
end $$;
