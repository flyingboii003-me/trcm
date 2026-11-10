(function () {
  "use strict";

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
    const key = window.TRCM.pageContext.getCurrentPageKey();
    const menus = [
      { key: "kunjungan-armada", children: ["registrasi-armada", "wh-in", "antri-parkir", "wh-out"] },
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
    const key = window.TRCM.pageContext.getCurrentPageKey();
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
    const title = window.TRCM.pageContext.getCurrentPageTitle();
    document.querySelectorAll("[data-page-title]").forEach(function (element) {
      element.textContent = title;
    });
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.navigation = {
    setupCollapsibleMenus: setupCollapsibleMenus,
    syncCollapsibleMenuState: syncCollapsibleMenuState,
    setActiveMenu: setActiveMenu,
    setPageTitle: setPageTitle
  };
})();