(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.masterData = window.TRCM.masterData || {};

  const resources = new Set([
    "cards",
    "vendors",
    "clients",
    "gates",
    "truck_types",
    "line_numbers",
    "fleet_templates"
  ]);

  function handles(path) {
    if (typeof path !== "string") return false;
    const match = path.match(/^\/rest\/v1\/([a-z_]+)(?:\?|$)/);
    return Boolean(match && resources.has(match[1]));
  }

  function request(path, options, settings) {
    if (!handles(path)) {
      throw new Error("Master Data Service hanya menerima endpoint data master yang didukung.");
    }
    if (!window.TRCM.api || typeof window.TRCM.api.request !== "function") {
      throw new Error("Shared API Service belum siap.");
    }
    return window.TRCM.api.request(path, options, settings);
  }

  function list(resource, query, settings) {
    if (!resources.has(resource)) {
      throw new Error("Resource tidak termasuk Master Data Service.");
    }
    const suffix = query ? (String(query).charAt(0) === "?" ? String(query) : "?" + query) : "";
    return request("/rest/v1/" + resource + suffix, {}, settings);
  }

  function create(resource, payload, settings) {
    if (!resources.has(resource)) throw new Error("Resource tidak termasuk Master Data Service.");
    return request("/rest/v1/" + resource, {
      method: "POST",
      headers: { "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(payload)
    }, settings);
  }

  function update(resource, id, payload, settings) {
    if (!resources.has(resource)) throw new Error("Resource tidak termasuk Master Data Service.");
    return request("/rest/v1/" + resource + "?id=eq." + encodeURIComponent(id), {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(payload)
    }, settings);
  }

  function remove(resource, id, settings) {
    if (!resources.has(resource)) throw new Error("Resource tidak termasuk Master Data Service.");
    return request("/rest/v1/" + resource + "?id=eq." + encodeURIComponent(id), {
      method: "DELETE",
      headers: { Prefer: "return=minimal" }
    }, settings);
  }

  window.TRCM.masterData.handles = handles;
  window.TRCM.masterData.request = request;
  window.TRCM.masterData.list = list;
  window.TRCM.masterData.create = create;
  window.TRCM.masterData.update = update;
  window.TRCM.masterData.remove = remove;
})();
