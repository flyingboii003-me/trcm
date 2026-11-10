(function () {
  "use strict";

  const pageKeys = {
    "dashboard.html": "dashboard",
    "riwayat.html": "riwayat",
    "registrasi-armada.html": "registrasi-armada",
    "template-armada.html": "template-armada",
    "wh-in.html": "wh-in",
    "wh-out.html": "wh-out",
    "antri-parkir.html": "antri-parkir",
    "mulai-loading.html": "mulai-loading",
    "selesai-loading.html": "selesai-loading",
    "checker.html": "checker",
    "master-data.html": "master-data",
    "impor-plan.html": "impor-plan",
    "daftar-plan.html": "daftar-plan",
    "user-role.html": "user-role",
    "profil.html": "profil",
    "live-view.html": "live-view"
  };

  const resourceKeys = {
    dashboard: "dashboard",
    riwayat: "history",
    "wh-in": "wh_in",
    "antri-parkir": "queue_parking",
    "wh-out": "wh_out",
    "mulai-loading": "start_loading",
    "selesai-loading": "finish_loading",
    "master-data": "master_data",
    "user-role": "user_role"
  };

  const pageTitles = {
    dashboard: "Dashboard TRCM",
    riwayat: "Riwayat",
    "registrasi-armada": "Registrasi Armada",
    "template-armada": "Template Armada",
    "wh-in": "WH In",
    "wh-out": "WH Out",
    "master-data": "Master Data",
    "user-role": "User & Role",
    profil: "Profil Pengguna",
    "live-view": "Live View"
  };

  function getCurrentPageKey() {
    const page = window.location.pathname.split("/").pop().toLowerCase();
    return pageKeys[page] || (page === "" ? "dashboard" : "");
  }

  function getCurrentPageResourceKey() {
    const explicitResource = document.body && document.body.getAttribute("data-page-resource");
    if (explicitResource) return explicitResource;
    return resourceKeys[getCurrentPageKey()] || "";
  }

  function getCurrentPageTitle() {
    return pageTitles[getCurrentPageKey()] || "TRCM";
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.pageContext = {
    getCurrentPageKey: getCurrentPageKey,
    getCurrentPageResourceKey: getCurrentPageResourceKey,
    getCurrentPageTitle: getCurrentPageTitle
  };
})();