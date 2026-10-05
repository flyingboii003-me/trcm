(function () {
  "use strict";

  const container = document.getElementById("sidebar-container");
  const topbarContainer = document.getElementById("topbar-container");
  const detailContainer = document.getElementById("visit-detail-container");
  const tableToolbarContainer = document.getElementById("table-toolbar-container");

  if (!container) {
    window.trcmSidebarReady = Promise.resolve(false);
    window.trcmComponentsReady = window.trcmSidebarReady;
    return;
  }

  function currentPageKey() {
    const page = window.location.pathname.split("/").pop().toLowerCase();

    if (page === "dashboard.html" || page === "") return "dashboard";
    if (page === "riwayat.html") return "riwayat";
    if (page === "checker.html") return "checker";
    if (page === "master-data.html") return "master-data";

    return "";
  }

  function setActiveMenu() {
    const key = currentPageKey();

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
      riwayat: "Riwayat"
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
        setActiveMenu();
      }
      return loaded;
    });

  window.trcmComponentsReady = Promise.all([
    window.trcmSidebarReady,
    loadFragment("../components/topbar.html", topbarContainer, false),
    loadFragment("../components/visit-detail.html", detailContainer, false),
    loadFragment("../components/table-toolbar.html", tableToolbarContainer, false)
  ]).then(function (results) {
    const loaded = results.every(Boolean);

    if (loaded) {
      setActiveMenu();
      setPageTitle();
      setAccountNames();
      setupMobileSidebar();
      setupLogout();
    }

    return loaded;
  });

  window.trcmStatusBadge = function (status) {
    const labels = {
      registered: "Terdaftar",
      started: "Sedang proses",
      completed: "Selesai"
    };
    const safeStatus = String(status || "");
    const label = labels[safeStatus] || safeStatus || "—";
    return '<span class="status-badge status-' + escapeHtml(safeStatus) + '">' +
      '<span class="status-dot"></span>' + escapeHtml(label) + '</span>';
  };

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, function (character) {
      return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[character];
    });
  }
})();
