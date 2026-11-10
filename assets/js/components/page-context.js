(function () {
  "use strict";

  const contracts = window.TRCM && window.TRCM.contracts;
  if (!contracts || !contracts.pages) {
    throw new Error("TRCM page contract belum dimuat.");
  }

  const pagesByFile = Object.keys(contracts.pages).reduce(function (map, key) {
    const page = contracts.pages[key];
    map[page.file] = Object.assign({ key: key }, page);
    return map;
  }, {});

  function getCurrentPage() {
    const file = window.location.pathname.split("/").pop().toLowerCase();
    return pagesByFile[file] || (file === "" ? pagesByFile["dashboard.html"] : null);
  }

  function getCurrentPageKey() {
    const page = getCurrentPage();
    return page ? page.key : "";
  }

  function getCurrentPageResourceKey() {
    const explicitResource = document.body && document.body.getAttribute("data-page-resource");
    if (explicitResource) return explicitResource;
    const page = getCurrentPage();
    return page ? page.resourceKey : "";
  }

  function getCurrentPageTitle() {
    const page = getCurrentPage();
    return page ? page.title : "TRCM";
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.pageContext = {
    getCurrentPage: getCurrentPage,
    getCurrentPageKey: getCurrentPageKey,
    getCurrentPageResourceKey: getCurrentPageResourceKey,
    getCurrentPageTitle: getCurrentPageTitle
  };
})();
