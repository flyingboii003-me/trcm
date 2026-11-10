(function () {
  "use strict";

  window.TRCM = window.TRCM || {};
  window.TRCM.api = window.TRCM.api || {};

  function parseResponse(text) {
    if (!text) return null;
    try {
      return JSON.parse(text);
    } catch {
      return null;
    }
  }

  function getErrorMessage(data, fields, fallback) {
    if (data && typeof data === "object") {
      for (const field of fields) {
        if (data[field]) return data[field];
      }
    }
    return fallback;
  }

  async function request(path, options, settings) {
    const session = typeof getTrcmSession === "function" ? getTrcmSession() : null;
    const config = settings || {};
    const requestOptions = options || {};
    const headers = Object.assign({
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: "Bearer " + (session && session.access_token ? session.access_token : "")
    }, requestOptions.headers || {});

    const response = await fetch(SUPABASE_URL + path, Object.assign({}, requestOptions, {
      headers: headers
    }));
    const text = await response.text();
    const data = parseResponse(text);

    if (response.ok && config.requireJson && data === null) {
      throw new Error(config.invalidResponseMessage || "Respons data tidak valid.");
    }

    if (response.status === 401) {
      if (config.redirectOnUnauthorized !== false) {
        sessionStorage.removeItem("trcm_session");
        window.location.replace(config.loginUrl || "../index.html");
      }
      if (config.unauthorizedMessage) throw new Error(config.unauthorizedMessage);
      return null;
    }

    if (!response.ok) {
      if (typeof config.errorMessageBuilder === "function") {
        const customMessage = config.errorMessageBuilder(data, text, response.status);
        if (customMessage) throw new Error(customMessage);
      }
      const fields = Array.isArray(config.errorFields)
        ? config.errorFields
        : ["message", "details", "hint", "error_description", "error"];
      throw new Error(getErrorMessage(
        data,
        fields,
        config.errorMessage || "Permintaan ke database gagal."
      ));
    }

    return data;
  }

  window.TRCM.api.request = request;
})();
