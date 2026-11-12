# Standar Authorization dan RLS TRCM

Status: **standar usulan untuk review**  
Disusun: 12 November 2026  
Basis: `docs/authorization-model.md`, role-permission aktif, policy RLS aktif, dan alur Plan/Loading yang diperiksa pada Supabase TRCM.

## 1. Tujuan

Dokumen ini menetapkan pola authorization yang konsisten untuk fitur baru dan perubahan fitur TRCM. Tujuannya:

- Memisahkan hak membuka halaman dari hak membaca atau mengubah data.
- Memungkinkan beberapa halaman menggunakan domain data yang sama tanpa saling memberikan akses halaman.
- Menjaga pembatasan baris data di database melalui RLS.
- Mencegah relasi PostgREST gagal dimuat karena tabel relasi memiliki policy yang berbeda.
- Menjadikan permission dan cakupan data dapat diaudit serta diuji.

Dokumen ini adalah standar desain. Penambahan resource, grant role, perubahan policy, view, RPC, atau migration tetap harus dilakukan melalui perubahan kode/migration terpisah dan review.

## 2. Fondasi yang dipertahankan

TRCM sudah memiliki model authorization:

`auth.users -> public.users -> roles -> role_permissions -> resources + permissions`

Ketentuan yang dipertahankan:

1. `public.users.role_id` adalah sumber role aplikasi.
2. Role memperoleh permission melalui `public.role_permissions`.
3. Permission mengacu pada resource dan action.
4. Frontend memakai `window.trcmPermissions.can(resource, action)` untuk mengatur navigasi dan kontrol UI.
5. Database memakai `private.has_permission(resource, action)` sebagai pemeriksaan permission.
6. Frontend bukan batas keamanan. Akses API langsung tetap harus dilindungi database/RPC.
7. Nama role tidak boleh menjadi lapisan otorisasi fitur kedua. Pengecualian hanya untuk safeguard sistem atau invariant bisnis yang terdokumentasi.

Tidak perlu mengganti model role-permission yang sudah ada.

## 3. Tiga lapisan authorization

### 3.1 Page permission

Menentukan apakah pengguna boleh membuka halaman atau route.

Contoh resource bertipe `page`:

- `daftar_plan.view`
- `start_loading.view`
- `history.view`
- `hubungkan_plan.view`

Page permission tidak otomatis memberikan hak baca/tulis ke semua tabel yang digunakan halaman.

### 3.2 Data permission

Menentukan operasi yang boleh dilakukan pada domain data, terlepas dari halaman yang menggunakannya.

Resource bertipe `data` yang diusulkan:

| Resource | Makna |
|---|---|
| `plan_data` | Data Plan secara utuh, termasuk header, item, trip, dan metadata importer |
| `visit_data` | Data visit dan detail operasional |
| `visit_event_data` | Timeline/event visit |
| `photo_data` | Metadata foto dan referensi file |
| `master_data_read` | Jika dibutuhkan, akses baca master data lintas workflow |

Daftar ini adalah usulan. Jangan membuat resource data hanya karena sebuah tabel ada; buat berdasarkan domain dan kebutuhan bisnis yang jelas.

**Ketentuan khusus Plan:** identitas importer adalah bagian dari `plan_data`, bukan resource permission terpisah. Nama pembuat Plan, `created_by`, waktu import, header Plan, item, dan trip mengikuti kebijakan akses domain Plan yang sama. Jangan membuat `plan_creator_data`.

### 3.3 Data scope

Data permission menentukan jenis operasi; data scope menentukan baris mana yang dapat diakses.

Contoh batasan scope yang dapat digunakan sesuai aturan bisnis:

- Plan untuk client yang relevan dengan visit.
- Plan dengan status aktif ketika digunakan untuk linking/loading.
- Visit yang sesuai dengan client dan activity type.
- Data yang berada pada hub atau lokasi kerja pengguna, jika TRCM menerapkan pembatasan tersebut.

Jangan mengasumsikan semua tabel harus memiliki scope yang sama. Tetapkan scope per domain dan dokumentasikan alasan bisnisnya.

## 4. Standar nama resource dan action

Gunakan `resource.action` dengan key resource stabil dan lowercase.

Action yang tersedia pada model awal TRCM:

- `view`: membaca data atau membuka halaman.
- `create`: membuat data.
- `update`: mengubah data.
- `delete`: menghapus data.
- `upload`: mengunggah file/metadata sesuai workflow.
- `export`: mengekspor data.

Makna action mengikuti resource. Pada resource `page`, `view` berarti akses halaman. Pada resource `data`, `view` berarti akses baca domain data.

Hindari:
- Menggunakan page resource untuk menjadi izin SELECT tabel secara permanen.
- Memberi akses hanya dengan membandingkan `role.key`.
- Menggunakan satu permission luas untuk operasi yang berbeda risiko.
- Menganggap `authenticated` sama dengan “boleh membaca semua data”.

## 5. Standar penerapan Plan

### 5.1 Permission tunggal untuk seluruh domain Plan

Gunakan `plan_data.view` untuk membaca:

- `public.import_plans`
- `public.import_plan_items`
- `public.import_plan_trips`
- Relasi metadata importer yang dibutuhkan untuk menampilkan Plan.

Nama importer adalah atribut presentasi domain Plan. Ia tidak memiliki permission data tersendiri.

Akses halaman tetap independen. Contoh: Checker dapat memiliki `start_loading.view` dan `plan_data.view` tanpa memperoleh `daftar_plan.view`. Sebaliknya, hak membuka Daftar Plan tidak otomatis memberikan `plan_data.update`.

### 5.2 Kebijakan RLS konseptual

