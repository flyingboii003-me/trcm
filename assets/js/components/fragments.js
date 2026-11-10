(function () {
  "use strict";

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

  window.TRCM = window.TRCM || {};
  window.TRCM.fragments = {
    load: loadFragment
  };
})();