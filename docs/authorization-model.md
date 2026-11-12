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
- Admin Office (`office_admin`)

Role tambahan dapat dibuat melalui halaman User & Role dan tidak dibatasi pada daftar role awal.

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
- Hubungkan Plan

## User profile

`public.users` now supports:

- `full_name`
- `role_id`
- `is_active`

`role_id` is the source of truth for authorization. The `role` column is retained as a text compatibility mirror containing the selected role key. It is intentionally `text`, not a PostgreSQL enum, so roles created through User & Role can be assigned without a schema migration for every new role.

## Authorization direction

Menu visibility in the frontend is derived from permissions, but frontend visibility is not the security boundary. Supabase RLS remains responsible for enforcing access.

User-specific permission overrides are intentionally deferred until a concrete requirement exists; the default model is role-based permissions.


## Permission-driven enforcement

Resource/action permissions are the authorization source for application features. A role key such as `admin`, `gatesec`, `checker`, or `office_admin` must not grant or deny a feature by itself.

- Frontend actions use `window.trcmPermissions.can(resource, action)`.
- RLS policies use `private.has_permission(resource, action)`.
- Operational status transitions use the permission for the transition being performed.
- User & Role Edge Function endpoints require `user_role.create`, `user_role.update`, or `user_role.delete` according to HTTP method.
- History edit and delete are independently controlled by `history.update` and `history.delete`.
- Plan edit and delete are independently controlled by `daftar_plan.update` and `daftar_plan.delete`.
- Manual Plan linking and unlinking are independently controlled by `hubungkan_plan.update`; page access uses `hubungkan_plan.view`.

Role-name checks remain only for explicit system safeguards or business invariants, not as a second feature authorization layer. Examples include protecting the built-in `admin` role from modification/deletion in the User & Role screen and the Gate Security shipment-identifier lock before WH Out.

The legacy `public.is_admin()` helper is retained for compatibility, but the active Plan write/delete RLS policies no longer use it.
