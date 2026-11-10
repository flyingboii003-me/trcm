(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.plan = window.TRCM.plan || {};

  const resources = new Set([
    "import_plans",
    "import_plan_items",
    "import_plan_trips",
    "visit_plan_items"
  ]);
  const rpcNames = new Set(["save_import_plan", "update_import_plan"]);

  function handles(path) {
    if (typeof path !== "string") return false;
    const resourceMatch = path.match(/^\/rest\/v1\/([a-z_]+)(?:\?|$)/);
    const rpcMatch = path.match(/^\/rest\/v1\/rpc\/([a-z_]+)(?:\?|$)/);
    return Boolean(
      (resourceMatch && resources.has(resourceMatch[1])) ||
      (rpcMatch && rpcNames.has(rpcMatch[1]))
    );
  }

  function request(path, options, settings) {
    if (!handles(path)) throw new Error("Plan Service hanya menerima endpoint Plan yang didukung.");
    if (!window.TRCM.api || typeof window.TRCM.api.request !== "function") {
      throw new Error("Shared API Service belum siap.");
    }
    return window.TRCM.api.request(path, options, settings);
  }

  function list(resource, query, settings) {
    if (!resources.has(resource)) throw new Error("Resource tidak termasuk Plan Service.");
    const suffix = query ? (String(query).charAt(0) === "?" ? String(query) : "?" + query) : "";
    return request("/rest/v1/" + resource + suffix, {}, settings);
  }

  function rpc(name, payload, settings) {
    if (!rpcNames.has(name)) throw new Error("RPC tidak termasuk Plan Service.");
    return request("/rest/v1/rpc/" + name, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload || {})
    }, settings);
  }

  window.TRCM.plan.handles = handles;
  window.TRCM.plan.request = request;
  window.TRCM.plan.list = list;
  window.TRCM.plan.rpc = rpc;
})();
