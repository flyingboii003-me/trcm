# Audit Permission dan RLS TRCM

Status: **snapshot audit read-only; rekomendasi belum diterapkan**  
Tanggal snapshot: 12 November 2026  
Sumber: Supabase TRCM live database, `public.roles`, `public.resources`, `public.permissions`, `public.role_permissions`, `pg_policies`, katalog tabel PostgreSQL, dan Supabase Security Advisor.

> Dokumen ini membedakan konfigurasi yang benar-benar terbaca dari rekomendasi. Snapshot database dapat berubah setelah dokumen ini dibuat; jalankan ulang query audit sebelum migration authorization berikutnya.

## 1. Ringkasan

- Ditemukan **19 tabel** pada schema `public`; seluruhnya mengaktifkan RLS.
- Seluruh 19 tabel memiliki `FORCE ROW LEVEL SECURITY = false`.
- Semua resource yang terdaftar saat snapshot bertipe `page` atau `action`; belum ada resource bertipe `data`.
- Role permission sudah dikelola dinamis melalui `role_permissions`.
- Beberapa tabel memiliki SELECT policy `USING (true)`; policy permissive ini membuka semua baris tabel kepada role `authenticated` dan tidak dibatasi oleh permission fitur.
- Kasus importer Plan adalah mismatch permission: Plan parent/child dapat dibaca melalui `daftar_plan.view`, sedangkan policy SELECT profil pembuat hanya mengizinkan `import_plan.view`.
- Checker **memiliki** `daftar_plan.view` pada snapshot database. Catatan lama yang menyebut Checker tidak memiliki permission ini tidak sesuai dengan konfigurasi live saat audit.
- Belum ada perubahan database, migration, role grant, atau policy sebagai bagian dari audit ini.

## 2. Resource yang terdaftar

Seluruh resource aktif pada snapshot:

| Resource key | Type | Keterangan |
|---|---|---|
| `dashboard` | page | Dashboard |
| `master_data` | page | Master Data |
| `import_plan` | page | Impor Plan |
| `import_plan_upload` | page | Impor Plan upload |
| `daftar_plan` | page | Daftar Plan |
| `hubungkan_plan` | page | Hubungkan Plan |
| `wh_in` | page | WH In |
| `fleet_templates` | action | Template Armada |
| `queue_parking` | page | Antri / Parkir |
| `start_loading` | page | Mulai Loading |
| `finish_loading` | page | Selesai Loading |
| `wh_out` | page | WH Out |
| `live_view` | page | Live View |
| `history` | page | Riwayat |
| `user_role` | page | User & Role |

Belum ada resource bertipe `data`. Usulan `plan_data` dijelaskan di `docs/authorization-standard.md`. Importer termasuk domain `plan_data`; tidak dibuat resource `plan_creator_data`.

## 3. Role permission aktual

Matriks berikut merupakan grant yang terbaca dari `role_permissions` pada saat snapshot. Ini bukan rekomendasi final dan bukan bukti E2E UI.

| Role | Grant aktual |
|---|---|
| `admin` | Semua action yang tersedia pada seluruh resource terdaftar |
| `checker` | `daftar_plan.view`; `dashboard.view`; `start_loading.view/update/upload`; `finish_loading.view/update/upload`; `history.view` |
| `gatesec` | `dashboard.view`; `fleet_templates.view/create/update/delete`; `history.view/update/delete`; `queue_parking.view/update`; `wh_in.view/create/update/upload`; `wh_out.view/update` |
| `office_admin` | `dashboard.view`; `daftar_plan.view/create/update/delete`; `import_plan.view/create/update/delete`; `import_plan_upload.view/create/update/delete`; `hubungkan_plan.view/update`; `history.view/export`; `live_view.view` |
| `viewer` | `dashboard.view`; `history.view`; `live_view.view` |

Catatan:
- Admin memiliki seluruh action yang tersedia pada resource yang terdaftar, termasuk action yang tidak digunakan oleh role lain.
- `fleet_templates` merupakan resource bertipe `action`, bukan page.
- Role grant adalah snapshot. Jika role atau permission berubah, matriks ini harus diperbarui.
- Role `checker` memang memiliki `daftar_plan.view` pada database live saat pemeriksaan. Jika kebijakan produk menghendaki Checker tidak membuka halaman Daftar Plan, grant tersebut perlu dibahas terpisah; jangan menghapusnya sebagai bagian dari perbaikan importer tanpa persetujuan workflow.

