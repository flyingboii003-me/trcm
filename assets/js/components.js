(function () {
  const container = document.getElementById("sidebar-container");

  if (!container) {
    window.trcmSidebarReady = Promise.reject(new Error("Sidebar container tidak ditemukan."));
    return;
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
      container.outerHTML = html;

      const currentPage = window.location.pathname.split("/").pop() || "dashboard.html";
      const menuLinks = document.querySelectorAll(".sidebar-menu-link");

      menuLinks.forEach(function (link) {
        const href = link.getAttribute("href");

        if (href === currentPage) {
          link.classList.add("active");
          link.setAttribute("aria-current", "page");
        }
      });

      return true;
    })
    .catch(function (error) {
      console.error("TRCM components:", error);
      throw error;
    });
})();