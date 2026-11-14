(function () {
  "use strict";

  const releases = [
    { version:"1.14.3", date:"2026-11-12", pr:42, categories:{
      Added:["Permission data `plan_data` menjadi satu akses baca untuk header, item, trip, dan metadata importer Plan."],
      Changed:["Pembacaan data Plan disatukan menggunakan permission `plan_data.view` agar akses lintas komponen Plan mengikuti aturan yang konsisten."],
      Security:["Kebijakan RLS diperbarui dan metadata pembuat Plan disediakan melalui RPC terbatas yang hanya mengembalikan informasi tampilan bagi pengguna berwenang."]
    } },
    { version:"1.14.2", date:"2026-11-12", pr:41, categories:{ Added:["Dokumentasi standar authorization dan RLS serta audit akses baca untuk membantu peninjauan kebijakan keamanan TRCM."] } },
    { version:"1.14.1", date:"2026-11-12", pr:40, categories:{ Fixed:["Informasi pembuat Plan kini dapat dibaca oleh pengguna yang memiliki izin melihat Plan atau Riwayat, tanpa membuka seluruh data pengguna."] } },
    { version:"1.14.0", date:"2026-11-12", pr:39, categories:{
      Added:["Halaman Hubungkan Plan untuk menghubungkan dan melepas hubungan item Plan dengan visit secara manual.","Menu Manajemen Plan yang mengelompokkan Daftar Plan, Impor Plan, dan Hubungkan Plan."],
      Changed:["Tampilan Daftar Plan dan Hubungkan Plan dirapikan; informasi identitas Plan yang tidak diperlukan disembunyikan.","Akses dan proses pengaitan Plan disesuaikan dengan permission khusus serta perlindungan data yang relevan."],
      Fixed:["Pencarian visit dan pengaitan Plan historis diperbaiki, termasuk penguncian baris agar perubahan hubungan tetap konsisten."]
    } },
    { version:"1.13.2", date:"2026-11-11", pr:37, categories:{ Fixed:["Perhitungan kartu Menunggu dan Sedang proses pada Dashboard diperjelas agar status antre atau parkir tidak ikut dihitung sebagai proses muat/bongkar."] } },
    { version:"1.13.1", date:"2026-11-11", pr:38, categories:{ Added:["Filter Klien pada Dashboard untuk menyaring KPI, monitoring operasional, grafik aktivitas, daftar visit, dan ringkasan Plan."] } },
    { version:"1.13.0", date:"2026-11-10", pr:36, categories:{ Changed:["Struktur komponen dan service layer dirapikan, kontrak bersama diperjelas, dan pemanggilan API dimigrasikan agar kode lebih konsisten dan mudah dirawat.","Dokumentasi teknis diperbarui serta referensi Dashboard diperbaiki."] } },
    { version:"1.12.3", date:"2026-11-10", pr:35, categories:{ Added:["Metrik Plan ditambahkan ke monitoring Dashboard.","Dukungan beberapa foto WH In disediakan untuk dokumentasi kunjungan."], Fixed:["Penanganan KIR kedaluwarsa dan sejumlah detail tampilan Plan diperbaiki."] } },
    { version:"1.12.2", date:"2026-11-09", pr:34, categories:{ Changed:["Monitoring Dashboard diperbarui agar mencerminkan perubahan armada dan Plan."] } },
    { version:"1.12.1", date:"2026-11-09", pr:33, categories:{ Security:["Akses foto kunjungan menggunakan kebijakan penyimpanan privat untuk membatasi file kepada pengguna TRCM yang berwenang."] } },
    { version:"1.12.0", date:"2026-11-05", pr:32, categories:{ Added:["Otorisasi berbasis permission diterapkan pada halaman dan operasi data, termasuk dukungan role dinamis."], Security:["Kebijakan RLS, trigger, dan Edge Functions diperketat agar operasi mengikuti izin pengguna."] } },
    { version:"1.11.2", date:"2026-11-02", pr:30, categories:{ Added:["Monitoring operasional ditambahkan ke Dashboard untuk membantu melihat kondisi proses gudang."] } },
    { version:"1.11.1", date:"2026-10-30", pr:29, categories:{ Added:["Ekspor analisis kunjungan ke Excel dengan rentang tanggal, ringkasan, detail kunjungan, dan durasi."] } },
    { version:"1.11.0", date:"2026-10-29", pr:28, categories:{ Added:["Nilai Vendor dan tipe truk khusus dapat disimpan dan digunakan pada proses pendaftaran."], Security:["Kebijakan akses data disesuaikan untuk mendukung nilai master khusus."] } },
    { version:"1.10.0", date:"2026-10-27", pr:27, categories:{ Fixed:["Rekonsiliasi RPC operasional, akses Plan/Shipment, dan beberapa perilaku antarmuka diperbaiki."] } },
    { version:"1.9.0", date:"2026-10-23", pr:25, categories:{ Changed:["Alur Plan difokuskan pada kunjungan armada dan referensi DO/Shipment; data item kargo yang tidak lagi diperlukan dihapus dari alur tersebut."] } },
    { version:"1.8.0", date:"2026-10-21", pr:24, categories:{ Changed:["Alur Checker Plan, pemilihan Shipment, pengelompokan Impor Plan, WH In, antrean, Riwayat, dan role diselaraskan."], Fixed:["Sejumlah masalah integrasi antarmodul Plan dan proses operasional diperbaiki."] } },
    { version:"1.7.0", date:"2026-10-21", pr:23, categories:{ Added:["Pengelolaan Daftar Plan mendukung pembaruan, revisi, dan penghapusan Plan."], Changed:["Penggantian data Plan dilakukan secara transaksional dan mengikuti permission pengguna."] } },
    { version:"1.6.5", date:"2026-10-20", pr:22, categories:{ Added:["Validasi header pada Impor Plan ditambahkan, termasuk pemetaan alias header dan pratinjau data."], Fixed:["Pemeriksaan duplikasi Shipment dilakukan sebelum data diimpor."] } },
    { version:"1.6.4", date:"2026-10-19", pr:21, categories:{ Fixed:["Tata letak konfirmasi Impor Plan diperbaiki untuk penggunaan di perangkat mobile."] } },
    { version:"1.6.3", date:"2026-10-19", pr:20, categories:{ Added:["Field dokumen pada Fleet Template dilengkapi agar data template dapat digunakan lebih lengkap."] } },
    { version:"1.6.2", date:"2026-10-19", pr:19, categories:{ Changed:["Registrasi Armada dan konfirmasi WH In dipisahkan agar setiap tahap memiliki alur yang lebih jelas.","Checklist pemeriksaan ditambahkan pada proses konfirmasi."] } },
    { version:"1.6.1", date:"2026-10-16", pr:18, categories:{ Added:["Pemilih Klien ditambahkan pada proses impor Plan."], Removed:["Field foto loading yang tidak lagi diperlukan dihilangkan dari form impor Plan."] } },
    { version:"1.6.0", date:"2026-10-16", pr:17, categories:{ Added:["Integrasi fitur profil, role, dan workflow operasional disatukan ke aplikasi TRCM."] } },
    { version:"1.5.4", date:"2026-10-16", pr:16, categories:{ Removed:["Perbandingan dengan hari sebelumnya di Status Armada dihapus agar ringkasan hanya menampilkan informasi yang relevan."] } },
    { version:"1.5.3", date:"2026-10-12", pr:15, categories:{ Added:["Workflow Checker untuk WH In dilengkapi dengan pemeriksaan kelayakan Checker, unggah foto, dan permission yang sesuai."] } },
    { version:"1.5.2", date:"2026-10-12", pr:14, categories:{ Fixed:["Bagian ringkasan pada form Registrasi Armada diperbaiki."] } },
    { version:"1.5.1", date:"2026-10-10", pr:13, categories:{ Added:["Pengguna dapat mengelola profil sendiri.","Atribusi Checker, dokumentasi foto WH In, dan matriks role/permission dilengkapi."], Changed:["Alur Checker disesuaikan dengan aturan akses dan tanggung jawab masing-masing role."] } },
    { version:"1.5.0", date:"2026-10-10", pr:12, categories:{ Added:["Pembaruan data secara real-time, informasi profil, atribusi Checker, dan filter Klien ditambahkan."], Changed:["Izin penghapusan Riwayat dan pencatatan pelaku aktivitas disesuaikan dengan hak akses."] } },
    { version:"1.4.0", date:"2026-10-10", pr:11, categories:{ Added:["Pengelolaan Master Data untuk Kartu, Vendor, Klien, Gerbang, dan Line dilengkapi dengan fungsi tambah, ubah, hapus, pencarian, serta status aktif."] } },
    { version:"1.3.1", date:"2026-10-07", pr:10, categories:{ Added:["Unggah beberapa foto untuk WH Out dengan pilihan kamera atau galeri."], Changed:["Modal mobile, lencana status, dan pratinjau foto pada penyimpanan privat disempurnakan."] } },
    { version:"1.3.0", date:"2026-10-07", pr:9, categories:{ Added:["Workflow Kunjungan Armada dan Gate Security ditambahkan, termasuk antrean, parkir, WH Out, status kunjungan, dan pencatatan aktivitas."] } },
    { version:"1.2.1", date:"2026-10-06", pr:8, categories:{ Added:["Penyempurnaan modal Riwayat dan Dashboard serta navigasi mobile."], Changed:["Kolom Kartu dan pencarian pada tampilan terkait disesuaikan."] } },
    { version:"1.2.0", date:"2026-10-06", pr:6, categories:{ Changed:["Registrasi, status, dan waktu Dashboard dirapikan; waktu Inbound WH In dan grafik responsif disesuaikan.","Alur Bongkar dan Muat pada shipment diperjelas."] } },
    { version:"1.1.1", date:"2026-10-06", pr:5, categories:{ Added:["Umpan balik keberhasilan menggunakan SweetAlert ditambahkan pada aksi terkait."] } },
    { version:"1.1.0", date:"2026-10-06", pr:4, categories:{ Added:["Gate Security ditambahkan untuk registrasi kendaraan beserta data master pendukung."] } },
    { version:"1.0.2", date:"2026-10-06", pr:3, categories:{ Changed:["Tombol pada Dashboard dan Riwayat disempurnakan agar lebih konsisten."] } },
    { version:"1.0.1", date:"2026-10-06", pr:2, categories:{ Changed:["Tampilan diselaraskan dengan Spark Admin dan palet warna CJ Logistics; pencarian global dihapus."] } },
    { version:"1.0.0", date:"2026-10-05", pr:1, categories:{ Added:["Fondasi antarmuka TRCM dibangun menggunakan Spark Admin, mencakup Dashboard, Riwayat, komponen bersama, lencana status, dan navigasi responsif."] } }
  ];

  const categoryOrder = ["Added", "Changed", "Deprecated", "Removed", "Fixed", "Security"];
  const list = document.getElementById("changelog-list");
  const count = document.getElementById("changelog-release-count");

  function createElement(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  }

  function renderRelease(release) {
    const article = createElement("article", "changelog-release");
    article.id = "version-" + release.version.replace(/[^a-z0-9]+/gi, "-").toLowerCase();
    article.setAttribute("aria-labelledby", article.id + "-title");

    const top = createElement("div", "changelog-release-top");
    const headingWrap = createElement("div", "changelog-release-heading-main");
    const marker = createElement("span", "changelog-release-marker");
    marker.setAttribute("aria-hidden", "true");
    const heading = createElement("h3", "", "");
    heading.id = article.id + "-title";
    const version = createElement("span", "changelog-release-version", "[" + release.version + "]");
    heading.appendChild(version);
    headingWrap.append(marker, heading);

    const meta = createElement("div", "");
    const date = createElement("time", "changelog-release-date", release.date);
    date.dateTime = release.date;
    const prLink = createElement("a", "changelog-pr-link");
    prLink.href = "https://github.com/flyingboii003-me/trcm/pull/" + release.pr;
    prLink.target = "_blank";
    prLink.rel = "noopener noreferrer";
    prLink.setAttribute("aria-label", "Buka Pull Request #" + release.pr);
    prLink.append(createElement("span", "", "PR #" + release.pr), createElement("i", "bi bi-box-arrow-up-right"));
    meta.append(date);
    top.append(headingWrap, meta);
    article.append(top);

    categoryOrder.forEach(function (category) {
      const entries = release.categories[category];
      if (!Array.isArray(entries) || entries.length === 0) return;
      const section = createElement("section", "changelog-category changelog-category--" + category.toLowerCase());
      const subheading = createElement("h4", "", category);
      const ul = createElement("ul", "");
      entries.forEach(function (entry) {
        ul.appendChild(createElement("li", "", entry));
      });
      section.append(subheading, ul);
      article.appendChild(section);
    });

    meta.appendChild(prLink);
    return article;
  }

  function render() {
    if (!list || !count) return;
    list.replaceChildren();
    releases.forEach(function (release) {
      list.appendChild(renderRelease(release));
    });
    count.textContent = releases.length + " versi tercatat";
  }

  function initialize() {
    const session = typeof getTrcmSession === "function" ? getTrcmSession() : null;
    if (!session || !session.access_token || !session.user) {
      window.location.replace("../index.html");
      return;
    }
    if (window.trcmComponentsReady && typeof window.trcmComponentsReady.then === "function") {
      window.trcmComponentsReady.then(function (ready) {
        if (ready === false) return;
        render();
      });
    } else {
      render();
    }
  }

  initialize();
})();