## 4. Inventaris RLS per tabel

Semua tabel berikut memiliki RLS aktif. `FORCE RLS` tidak aktif pada semua tabel.

| Tabel | SELECT policy aktif | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `cards` | `authenticated can view dashboard cards`: `true` | `master_data.create` | `master_data.update` | `master_data.delete` |
| `clients` | `authenticated can view dashboard clients`: `true` | `master_data.create` | `master_data.update` | `master_data.delete` |
| `fleet_templates` | `fleet_templates.view` | `fleet_templates.create` | `fleet_templates.update` | `fleet_templates.delete` |
| `gates` | `authenticated can view dashboard gates`: `true` | `master_data.create` | `master_data.update` | `master_data.delete` |
| `import_plans` | OR: `import_plan.view`, `daftar_plan.view`, `history.view`, `hubungkan_plan.view` | `import_plan.create` | `daftar_plan.update` | `daftar_plan.delete` |
| `import_plan_items` | Parent Plan harus cocok dan salah satu: `import_plan.view`, `daftar_plan.view`, `history.view`, `hubungkan_plan.view` | Parent Plan + `import_plan.create` atau `daftar_plan.update` | `daftar_plan.update` | `daftar_plan.update` atau `daftar_plan.delete` |
| `import_plan_trips` | Parent Plan harus cocok dan salah satu: `import_plan.view`, `daftar_plan.view`, `history.view`, `hubungkan_plan.view` | Parent Plan + `import_plan.create` atau `daftar_plan.update` | `daftar_plan.update` | `daftar_plan.update` atau `daftar_plan.delete` |
| `line_numbers` | `authenticated can view dashboard line numbers`: `true` | `master_data.create` | `master_data.update` | `master_data.delete` |
| `permissions` | `user_role.view` | `user_role.create` | `user_role.update` | `user_role.delete` |
| `photos` | `authenticated can view dashboard photos`: `true` | `uploaded_by = auth.uid()` dan permission + status visit sesuai tipe foto | Tidak ada policy UPDATE | Permission upload sesuai `photo_type` |
| `resources` | `user_role.view` | `user_role.create` | `user_role.update` | `user_role.delete` |
| `role_permissions` | `user_role.view` | `user_role.update` | `user_role.update` | `user_role.update` |
| `roles` | `user_role.view` | `user_role.create` | `user_role.update` | `user_role.delete` |
| `truck_types` | `master_data.view` OR `wh_in.view` | `master_data.create` OR `wh_in.create` | `master_data.update` | `master_data.delete` |
| `users` | OR: `user_role.view` untuk profil yang lolos policy; atau `import_plan.view` untuk baris user yang menjadi `created_by` Plan | `user_role.create` | `user_role.update` | `user_role.delete` |
| `vendors` | `authenticated can view dashboard vendors`: `true` | `master_data.create` OR `wh_in.create` | `master_data.update` | `master_data.delete` |
| `visit_events` | `authenticated can view dashboard visit events`: `true` | Status event harus sesuai permission workflow (WH In, queue, start, finish, WH Out) | Tidak ada policy UPDATE | Tidak ada policy DELETE |
| `visit_plan_items` | OR: `history.view`, `import_plan.view`, `daftar_plan.view`, `start_loading.update`, `finish_loading.update`, `hubungkan_plan.view` | Permission loading atau linking + validasi Plan/visit | Tidak ada policy UPDATE | `import_plan.delete` atau `daftar_plan.update` dengan visit belum WH Out |
| `visits` | OR: `authenticated can view dashboard visits` (`true`) dan `hubungkan_plan_select_visits` (`hubungkan_plan.view`) | `wh_in.create` | Permission transisi berdasarkan `process_status` | `history.delete` |

Catatan interpretasi:
- `USING` adalah syarat baris yang dapat dibaca/diubah/dihapus; `WITH CHECK` adalah syarat baris baru pada INSERT atau UPDATE.
- Pada tabel dengan beberapa policy permissive untuk operasi yang sama, PostgreSQL menggabungkannya dengan OR.
- Tabel yang tidak memiliki policy untuk suatu operasi tidak memberikan izin operasi tersebut melalui policy RLS.
- Tabel ini merangkum policy aktif yang terbaca, bukan audit SQL grants, Storage object policies, view, trigger, atau seluruh fungsi database.

