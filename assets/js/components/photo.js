(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.photo = window.TRCM.photo || {};

  function handles(path) {
    return typeof path === "string" && /^\/rest\/v1\/photos(?:\?|$)/.test(path);
  }

  function getAuthHeaders(extra) {
    const session = typeof getTrcmSession === "function" ? getTrcmSession() : null;
    return Object.assign({
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: "Bearer " + (session && session.access_token ? session.access_token : "")
    }, extra || {});
  }

  function storagePath(operation, objectPath) {
    const encodedPath = String(objectPath || "").split("/").map(encodeURIComponent).join("/");
    const action = operation ? operation + "/" : "";
    return "/storage/v1/object/" + action + "trcm-visit-photos/" + encodedPath;
  }

  function request(path, options, settings) {
    if (!handles(path)) throw new Error("Photo Service hanya menerima endpoint metadata foto.");
    if (!window.TRCM.api || typeof window.TRCM.api.request !== "function") {
      throw new Error("Shared API Service belum siap.");
    }
    return window.TRCM.api.request(path, options, settings);
  }

  function upload(objectPath, file, contentType, extraHeaders) {
    return fetch(SUPABASE_URL + storagePath("", objectPath), {
      method: "POST",
      headers: getAuthHeaders(Object.assign({
        "Content-Type": contentType || (file && file.type) || "application/octet-stream",
        "x-upsert": "false"
      }, extraHeaders || {})),
      body: file
    });
  }

  function remove(objectPath) {
    return fetch(SUPABASE_URL + storagePath("", objectPath).replace("/object//", "/object/"), {
      method: "DELETE",
      headers: getAuthHeaders()
    });
  }

  function createRecord(payload, settings) {
    return request("/rest/v1/photos", {
      method: "POST",
      headers: { "Content-Type": "application/json", Prefer: "return=representation" },
      body: JSON.stringify(payload)
    }, settings);
  }

  function deleteRecord(photoId, settings) {
    return request("/rest/v1/photos?id=eq." + encodeURIComponent(photoId), {
      method: "DELETE",
      headers: { Prefer: "return=minimal" }
    }, settings);
  }

  async function createSignedUrl(fileLocation, expiresIn) {
    if (!fileLocation) return null;
    const objectPath = String(fileLocation)
      .replace(/^\/+/, "")
      .replace(/^trcm-visit-photos\//, "");
    if (!objectPath) return null;

    const response = await fetch(
      SUPABASE_URL + storagePath("sign", objectPath),
      {
        method: "POST",
        headers: getAuthHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({ expiresIn: Number(expiresIn) || 3600 })
      }
    );
    const responseText = await response.text();
    let data = null;
    try { data = responseText ? JSON.parse(responseText) : null; } catch {}

    if (!response.ok) {
      console.error("Gagal membuat signed URL foto:", response.status, data);
      return null;
    }

    const signedPath = data && (data.signedURL || data.signedUrl);
    if (!signedPath) return null;
    if (signedPath.startsWith("http://") || signedPath.startsWith("https://")) return signedPath;

    const normalizedSignedPath = signedPath.startsWith("/") ? signedPath : "/" + signedPath;
    return SUPABASE_URL + (
      normalizedSignedPath.startsWith("/storage/v1/")
        ? normalizedSignedPath
        : "/storage/v1" + normalizedSignedPath
    );
  }

  window.TRCM.photo.handles = handles;
  window.TRCM.photo.request = request;
  window.TRCM.photo.upload = upload;
  window.TRCM.photo.remove = remove;
  window.TRCM.photo.createRecord = createRecord;
  window.TRCM.photo.deleteRecord = deleteRecord;
  window.TRCM.photo.createSignedUrl = createSignedUrl;
})();
