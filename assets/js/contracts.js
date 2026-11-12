(function () {
  "use strict";

  window.TRCM = window.TRCM || {};

  const pages = {
    dashboard: { file: "dashboard.html", title: "Dashboard TRCM", resourceKey: "dashboard" },
    riwayat: { file: "riwayat.html", title: "Riwayat", resourceKey: "history" },
    "registrasi-armada": { file: "registrasi-armada.html", title: "Registrasi Armada", resourceKey: "wh_in" },
    "template-armada": { file: "template-armada.html", title: "Template Armada", resourceKey: "fleet_templates" },
    "wh-in": { file: "wh-in.html", title: "WH In", resourceKey: "wh_in" },
    "antri-parkir": { file: "antri-parkir.html", title: "Antri / Parkir", resourceKey: "queue_parking" },
    "wh-out": { file: "wh-out.html", title: "WH Out", resourceKey: "wh_out" },
    "mulai-loading": { file: "mulai-loading.html", title: "Mulai Loading", resourceKey: "start_loading" },
    "selesai-loading": { file: "selesai-loading.html", title: "Selesai Loading", resourceKey: "finish_loading" },
    "master-data": { file: "master-data.html", title: "Master Data", resourceKey: "master_data" },
    "impor-plan": { file: "impor-plan.html", title: "Impor Plan", resourceKey: "import_plan_upload" },
    "daftar-plan": { file: "daftar-plan.html", title: "Daftar Plan", resourceKey: "daftar_plan" },
    "hubungkan-plan": { file: "hubungkan-plan.html", title: "Hubungkan Plan", resourceKey: "hubungkan_plan" },
    "user-role": { file: "user-role.html", title: "User & Role", resourceKey: "user_role" },
    profil: { file: "profil.html", title: "Profil Pengguna", resourceKey: "" },
    "live-view": { file: "live-view.html", title: "Live View", resourceKey: "live_view" },
    checker: { file: "checker.html", title: "Checker", resourceKey: "" }
  };

  const navigationGroups = [
    { key: "kunjungan-armada", children: ["registrasi-armada", "wh-in", "antri-parkir", "wh-out"] },
    { key: "checker", children: ["mulai-loading", "selesai-loading"] },
    { key: "manajemen-plan", children: ["daftar-plan", "impor-plan", "hubungkan-plan"] }
  ];

  const statuses = {
    wh_in: { label: "Terdaftar", className: "status-wh-in", liveViewLabel: "Terdaftar", liveViewColor: "#006ECD" },
    queue: { label: "Parkir", className: "status-queue", liveViewLabel: "Parkir", liveViewColor: "#D6A000" },
    parked: { label: "Parkir", className: "status-queue", liveViewLabel: "Parkir", liveViewColor: "#D6A000" },
    start_loading: { label: "Proses Loading", className: "status-start-loading", liveViewLabel: "Sedang proses", liveViewColor: "#F97316" },
    done_loading: { label: "Selesai Loading", className: "status-done-loading", liveViewLabel: "Selesai", liveViewColor: "#16A34A" },
    wh_out: { label: "WH Out", className: "status-wh-out", liveViewLabel: "Keluar gudang", liveViewColor: "#006ECD" },
    registered: { label: "Terdaftar", className: "status-wh-in", liveViewLabel: "Terdaftar", liveViewColor: "#006ECD" },
    started: { label: "Proses", className: "status-start-loading", liveViewLabel: "Sedang proses", liveViewColor: "#F97316" },
    processing: { label: "Proses", className: "status-start-loading", liveViewLabel: "Sedang proses", liveViewColor: "#F97316" },
    completed: { label: "Selesai Loading", className: "status-done-loading", liveViewLabel: "Selesai", liveViewColor: "#16A34A" }
  };

  const services = {
    api: { basePath: "/rest/v1", auth: "supabase-session", response: "parsed-json-or-null" },
    visit: {
      resources: ["visits"],
      rpc: ["confirm_visit_wh_in", "record_visit_wh_out", "start_loading_visit", "finish_loading_visit"]
    },
    masterData: {
      resources: ["cards", "vendors", "clients", "gates", "truck_types", "line_numbers", "fleet_templates"]
    },
    plan: {
      resources: ["import_plans", "import_plan_items", "import_plan_trips", "visit_plan_items"],
      rpc: ["save_import_plan", "update_import_plan", "manual_link_plan_items", "manual_unlink_plan_link", "get_plan_importers"]
    },
    photo: {
      resources: ["photos"],
      storageBucket: "trcm-visit-photos",
      storageOperations: ["upload", "remove", "signed-url"]
    }
  };

  window.TRCM.contracts = Object.freeze({
    version: 1,
    pages: Object.freeze(pages),
    navigationGroups: Object.freeze(navigationGroups),
    statuses: Object.freeze(statuses),
    services: Object.freeze(services)
  });
})();
