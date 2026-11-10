(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.state = window.TRCM.state || {};
  window.TRCM.state.permissionState = window.TRCM.state.permissionState || new Set();
  window.trcmSidebarReady = Promise.resolve(false);

  const moduleNames = [
    "api.js",
    "status.js",
    "refresh.js",
    "page-context.js",
    "permissions.js",
    "navigation.js",
    "account.js",
    "sidebar.js",
    "fragments.js"
  ];
  const scriptBaseUrl = new URL("./components/", document.currentScript.src).href;

  function loadModule(name) {
    return new Promise(function (resolve, reject) {
      const script = document.createElement("script");
      script.src = scriptBaseUrl + name;
      script.async = true;
      script.onload = function () {
        script.remove();
        resolve();
      };
      script.onerror = function () {
        reject(new Error("Modul TRCM gagal dimuat: " + name));
      };
      document.head.appendChild(script);
    });
  }

  async function initializeComponents() {
    await Promise.all(moduleNames.map(loadModule));

    const sidebarContainer = document.getElementById("sidebar-container");
    const topbarContainer = document.getElementById("topbar-container");
    const detailContainer = document.getElementById("visit-detail-container");
    const tableToolbarContainer = document.getElementById("table-toolbar-container");
    const fragments = window.TRCM.fragments;
    const navigation = window.TRCM.navigation;

    window.trcmSidebarReady = fragments.load("../components/sidebar.html", sidebarContainer, true)
      .then(function (loaded) {
        if (loaded) {
          navigation.setupCollapsibleMenus();
          navigation.setActiveMenu();
        }
        return loaded;
      });

    const results = await Promise.all([
      window.trcmSidebarReady,
      fragments.load("../components/topbar.html", topbarContainer, false),
      fragments.load("../components/visit-detail.html", detailContainer, false),
      fragments.load("../components/table-toolbar.html", tableToolbarContainer, false)
    ]);

    if (!results.every(Boolean)) return false;

    navigation.setPageTitle();
    window.TRCM.account.setNames();
    window.TRCM.sidebar.setupMobile();
    window.TRCM.sidebar.setupDesktop();
    window.TRCM.account.setupLogout();
    window.TRCM.account.setupProfileButton();

    try {
      const allowed = await window.TRCM.permissions.load();
      if (!allowed) return true;

      const permitted = await window.TRCM.permissions.enforcePage();
      if (permitted) {
        await window.TRCM.permissions.applyVisibility();
        window.trcmPermissions.apply(document);
        navigation.setActiveMenu();
      }

      return permitted;
    } catch (error) {
      console.error("TRCM permission guard:", error);
      if (window.TRCM.permissions) window.TRCM.permissions.showAccessDenied();
      return false;
    }
  }

  window.trcmComponentsReady = initializeComponents().catch(function (error) {
    console.error("TRCM components initialization:", error);
    return false;
  });
})();