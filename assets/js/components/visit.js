(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.visit = window.TRCM.visit || {};

  const allowedRpc = new Set([
    "confirm_visit_wh_in",
    "record_visit_wh_out",
    "start_loading_visit",
    "finish_loading_visit"
  ]);

  function handles(path) {
    return typeof path === "string" && (
      /^\/rest\/v1\/visits(?:\?|$)/.test(path) ||
      /^\/rest\/v1\/rpc\/(?:confirm_visit_wh_in|record_visit_wh_out|start_loading_visit|finish_loading_visit)(?:\?|$)/.test(path)
    );
  }

  function request(path, options, settings) {
    if (!handles(path)) {
      throw new Error("Visit Service hanya menerima endpoint visits dan RPC lifecycle visit.");
    }
    if (!window.TRCM.api || typeof window.TRCM.api.request !== "function") {
      throw new Error("Shared API Service belum siap.");
    }
    return window.TRCM.api.request(path, options, settings);
  }

  function list(query, settings) {
    const suffix = query ? (String(query).charAt(0) === "?" ? String(query) : "?" + query) : "";
    return request("/rest/v1/visits" + suffix, {}, settings);
  }

  function create(payload, settings) {
    return request("/rest/v1/visits", {
      method: "POST",
      headers: { "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(payload)
    }, settings);
  }

  function update(visitId, payload, settings) {
    return request("/rest/v1/visits?id=eq." + encodeURIComponent(visitId), {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(payload)
    }, settings);
  }

  function remove(visitId, settings) {
    return request("/rest/v1/visits?id=eq." + encodeURIComponent(visitId), {
      method: "DELETE",
      headers: { Prefer: "return=minimal" }
    }, settings);
  }

  function rpc(name, payload, settings) {
    if (!allowedRpc.has(name)) {
      throw new Error("RPC tidak termasuk lifecycle visit yang didukung Visit Service.");
    }
    return request("/rest/v1/rpc/" + name, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload || {})
    }, settings);
  }

  window.TRCM.visit.handles = handles;
  window.TRCM.visit.request = request;
  window.TRCM.visit.list = list;
  window.TRCM.visit.create = create;
  window.TRCM.visit.update = update;
  window.TRCM.visit.remove = remove;
  window.TRCM.visit.rpc = rpc;
})();
