(function () {
  "use strict";

  const container = document.getElementById("sidebar-container");

  if (!container) {
    window.trcmSidebarReady = Promise.resolve(false);
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

  window.trcmSidebarReady = fetch("../components/sidebar.html", {
    method: "GET",
    headers: {
      Accept: "text/html"
    }
  })
    .then(function (response) {
      if (!response.ok) {
        throw new Error("Sidebar gagal dimuat.");
      }

      return response.text();
    })
    .then(function (html) {
      container.innerHTML = html;

      setActiveMenu();
      setAccountNames();
      setupMobileSidebar();
      setupLogout();

      return true;
    })
    .catch(function (error) {
      console.error("TRCM components:", error);
      container.innerHTML = "";
      return false;
    });
})();
