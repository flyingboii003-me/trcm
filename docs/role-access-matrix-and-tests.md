# Matriks Akses, Pengujian Role, dan Checklist E2E TRCM

Tanggal pemeriksaan: 10 Oktober 2026  
Repository: `flyingboii003-me/trcm`  
Branch: `feature/master-data`  
Supabase project: TRCM

## Cakupan

Dokumen ini mencatat matriks permission aktual, pengujian database yang telah dijalankan, usulan penyesuaian permission, dan checklist pengujian aplikasi. Audit lanjutan terhadap kebijakan SELECT/GRANT dan fungsi SECURITY DEFINER tidak termasuk cakupan pekerjaan ini sesuai keputusan saat ini. Kebijakan SELECT yang luas tetap ada dan tidak dinyatakan telah diperbaiki.

## Matriks akses aktual

Matriks ini dibaca dari `role_permissions`, `roles`, `resources`, dan `permissions`, lalu diverifikasi untuk sejumlah permission operasional menggunakan `private.has_permission(resource, action)`. Matriks ini adalah keadaan database saat pemeriksaan, bukan pengganti pengujian browser.

| Role | Akses resource/permission yang terkonfirmasi | Catatan |
|---|---|---|
| Admin | Seluruh action pada seluruh resource yang terdaftar; WH In create/update; antrean update; Mulai/Selesai Loading update+upload; WH Out update; Master Data dan User & Role update | Sesuai konsep akses penuh. |
| Gate Security | WH In create/update/view; Antri/Parkir update/view; Mulai Loading update; WH Out update/view; Dashboard/Riwayat view | Izin Mulai Loading memungkinkan bypass dari antrean/registrasi sesuai alur operasional TRCM yang telah disepakati. Upload foto loading tidak diizinkan. |
| Checker | Mulai Loading create/update/upload/view; Selesai Loading create/update/upload/view; Dashboard/Riwayat view; Antri/Parkir view dan **create** | Tidak memiliki `queue_parking.update`, sehingga tidak dapat melakukan transisi antrean melalui jalur database yang mengharuskan permission update. Permission `queue_parking.create` tampak tidak diperlukan dan perlu dikonfirmasi/dihapus. |
| Viewer | Dashboard/Riwayat/Live View view | Permission operasional create/update/upload tidak diberikan. Viewer tetap dapat membaca data melalui SELECT policy yang ada; pembatasan baris SELECT bukan bagian dari pekerjaan ini. |

## Pengujian database yang sudah dilakukan

Semua uji tulis yang valid dilakukan dalam transaksi yang diakhiri dengan `ROLLBACK`; tidak ada data uji yang dipertahankan.

| Pengujian | Hasil |
|---|---|
| Admin: permission WH In, antrean, Mulai/Selesai Loading, WH Out, Master Data, User & Role | Lulus; permission terpilih bernilai true |
| Checker: Mulai/Selesai Loading update dan upload; tidak punya WH In/antrean update/WH Out update | Lulus; hasil sesuai permission terpilih |
| Gate Security: WH In, antrean, Mulai Loading bypass, WH Out; tidak punya upload foto loading | Lulus; hasil sesuai permission terpilih |
| Viewer: tidak punya permission create/update/upload operasional | Lulus |
| Checker menyisipkan metadata foto `loading_start` pada visit berstatus `started` | Diizinkan oleh RLS; transaksi di-rollback |
| Viewer menyisipkan metadata foto `loading_start` | Ditolak oleh RLS |
| Checker membuat event `started` yang sesuai dengan status visit | Diizinkan; transaksi di-rollback |
| Checker membuat event `completed` saat visit masih `started` | Ditolak trigger karena status event tidak sesuai dengan status visit |
| Pemeriksaan sisa artefak uji | Tidak ditemukan metadata uji yang tersimpan |

## Usulan SQL — belum diterapkan

Permission `checker:queue_parking:create` tercatat di tabel role-permission, sedangkan halaman Antri/Parkir menggunakan `queue_parking.update` untuk aksi antrean dan Checker tidak memiliki permission update tersebut. Berdasarkan PRD, Checker tidak bertugas memindahkan truk ke antrean. Jika konfirmasi operasional menyatakan permission create memang tidak dibutuhkan, hapus grant tersebut dengan SQL berikut:

```sql
DELETE FROM public.role_permissions rp
USING public.roles r, public.resources res, public.permissions p
WHERE rp.role_id = r.id
  AND rp.resource_id = res.id
  AND rp.permission_id = p.id
  AND r.key = 'checker'
  AND res.key = 'queue_parking'
  AND p.key = 'create';
```

SQL ini hanya menghapus satu hubungan role-permission, bukan menghapus data visit. SQL **belum dijalankan**. Izin `gatesec:start_loading:update` tidak diusulkan untuk dihapus karena mendukung alur bypass Gate Security yang sudah disepakati sebelumnya.

## Checklist pengujian E2E aplikasi

Pengujian database di atas tidak menggantikan pengujian browser. Tandai setiap butir setelah dilakukan pada aplikasi dengan akun role yang sesuai.

- [ ] Gate Security: WH In dan registrasi visit; data dan timestamp tersimpan.
- [ ] Gate Security: pindahkan visit ke Antri/Parkir.
- [ ] Gate Security: bypass ke Mulai Loading sesuai alur yang disepakati.
- [ ] Checker: lihat visit yang tersedia dan mulai loading.
- [ ] Checker: unggah foto awal, lalu verifikasi metadata `photos` dan file Storage.
- [ ] Checker: selesaikan loading, unggah foto akhir, lalu verifikasi metadata dan file Storage.
- [ ] Gate Security: WH Out; `wh_out_at` terisi sementara `process_status` tetap `completed`.
- [ ] Viewer: dashboard/Live View dapat dibaca, kontrol operasional tidak tersedia.
- [ ] Uji akses langsung ke URL halaman yang tidak diizinkan untuk setiap role.
- [ ] Verifikasi timeline `visit_events`, timestamp, Riwayat, dashboard, error state, empty state, dan tampilan mobile.
- [ ] Pastikan tidak ada duplikasi event atau metadata foto setelah aksi diulang.

**Status E2E:** belum dijalankan dari browser dalam sesi ini. Database connector tidak menyediakan bukti bahwa alur UI, kamera/perangkat, navigasi, dan responsivitas telah tervalidasi.

## Batasan dan tindak lanjut

1. Tidak ada perubahan SQL baru yang diterapkan selama rangkaian pemeriksaan ini.
2. Kebijakan SELECT luas pada `visits`, `visit_events`, dan `photos` tidak diubah sesuai keputusan cakupan.
3. Pengujian transisi status penuh belum dilakukan karena data saat pemeriksaan tidak mencakup semua status awal yang dibutuhkan.
4. Setelah keputusan tentang `checker:queue_parking:create`, jalankan SQL hanya jika disetujui, kemudian ulangi pemeriksaan permission dan uji role.