Contoh pola dasar untuk parent Plan:

```sql
create policy import_plans_select_by_plan_data
on public.import_plans
for select
to authenticated
using (
  private.has_permission('plan_data', 'view')
);
```

Child table harus menguji permission domain yang sama dan memastikan parent Plan yang menaunginya dapat dibaca:

```sql
create policy import_plan_items_select_by_plan_data
on public.import_plan_items
for select
to authenticated
using (
  exists (
    select 1
    from public.import_plans p
    where p.id = import_plan_items.plan_id
      and private.has_permission('plan_data', 'view')
  )
);
```

Terapkan pola ekuivalen pada `import_plan_trips`. Contoh di atas adalah pola permission, bukan migration siap pakai: scope baris, policy yang sudah ada, dan perilaku PostgREST harus dievaluasi sebelum implementasi.

### 5.3 Metadata importer dan prinsip least privilege

PostgreSQL RLS membatasi baris, bukan kolom. Jangan membuka seluruh kolom `public.users` hanya untuk menampilkan nama importer.

Gunakan proyeksi khusus yang hanya menyediakan kolom identitas minimum yang diperlukan, misalnya ID, username, dan full name. Implementasinya dapat berupa view/RPC khusus yang:
- hanya mengembalikan kolom yang dibutuhkan;
- memverifikasi `plan_data.view`;
- hanya mengembalikan profil yang terkait dengan Plan yang dapat dibaca pemanggil;
- tidak memberikan akses umum ke tabel profil pengguna.

View/RPC tersebut harus diuji dengan role yang memiliki dan tidak memiliki `plan_data.view`. Jangan membuat permission `plan_creator_data`; kontrol aksesnya tetap bagian dari `plan_data`.

## 6. Aturan RLS wajib

1. Setiap tabel yang diekspos melalui API harus mengaktifkan RLS.
2. Policy harus menyebut role database secara eksplisit, umumnya `authenticated`, dan menggunakan permission domain yang sesuai.
3. SELECT pada tabel relasi harus dievaluasi terpisah; izin parent tidak otomatis mengizinkan child table.
4. INSERT menggunakan `WITH CHECK`; UPDATE harus memeriksa `USING` dan `WITH CHECK`; DELETE harus memiliki `USING`.
5. Hindari policy permissive `USING (true)` kecuali data memang dirancang untuk dibaca semua pengguna authenticated. Alasan dan kolom yang terekspos harus terdokumentasi.
6. PostgreSQL menggabungkan policy permissive dengan OR. Policy tambahan yang sempit tidak membatasi policy `true` yang sudah ada.
7. RLS membatasi baris, bukan kolom. Terapkan proyeksi/privilege kolom untuk data sensitif.
8. Periksa grants SQL, view security mode, RPC grants, trigger, dan fungsi `SECURITY DEFINER`; RLS bukan satu-satunya jalur akses.
9. Jangan mengubah fungsi `SECURITY DEFINER` secara massal. Periksa validasi identitas, permission, search_path, grants, dan kebutuhan hak pemilik fungsi.
10. Jangan memakai `FORCE ROW LEVEL SECURITY` atau mengubahnya tanpa memahami efek terhadap owner, service role, dan fungsi administratif.

## 7. Frontend dan API

- Frontend menggunakan page permission untuk route/menu dan kontrol UI.
- Frontend boleh meminta data domain jika workflow memerlukannya; RLS tetap menjadi otoritas akhir.
- Jangan menyembunyikan error RLS dengan mengganti data kosong menjadi data palsu.
- Untuk relasi PostgREST, verifikasi SELECT terhadap parent, child, dan tabel relasi yang di-embed.
- Error permission harus dibedakan dari empty state dan network error.

## 8. Checklist setiap fitur baru

Sebelum merge, developer wajib menyertakan:

- [ ] Daftar route/page permission.
- [ ] Daftar domain data dan permission yang diperlukan.
- [ ] Daftar tabel, view, RPC, dan Storage bucket yang disentuh.
- [ ] SELECT/INSERT/UPDATE/DELETE policy yang relevan.
- [ ] Scope baris dan aturan akses lintas client/hub jika berlaku.
- [ ] Daftar kolom sensitif dan cara membatasi proyeksinya.
- [ ] Permission role yang perlu ditambahkan/dihapus.
- [ ] Uji role yang diizinkan dan role yang ditolak.
- [ ] Uji API langsung, bukan hanya UI.
- [ ] Uji embedded relation/PostgREST.
- [ ] Uji regresi workflow yang menggunakan domain yang sama.

## 9. Strategi migrasi

1. Inventarisasi permission, policy, SQL grants, view, RPC, Storage, dan trigger.
2. Tentukan role yang memang membutuhkan tiap domain data.
3. Tambahkan resource bertipe `data` dan grant melalui migration.
4. Migrasikan policy domain satu per satu; jangan menghapus policy lama sebelum pengganti dan uji siap.
5. Uji semua role melalui JWT/akun terpisah.
6. Periksa hasil Security Advisor.
7. Hapus policy lama yang redundant hanya setelah verifikasi.
8. Perbarui matriks audit dan dokumentasi role.

## 10. Keputusan desain

- Page permission dan data permission adalah dua hal berbeda.
- Data permission tidak otomatis membuka halaman.
- Page permission tidak otomatis membuka tabel.
- Data scope tetap wajib ketika domain memiliki batasan client, visit, status, atau lokasi.
- Importer adalah bagian dari domain `plan_data`; tidak ada `plan_creator_data`.
- Tidak ada konsep “semua authenticated boleh membaca semua data” sebagai default.
- Database tetap menjadi batas keamanan utama.
