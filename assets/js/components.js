(function () {
  "use strict";

  const container = document.getElementById("sidebar-container");
  const topbarContainer = document.getElementById("topbar-container");
  const detailContainer = document.getElementById("visit-detail-container");
  const tableToolbarContainer = document.getElementById("table-toolbar-container");
  const permissionState = new Set();

  if (!container) {
    window.trcmSidebarReady = Promise.resolve(false);
    window.trcmComponentsReady = window.trcmSidebarReady;
    return;
  }

  function currentPageKey() {
    const page = window.location.pathname.split("/").pop().toLowerCase();

    if (page === "dashboard.html" || page === "") return "dashboard";
    if (page === "riwayat.html") return "riwayat";
    if (page === "registrasi-armada.html") { return new URLSearchParams(window.location.search).get("view") === "wh-in" ? "wh-in" : "wh-in"; }
    if (page === "wh-out.html") return "wh-out";
    if (page === "antri-parkir.html") return "antri-parkir";
    if (page === "mulai-loading.html") return "mulai-loading";
    if (page === "selesai-loading.html") return "selesai-loading";
    if (page === "checker.html") return "checker";
    if (page === "master-data.html") return "master-data";
    if (page === "user-role.html") return "user-role";

    return "";
  }

  function currentPageResourceKey() {
    const page = currentPageKey();
    return {
      dashboard: "dashboard",
      riwayat: "history",
      "wh-in": "wh_in",
      "antri-parkir": "queue_parking",
      "wh-out": "wh_out",
      "mulai-loading": "start_loading",
      "selesai-loading": "finish_loading",
      "master-data": "master_data",
      "user-role": "user_role"
    }[page] || "";
  }

  function showPageAccessDenied() {
    const main = document.querySelector("main") || document.body;
    main.innerHTML = '<div class="container-fluid py-5"><div class="card border-0 shadow-sm"><div class="card-body text-center py-5"><div class="mb-3"><i class="bi bi-shield-lock fs-1 text-secondary"></i></div><h4 class="mb-2">Akses tidak tersedia</h4><p class="text-secondary mb-4">Anda tidak memiliki permission untuk membuka halaman ini.</p><a class="btn btn-primary" href="dashboard.html">Kembali ke Dashboard</a></div></div></div>';
  }

  async function loadMyMenuPermissions() {
    const session = (() => {
      try { return JSON.parse(sessionStorage.getItem("trcm_session") || "null"); }
      catch { return null; }
    })();
    const accessToken = session && session.access_token;
    if (!accessToken) return null;

    const response = await fetch("https://pcednpmjyfkuomfcmian.supabase.co/rest/v1/rpc/get_my_permissions", {
      method: "POST",
      headers: {
        "apikey": "sb_publishable_ERlBrySRotVM5jfLA1oukQ_Cg0gmgIp",
        "Authorization": "Bearer " + accessToken,
        "Content-Type": "application/json"
      },
      body: "{}"
    });

    if (!response.ok) throw new Error("Permission user gagal dimuat.");
    const rows = await response.json();

    permissionState.clear();
    (Array.isArray(rows) ? rows : []).forEach(function (row) {
      const resourceKey = String(row.resource_key || "");
      const permissionKey = String(row.permission_key || "");
      if (resourceKey && permissionKey) {
        permissionState.add(resourceKey + ":" + permissionKey);
      }
    });

    return new Set((Array.isArray(rows) ? rows : [])
      .filter(function (row) { return String(row.permission_key || "") === "view"; })
      .map(function (row) { return String(row.resource_key || ""); }));
  }

  window.trcmPermissions = {
    can: function (resourceKey, permissionKey) {
      return permissionState.has(String(resourceKey || "") + ":" + String(permissionKey || ""));
    },
    apply: function (root) {
      const scope = root || document;
      scope.querySelectorAll("[data-permission]").forEach(function (element) {
        const value = String(element.getAttribute("data-permission") || "");
        const separatorIndex = value.indexOf(":");
        if (separatorIndex < 1) return;
        const resourceKey = value.slice(0, separatorIndex);
        const permissionKey = value.slice(separatorIndex + 1);
        element.hidden = !window.trcmPermissions.can(resourceKey, permissionKey);
      });
    },
    canView: function (resourceKey) {
      return permissionState.has(String(resourceKey || "") + ":view");
    },
    loaded: function () {
      return permissionState.size > 0;
    }
  };

  async function applyPermissionVisibility() {

    const sidebar = document.getElementById("sidebar");
    if (sidebar) sidebar.style.visibility = "hidden";

    try {
      document.querySelectorAll("[data-resource-key]").forEach(function (element) {
        const resourceKey = element.getAttribute("data-resource-key");
        const visible = permissionState.has(String(resourceKey || "") + ":view");
        const item = element.closest(".sidebar-menu-item") || element;
        item.hidden = !visible;
      });

      document.querySelectorAll("[data-resource-group]").forEach(function (group) {
        const submenu = group.nextElementSibling;
        const hasVisibleChild = submenu && Array.from(submenu.querySelectorAll("[data-resource-key]")).some(function (item) {
          const li = item.closest(".sidebar-menu-item") || item;
          return !li.hidden;
        });
        const parentItem = group.closest(".sidebar-menu-item");
        if (parentItem) parentItem.hidden = !hasVisibleChild;
      });

      syncCollapsibleMenuState();
    } finally {
      if (sidebar) sidebar.style.visibility = "";
    }
  }

  async function enforcePagePermission() {
    const resourceKey = currentPageResourceKey();
    if (!resourceKey) return true;

    if (permissionState.has(resourceKey + ":view")) return true;

    showPageAccessDenied();
    return false;
  }

  function setupCollapsibleMenus() {
    const toggles = document.querySelectorAll("[data-menu-toggle]");
    toggles.forEach(function (toggle) {
      const menuKey = toggle.getAttribute("data-menu-toggle");
      const submenu = document.querySelector('[data-menu-submenu="' + menuKey + '"]');
      if (!submenu) return;

      toggle.addEventListener("click", function () {
        const expanded = toggle.getAttribute("aria-expanded") === "true";
        toggle.setAttribute("aria-expanded", String(!expanded));
        submenu.hidden = expanded;
        toggle.classList.toggle("is-expanded", !expanded);
      });
    });
  }

  function syncCollapsibleMenuState() {
    const key = currentPageKey();
    const menus = [
      { key: "kunjungan-armada", children: ["wh-in", "antri-parkir", "wh-out"] },
      { key: "checker", children: ["mulai-loading", "selesai-loading"] }
    ];

    menus.forEach(function (menu) {
      const toggle = document.querySelector('[data-menu-toggle="' + menu.key + '"]');
      const submenu = document.querySelector('[data-menu-submenu="' + menu.key + '"]');
      if (!toggle || !submenu) return;

      const isChildActive = menu.children.includes(key);
      toggle.setAttribute("aria-expanded", String(isChildActive));
      toggle.classList.toggle("is-expanded", isChildActive);
      submenu.hidden = !isChildActive;
    });
  }

  function setActiveMenu() {
    const key = currentPageKey();

    syncCollapsibleMenuState();

    document.querySelectorAll("[data-nav-key]").forEach(function (link) {
      const active = link.getAttribute("data-nav-key") === key;

      link.classList.toggle("active", active);

      if (active) {
        link.setAttribute("aria-current", "page");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  function setPageTitle() {
    const titles = {
      dashboard: "Dashboard TRCM",
      riwayat: "Riwayat",
      "registrasi-armada": "WH In",
      "wh-in": "WH In",
      "wh-out": "WH Out",
      "master-data": "Master Data",
      "user-role": "User & Role"
    };

    const key = currentPageKey();
    const title = titles[key] || "TRCM";

    document.querySelectorAll("[data-page-title]").forEach(function (element) {
      element.textContent = title;
    });
  }

  function setAccountNames() {
    let session = null;

    try {
      session = JSON.parse(sessionStorage.getItem("trcm_session") || "null");
    } catch {
      session = null;
    }

    const username =
      session &&
      session.user &&
      (session.user.username || session.user.auth_email);

    const displayName = username || "Akun";

    document
      .querySelectorAll("#account-name, #account-menu-name, #sidebar-account-name")
      .forEach(function (element) {
        element.textContent = displayName;
      });
  }

  function setupMobileSidebar() {
    const sidebar = document.getElementById("sidebar");
    const menuButton = document.getElementById("menu-button");
    const backdrop = document.getElementById("sidebar-backdrop");

    if (!sidebar || !menuButton || !backdrop) return;

    function closeSidebar() {
      sidebar.classList.remove("is-open");
      backdrop.classList.remove("is-visible");
      menuButton.setAttribute("aria-expanded", "false");
    }

    menuButton.addEventListener("click", function () {
      const isOpen = sidebar.classList.toggle("is-open");

      backdrop.classList.toggle("is-visible", isOpen);
      menuButton.setAttribute("aria-expanded", String(isOpen));
    });

    backdrop.addEventListener("click", closeSidebar);

    sidebar.querySelectorAll("a").forEach(function (link) {
      link.addEventListener("click", function () {
        if (window.innerWidth < 1200) {
          closeSidebar();
        }
      });
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth >= 1200) {
        closeSidebar();
      }
    });
  }

  function setupLogout() {
    const logoutButton = document.getElementById("account-logout");

    if (!logoutButton) return;

    logoutButton.addEventListener("click", function () {
      sessionStorage.removeItem("trcm_session");
      window.location.replace("../index.html");
    });
  }

  function loadFragment(url, target, required) {
    if (!target) return Promise.resolve(true);

    return fetch(url, {
      method: "GET",
      headers: { Accept: "text/html" }
    })
      .then(function (response) {
        if (!response.ok) throw new Error("Komponen gagal dimuat: " + url);
        return response.text();
      })
      .then(function (html) {
        target.innerHTML = html;
        return true;
      })
      .catch(function (error) {
        console.error("TRCM component:", error);
        if (required) target.innerHTML = "";
        return false;
      });
  }

  window.trcmSidebarReady = loadFragment("../components/sidebar.html", container, true)
    .then(function (loaded) {
      if (loaded) {
        setupCollapsibleMenus();
        setActiveMenu();
      }
      return loaded;
    });

  window.trcmComponentsReady = Promise.all([
    window.trcmSidebarReady,
    loadFragment("../components/topbar.html", topbarContainer, false),
    loadFragment("../components/visit-detail.html", detailContainer, false),
    loadFragment("../components/table-toolbar.html", tableToolbarContainer, false)
  ]).then(async function (results) {
    const loaded = results.every(Boolean);

    if (!loaded) return false;

    setPageTitle();
    setAccountNames();
    setupMobileSidebar();
    setupLogout();

    try {
      const allowed = await loadMyMenuPermissions();
      if (!allowed) return true;
      const permitted = await enforcePagePermission();
      if (permitted) {
        await applyPermissionVisibility();
        window.trcmPermissions.apply(document);
        setActiveMenu();
      }
      return permitted;
    } catch (error) {
      console.error("TRCM permission guard:", error);
      showPageAccessDenied();
      return false;
    }
  });

  const statusConfig = {
    wh_in: { label: "Terdaftar", className: "status-wh-in" },
    queue: { label: "Antri/Parkir", className: "status-queue" },
    queue: { label: "Antri/Parkir", className: "status-queue" },
    start_loading: { label: "Proses Loading", className: "status-start-loading" },
    done_loading: { label: "Selesai Loading", className: "status-done-loading" },
    wh_out: { label: "WH Out", className: "status-wh-out" },
    registered: { label: "Terdaftar", className: "status-wh-in" },
    started: { label: "Proses Loading", className: "status-start-loading" },
    completed: { label: "Selesai Loading", className: "status-done-loading" }
  };

  window.trcmStatusConfig = statusConfig;
  window.trcmStatusLabels = Object.keys(statusConfig).reduce(function (labels, key) {
    labels[key] = statusConfig[key].label;
    return labels;
  }, {});

  window.trcmVisitStatus = function (visit) {
    if (visit && visit.wh_out_at) return "wh_out";
    return visit && visit.process_status ? visit.process_status : "";
  };

  window.trcmStatusClass = function (status) {
    const safeStatus = String(status || "");
    return statusConfig[safeStatus] ? statusConfig[safeStatus].className : "status-unknown";
  };

  window.trcmStatusBadge = function (status) {
    const safeStatus = String(status || "");
    const config = statusConfig[safeStatus];
    const label = config ? config.label : safeStatus || "—";
    const className = config ? config.className : "status-unknown";
    return '<span class="status-badge ' + className + '">' +
      '<span class="status-dot"></span>' + escapeHtml(label) + '</span>';
  };

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, function (character) {
      return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[character];
    });
  }
})();
