# TRCM Authorization Model

## Model

`auth.users` authenticates the account. `public.users` stores the application profile and points to a role. Roles receive permissions through `role_permissions`, and permissions target resources.

```
auth.users
  -> public.users
  -> roles
  -> role_permissions
  -> resources + permissions
```

## Initial roles

- Administrator (`admin`)
- Gate Security (`gatesec`)
- Checker (`checker`)
- Viewer (`viewer`)

## Initial permissions

- view
- create
- update
- delete
- upload
- export

## Resources

- Dashboard
- Master Data
- WH In
- Antri / Parkir
- Mulai Loading
- Selesai Loading
- WH Out
- Live View
- Riwayat
- User & Role

## User profile

`public.users` now supports:

- `full_name`
- `role_id`
- `is_active`

The existing role field is retained for compatibility while the authorization model migrates to role records.

## Authorization direction

Menu visibility in the frontend is derived from permissions, but frontend visibility is not the security boundary. Supabase RLS remains responsible for enforcing access.

User-specific permission overrides are intentionally deferred until a concrete requirement exists; the default model is role-based permissions.