## 5. Temuan prioritas

### HIGH — SELECT `USING (true)` pada delapan tabel

Policy SELECT `true` ditemukan pada:

- `cards`
- `clients`
- `gates`
- `line_numbers`
- `photos`
- `vendors`
- `visit_events`
- `visits`

Semua policy tersebut berlaku untuk `authenticated`. Konsekuensinya, setiap pengguna authenticated yang dapat mengakses tabel melalui API dapat membaca seluruh baris yang dicakup policy, tanpa pemeriksaan permission domain.

Pada `visits), terdapat policy kedua yang mensyaratkan `hubungkan_plan.view`; policy tersebut tidak membatasi hasil karena policy `true` tetap mengizinkan baris melalui OR.

Pada `photos`, pembacaan metadata foto tidak dibatasi oleh permission workflow walaupun INSERT dan DELETE sudah memakai permission berdasarkan tipe foto.

Rekomendasi: tentukan kebutuhan baca per halaman/domain, lalu ganti policy luas secara bertahap dengan permission data dan scope baris yang disetujui. Jangan langsung mencabut policy sebelum dashboard, live view, history, dan workflow operasional memiliki policy pengganti serta pengujian.

### HIGH — Akses Plan dan metadata importer tidak konsisten

Policy SELECT parent/child Plan menerima:

- `import_plan.view`
- `daftar_plan.view`
- `history.view`
- `hubungkan_plan.view`

Role Checker pada snapshot memiliki `daftar_plan.view`, sehingga policy Plan dapat mengizinkan Checker membaca Plan.

Namun policy SELECT tambahan pada `public.users` untuk importer hanya mengizinkan:

```sql
private.has_permission('import_plan', 'view')
and exists (
  select 1
  from public.import_plans p
  where p.created_by = users.id
)
```

Checker tidak memiliki `import_plan.view` pada snapshot. Akibatnya, relasi importer dapat tidak terbaca walaupun parent Plan terbaca.

Standar target: importer adalah bagian dari domain `plan_data`; satu permission `plan_data.view` mengatur Plan dan metadata importer. Jangan membuat `plan_creator_data`.

Catatan implementasi: RLS pada `users` membatasi baris, bukan kolom. Jangan memberikan akses seluruh profil pengguna hanya demi menampilkan nama importer. Gunakan proyeksi profil minimum yang tervalidasi.

### MEDIUM — Beberapa policy permissive untuk operasi yang sama

Ditemukan beberapa tabel dengan lebih dari satu policy pada operasi yang sama:

- `visits`: dua SELECT policy.
- `users`: dua SELECT policy.
- `truck_types`: dua INSERT policy.
- `vendors`: dua INSERT policy.

Kombinasi policy dapat memang disengaja, tetapi harus diperiksa sebagai satu ekspresi OR. Policy yang lebih ketat tidak menjadi pembatas jika policy lain sudah mengizinkan operasi secara lebih luas.

### MEDIUM — RLS tidak di-FORCE pada semua tabel

Semua 19 tabel memiliki `relrowsecurity = true`, tetapi `relforcerowsecurity = false`.

Ini berarti table owner dapat melewati RLS dalam konteks PostgreSQL normal. Hal ini tidak otomatis menjadi celah bagi pengguna API biasa, tetapi harus diperhitungkan saat meninjau owner, migration, fungsi SECURITY DEFINER, dan jalur administratif. Jangan mengaktifkan FORCE secara massal tanpa uji dampak.

### MEDIUM — Security Advisor: 8 fungsi SECURITY DEFINER

Supabase Security Advisor pada 12 November 2026 melaporkan 8 fungsi SECURITY DEFINER yang dapat dieksekusi role `authenticated`:

| Fungsi | Catatan pemeriksaan |
|---|---|
| `public.get_my_menu_permissions()` | Pastikan hanya mengembalikan permission pemanggil |
| `public.get_my_permissions()` | Pastikan hanya mengembalikan permission pemanggil |
| `public.get_my_profile()` | Pastikan hanya mengembalikan profil pemanggil |
| `public.get_visit_event_actors(uuid)` | Pastikan permission dan scope visit diverifikasi |
| `public.has_role(public.user_role)` | Tinjau kebutuhan expose helper berbasis role |
| `public.is_admin()` | Tinjau compatibility dan kebutuhan expose |
| `public.manual_link_plan_items(uuid, uuid[])` | RPC mutasi; validasi permission, visit, Plan, dan item |
| `public.manual_unlink_plan_link(uuid, uuid)` | RPC mutasi; validasi permission, visit, dan link |

Peringatan advisor bukan bukti eksploitasi. Periksa definisi fungsi, `EXECUTE` grants, `search_path`, validasi `auth.uid()`, permission, dan scope sebelum memutuskan revoke atau mengubah security mode. Dua RPC manual Plan secara eksplisit menggunakan `hubungkan_plan.update` pada implementasi migration yang diperiksa; jangan menghapus hak SECURITY DEFINER tanpa pengganti yang diuji.

### LOW/MEDIUM — Leaked Password Protection nonaktif

Supabase Auth melaporkan leaked password protection nonaktif. Aktifkan setelah meninjau dampak pada proses login/password dan komunikasi kepada pengguna.

## 6. Kasus Checker dan Plan

Konfigurasi database live saat audit:

- Checker memiliki `start_loading.view`, `start_loading.update`, dan `start_loading.upload`.
- Checker memiliki `daftar_plan.view`.
- Checker tidak memiliki `import_plan.view`.
- SELECT `import_plans`, `import_plan_items`, dan `import_plan_trips` menerima `daftar_plan.view`.
- SELECT profil importer di `public.users` hanya menerima `import_plan.view`.
- Karena itu, akses Plan dan akses profil importer tidak konsisten.

Selain policy, query halaman harus meminta relasi/field importer dan UI harus merendernya. RLS yang benar saja tidak akan menampilkan field yang tidak diminta query.

## 7. Rekomendasi tindak lanjut berurutan

1. **Tetapkan domain permission**: tambah resource data `plan_data` dan tentukan role yang memang membutuhkan baca Plan. Importer tetap satu domain dengan Plan.
2. **Perbaiki Plan read path**: samakan policy parent, item, trip, dan proyeksi importer pada `plan_data.view`; definisikan scope baris yang tepat.
3. **Audit SELECT true**: mulai dari `visits`, `photos`, dan `visit_events`, lalu master/reference tables. Petakan konsumen UI/API sebelum mengganti policy.
4. **Konsolidasikan policy permissive**: khususnya SELECT `visits/users` dan INSERT `vendors/truck_types`; pertahankan perilaku bisnis yang memang diperlukan.
5. **Review SECURITY DEFINER**: verifikasi fungsi satu per satu beserta grants dan search_path.
6. **Review SQL grants dan Storage**: audit privilege tabel/kolom, bucket, dan object policy yang belum termasuk snapshot ini.
7. **Jalankan pengujian role**: akun/JWT Admin, Office Admin, Gate Security, Checker, dan Viewer; uji akses yang diizinkan dan ditolak.
8. **Perbarui dokumen**: catat hasil migration, hasil uji API, E2E, dan advisor setelah perubahan.

## 8. Query verifikasi yang digunakan

Snapshot ini berasal dari query read-only setara dengan:

```sql
select n.nspname, c.relname, c.relrowsecurity, c.relforcerowsecurity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind = 'r'
order by c.relname;
```

```sql
select schemaname, tablename, policyname, permissive, roles,
       cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;
```

Role grants dibaca dengan join `role_permissions`, `roles`, `resources`, dan `permissions`.

## 9. Batasan audit

Belum dilakukan dalam audit ini:

- Pengujian langsung menggunakan JWT/akun terpisah untuk setiap role.
- Pengujian API/PostgREST dan embedded relation end-to-end.
- Audit semua SQL table/column grants.
- Audit Storage bucket/object policies.
- Pemeriksaan definisi lengkap seluruh fungsi SECURITY DEFINER.
- Pemeriksaan semua view, trigger, Edge Function, dan akses service role.
- Pengujian UI browser dan workflow operasional.

**Status akhir:** inventaris role, resource, RLS table/policy, dan Security Advisor berhasil dibaca secara read-only. Rekomendasi belum diterapkan. Tidak ada perubahan database.
