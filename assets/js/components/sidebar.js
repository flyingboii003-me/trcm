(function () {
  "use strict";

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
        if (window.innerWidth < 1200) closeSidebar();
      });
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth >= 1200) closeSidebar();
    });
  }

  function setupDesktopSidebar() {
    const toggleButton = document.getElementById("desktop-sidebar-toggle");
    if (!toggleButton) return;

    const icon = toggleButton.querySelector("i");
    const storageKey = "trcm_sidebar_minimized";

    function isDesktop() {
      return window.innerWidth > 1200;
    }

    function syncToggleState() {
      const minimized = document.body.classList.contains("sidebar-minimized");
      if (icon) icon.className = minimized ? "bi bi-chevron-bar-right" : "bi bi-chevron-bar-left";
      toggleButton.setAttribute("aria-label", minimized ? "Perluas sidebar" : "Ciutkan sidebar");
      toggleButton.setAttribute("title", minimized ? "Perluas sidebar" : "Ciutkan sidebar");
    }

    document.querySelectorAll("#sidebar [data-nav-key], #sidebar [data-menu-toggle]").forEach(function (item) {
      const label = item.querySelector("span");
      if (label && label.textContent.trim()) item.setAttribute("title", label.textContent.trim());
    });

    function applySavedState() {
      const minimized = window.localStorage.getItem(storageKey) === "true";
      document.body.classList.toggle("sidebar-minimized", isDesktop() && minimized);
      syncToggleState();
    }

    toggleButton.addEventListener("click", function () {
      if (!isDesktop()) return;

      const minimized = !document.body.classList.contains("sidebar-minimized");
      document.body.classList.toggle("sidebar-minimized", minimized);
      window.localStorage.setItem(storageKey, String(minimized));
      syncToggleState();

      window.setTimeout(function () {
        window.dispatchEvent(new Event("resize"));
      }, 300);
    });

    applySavedState();

    window.addEventListener("resize", function () {
      if (!isDesktop()) {
        document.body.classList.remove("sidebar-minimized");
      } else {
        applySavedState();
      }
    });
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.sidebar = {
    setupMobile: setupMobileSidebar,
    setupDesktop: setupDesktopSidebar
  };
})();