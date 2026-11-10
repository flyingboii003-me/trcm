# TRCM Page, Status, dan Service Contracts

Dokumen ini menjelaskan source of truth konfigurasi frontend TRCM pada `assets/js/contracts.js`.
Tujuannya agar penambahan halaman, alias status, atau endpoint layanan dilakukan pada satu kontrak,
lalu modul pemakai membaca kontrak tersebut.

## Source of truth

- `assets/js/contracts.js`: registry halaman, grup navigasi, alias status, allowlist resource/RPC,
  dan konfigurasi Storage.
- `assets/js/components/page-context.js`: adapter untuk membaca halaman aktif dari registry.
- `assets/js/components/status.js`: adapter status lama (`trcmStatusConfig`,
  `trcmStatusLabels`, `trcmVisitStatus`, `trcmStatusClass`, `trcmStatusBadge`).
- `assets/js/components/{visit,master-data,plan,photo}.js`: implementasi service yang memvalidasi
  endpoint berdasarkan allowlist di registry.
- `assets/js/components.js`: memuat `contracts.js` sebelum modul komponen lainnya.

Halaman Live View berjalan mandiri, sehingga memuat `contracts.js` secara eksplisit sebelum service.

## Pemetaan halaman

| File | Page key | Judul navigasi | Resource permission |
|---|---|---|---|
| `dashboard.html` | `dashboard` | Dashboard TRCM | `dashboard` |
| `riwayat.html` | `riwayat` | Riwayat | `history` |
| `registrasi-armada.html` | `registrasi-armada` | Registrasi Armada | `wh_in` |
| `template-armada.html` | `template-armada` | Template Armada | `fleet_templates` |
| `wh-in.html` | `wh-in` | WH In | `wh_in` |
| `antri-parkir.html` | `antri-parkir` | Antri / Parkir | `queue_parking` |
| `wh-out.html` | `wh-out` | WH Out | `wh_out` |
| `mulai-loading.html` | `mulai-loading` | Mulai Loading | `start_loading` |
| `selesai-loading.html` | `selesai-loading` | Selesai Loading | `finish_loading` |
| `master-data.html` | `master-data` | Master Data | `master_data` |
| `impor-plan.html` | `impor-plan` | Impor Plan | `import_plan_upload` |
| `daftar-plan.html` | `daftar-plan` | Daftar Plan | `daftar_plan` |
| `user-role.html` | `user-role` | User & Role | `user_role` |
| `profil.html` | `profil` | Profil Pengguna | — |
| `live-view.html` | `live-view` | Live View | `live_view` |

`data-page-resource` pada elemen `body` tetap menjadi override eksplisit. Bila atribut itu tidak ada,
page-context memakai `resourceKey` dari registry. Hal ini menjaga kompatibilitas halaman yang
memakai nama resource khusus.

Grup menu yang dipakai untuk membuka submenu otomatis juga terdaftar di `navigationGroups`:
- `kunjungan-armada`: Registrasi, WH In, Antri / Parkir, WH Out.
- `checker`: Mulai Loading, Selesai Loading.

Registry mempertahankan key kompatibilitas `checker` untuk `checker.html`, meskipun file tersebut
tidak ada dalam daftar halaman saat kontrak ini diaudit.

## Status

Status disimpan sebagai key proses dan alias. Setiap definisi berisi label/class badge yang dipakai
komponen bersama dan `liveViewLabel` yang mempertahankan teks Live View saat ini.

| Key | Label komponen | Label Live View | Class |
|---|---|---|---|
| `wh_in`, `registered` | Terdaftar | Terdaftar | `status-wh-in` |
| `queue`, `parked` | Parkir | Parkir | `status-queue` |
| `start_loading` | Proses Loading | Sedang proses | `status-start-loading` |
| `started`, `processing` | Proses | Sedang proses | `status-start-loading` |
| `done_loading`, `completed` | Selesai Loading | Selesai | `status-done-loading` |
| `wh_out` | WH Out | Keluar gudang | `status-wh-out` |

`trcmVisitStatus(visit)` tetap memprioritaskan `wh_out_at` untuk menghasilkan key `wh_out`;
jika belum keluar gudang, fungsi mengembalikan `process_status` dari record.

**Catatan konsistensi:** PRD meminta satu set label yang konsisten. Kode yang diaudit masih memiliki
variasi label antara badge komponen dan Live View (contoh: `Selesai Loading` vs `Selesai`).
Kontrak memusatkan alias dan mencatat variasi yang ada tanpa mengubah teks operasional yang telah
diuji. Penyelarasan label final perlu diputuskan sebagai perubahan UI tersendiri.

## Service contracts

Allowlist ini adalah kontrak frontend untuk mencegah service menerima endpoint di luar tanggung
jawabnya. Ini bukan pengganti authorization; permission aplikasi dan Supabase RLS tetap menjadi
batas keamanan.

| Service | REST resources | RPC | Tanggung jawab |
|---|---|---|---|
| Shared API | `/rest/v1` | — | Auth session, parsing JSON, penanganan HTTP error/401 |
| Visit | `visits` | `confirm_visit_wh_in`, `record_visit_wh_out`, `start_loading_visit`, `finish_loading_visit` | Lifecycle visit |
| Master Data | `cards`, `vendors`, `clients`, `gates`, `truck_types`, `line_numbers`, `fleet_templates` | — | Data referensi/master |
| Plan | `import_plans`, `import_plan_items`, `import_plan_trips`, `visit_plan_items` | `save_import_plan`, `update_import_plan` | Impor, daftar, dan relasi Plan |
| Photo | `photos` | — | Metadata foto dan Storage bucket `trcm-visit-photos` |

### Kontrak pemanggilan

- Semua service menerima path REST relatif yang diawali `/rest/v1/`.
- Service `request(path, options, settings)` menolak resource/RPC yang tidak terdaftar.
- `list`, `create`, `update`, `remove`, dan `rpc` yang tersedia pada masing-masing service
  tetap mempertahankan signature dan perilaku sebelumnya.
- Photo Service mengelola metadata `photos` dan objek Storage. Kegagalan Storage tetap ditangani
  sesuai perilaku metode upload/remove/signed URL yang sudah ada.
- Pengecualian request khusus halaman (misalnya pembacaan actor event best-effort) tidak otomatis
  dipindahkan ke service tanpa audit perilaku terlebih dahulu.

## Aturan perubahan berikutnya

1. Halaman baru: tambahkan satu entri `pages`; pastikan `data-page-resource` dan atribut sidebar
   `data-nav-key` / `data-resource-key` sesuai.
2. Status/alias baru: tambahkan satu definisi `statuses`; jangan menambah mapping status lokal baru
   tanpa alasan tampilan yang terdokumentasi.
3. Endpoint baru: tambahkan resource/RPC pada service pemiliknya, kemudian tambahkan test allowlist
   untuk endpoint yang diterima dan ditolak.
4. Perubahan kontrak harus menjaga API publik service dan tidak mengubah workflow/permission/database
   tanpa bukti kebutuhan serta review terpisah.
5. Setiap perubahan halaman harus memeriksa direct URL guard, judul halaman, active menu, dan akses
   berdasarkan resource permission.

## Batas audit

Kontrak ini memusatkan konfigurasi frontend yang telah teridentifikasi pada branch
`feature/refactor-components-srp`. Tidak ada perubahan schema, migration, RLS, permission grants,
atau definisi workflow database dalam Tahap 3 ini.
