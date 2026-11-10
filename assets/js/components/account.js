(function () {
  "use strict";

  function setAccountNames() {
    const session = getTrcmSession();
    const accountName = document.getElementById("account-name");
    const accountMenuName = document.getElementById("account-menu-name");
    const sidebarAccountName = document.getElementById("sidebar-account-name");

    function applyDisplayName(name) {
      const displayName = (typeof name === "string" && name.trim()) || "Akun";
      if (accountName) accountName.textContent = displayName;
      if (accountMenuName) accountMenuName.textContent = "Halo, " + displayName;
      if (sidebarAccountName) sidebarAccountName.textContent = displayName;
    }

    const user = session && session.user;
    applyDisplayName(user && user.full_name);

    if (!session || !session.access_token) return;

    fetch(SUPABASE_URL + "/rest/v1/rpc/get_my_profile", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_PUBLISHABLE_KEY,
        Authorization: "Bearer " + session.access_token
      },
      body: "{}"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("Gagal memuat profil pengguna");
        return response.json();
      })
      .then(function (profiles) {
        const profile = Array.isArray(profiles) ? profiles[0] : profiles;
        if (profile && profile.full_name) applyDisplayName(profile.full_name);
      })
      .catch(function (error) {
        console.warn("Nama lengkap pengguna tidak dapat dimuat:", error);
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

  function setupProfileButton() {
    const profileButton = document.getElementById("profile-open");
    if (!profileButton) return;

    profileButton.addEventListener("click", function () {
      window.location.href = "profil.html";
    });
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.account = {
    setNames: setAccountNames,
    setupLogout: setupLogout,
    setupProfileButton: setupProfileButton
  };
})();