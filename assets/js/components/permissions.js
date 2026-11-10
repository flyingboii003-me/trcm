(function () {
  "use strict";

  const permissionState = window.TRCM.state.permissionState;

  function showPageAccessDenied() {
    const main = document.querySelector("main") || document.body;
    main.innerHTML = '<div class="container-fluid py-5"><div class="card border-0 shadow-sm"><div class="card-body text-center py-5"><div class="mb-3"><i class="bi bi-shield-lock fs-1 text-secondary"></i></div><h4 class="mb-2">Akses tidak tersedia</h4><p class="text-secondary mb-4">Anda tidak memiliki permission untuk membuka halaman ini.</p><a class="btn btn-primary" href="dashboard.html">Kembali ke Dashboard</a></div></div></div>';
  }

  async function loadMyMenuPermissions() {
    const session = getTrcmSession();
    const accessToken = session && session.access_token;
    if (!accessToken) return null;

    const response = await fetch(SUPABASE_URL + "/rest/v1/rpc/get_my_permissions", {
      method: "POST",
      headers: {
        apikey: SUPABASE_PUBLISHABLE_KEY,
        Authorization: "Bearer " + accessToken,
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
      .filter(function (row) {
        return String(row.permission_key || "") === "view";
      })
      .map(function (row) {
        return String(row.resource_key || "");
      }));
  }

  function can(resourceKey, permissionKey) {
    return permissionState.has(String(resourceKey || "") + ":" + String(permissionKey || ""));
  }

  function apply(root) {
    const scope = root || document;

    scope.querySelectorAll("[data-permission]").forEach(function (element) {
      const value = String(element.getAttribute("data-permission") || "");
      const separatorIndex = value.indexOf(":");
      if (separatorIndex < 1) return;

      const resourceKey = value.slice(0, separatorIndex);
      const permissionKey = value.slice(separatorIndex + 1);
      element.hidden = !can(resourceKey, permissionKey);
    });
  }

  function canView(resourceKey) {
    return permissionState.has(String(resourceKey || "") + ":view");
  }

  function loaded() {
    return permissionState.size > 0;
  }

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
          const listItem = item.closest(".sidebar-menu-item") || item;
          return !listItem.hidden;
        });
        const parentItem = group.closest(".sidebar-menu-item");
        if (parentItem) parentItem.hidden = !hasVisibleChild;
      });

      await window.TRCM.navigation.syncCollapsibleMenuState();
    } finally {
      if (sidebar) sidebar.style.visibility = "";
    }
  }

  async function enforcePagePermission() {
    const resourceKey = window.TRCM.pageContext.getCurrentPageResourceKey();
    if (!resourceKey) return true;
    if (permissionState.has(resourceKey + ":view")) return true;

    showPageAccessDenied();
    return false;
  }

  window.trcmPermissions = {
    can: can,
    apply: apply,
    canView: canView,
    loaded: loaded
  };

  window.TRCM = window.TRCM || {};
  window.TRCM.permissions = {
    load: loadMyMenuPermissions,
    applyVisibility: applyPermissionVisibility,
    enforcePage: enforcePagePermission
  };
})();