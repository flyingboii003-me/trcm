(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.visit = window.TRCM.visit || {};

  const contract = window.TRCM.contracts && window.TRCM.contracts.services.visit;
  if (!contract) throw new Error("TRCM service contract belum dimuat.");
  const resources = new Set(contract.resources);
  const allowedRpc = new Set(contract.rpc);

  function handles(path) {
    if (typeof path !== "string") return false;
    const resourceMatch = path.match(/^\/rest\/v1\/([a-z_]+)(?:\?|$)/);
    const rpcMatch = path.match(/^\/rest\/v1\/rpc\/([a-z_]+)(?:\?|$)/);
    return Boolean(
      (resourceMatch && resources.has(resourceMatch[1])) ||
      (rpcMatch && allowedRpc.has(rpcMatch[1]))
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
