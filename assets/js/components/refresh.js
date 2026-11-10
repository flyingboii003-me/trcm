(function () {
  "use strict";

  let pageRefreshCallback = null;
  let realtimeClient = null;
  let realtimeDebounce = null;
  let refreshFallback = null;

  window.trcmRunRefresh = async function (button, callback) {
    if (!button || button.disabled || typeof callback !== "function") return;

    const originalContent = button.innerHTML;
    const originalLabel = button.getAttribute("aria-label") || button.getAttribute("title") || "Perbarui data";
    button.disabled = true;
    button.setAttribute("aria-label", "Memuat...");
    button.title = "Memuat...";
    button.innerHTML = '<span class="spinner-border spinner-border-sm" aria-hidden="true"></span>';

    try {
      await callback();
    } catch (error) {
      console.error("TRCM refresh:", error);
    } finally {
      button.innerHTML = originalContent;
      button.disabled = false;
      button.setAttribute("aria-label", originalLabel);
      button.title = originalLabel;
    }
  };

  window.trcmRegisterRefresh = function (callback) {
    pageRefreshCallback = typeof callback === "function" ? callback : null;

    const headerButton = document.getElementById("header-refresh-button");
    if (headerButton && !headerButton.dataset.bound) {
      headerButton.dataset.bound = "true";
      headerButton.addEventListener("click", function () {
        window.trcmRunRefresh(headerButton, function () {
          return pageRefreshCallback();
        });
      });
    }

    setupPageRealtime();

    if (!refreshFallback) {
      refreshFallback = setInterval(function () {
        if (typeof pageRefreshCallback === "function" && document.visibilityState === "visible") {
          Promise.resolve(pageRefreshCallback()).catch(function (error) {
            console.error("TRCM fallback refresh:", error);
          });
        }
      }, 60000);
    }
  };

  function setupPageRealtime() {
    if (realtimeClient || !pageRefreshCallback) return;

    const session = getTrcmSession();
    if (!session || !session.access_token) return;

    function connect() {
      if (!window.supabase || !window.supabase.createClient) return;

      realtimeClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
      realtimeClient.realtime.setAuth(session.access_token);
      realtimeClient.channel("trcm-live-" + (window.location.pathname.split("/").pop() || "dashboard"))
        .on("postgres_changes", { event: "*", schema: "public", table: "visits" }, queueRealtimeRefresh)
        .on("postgres_changes", { event: "*", schema: "public", table: "visit_events" }, queueRealtimeRefresh)
        .on("postgres_changes", { event: "INSERT", schema: "public", table: "photos" }, queueRealtimeRefresh)
        .subscribe(function (status, error) {
          const headerButton = document.getElementById("header-refresh-button");
          if (headerButton) {
            headerButton.title = status === "SUBSCRIBED"
              ? "Perbarui data · Realtime aktif"
              : "Perbarui data · Realtime " + String(status || "tidak tersedia").toLowerCase();
            headerButton.setAttribute("aria-label", headerButton.title);
          }

          if (error) console.warn("TRCM Realtime:", error.message || error);
        });
    }

    if (window.supabase && window.supabase.createClient) {
      connect();
      return;
    }

    const script = document.createElement("script");
    script.src = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2";
    script.async = true;
    script.onload = connect;
    script.onerror = function () {
      console.warn("TRCM Realtime tidak tersedia; refresh manual tetap aktif.");
    };
    document.head.appendChild(script);
  }

  function queueRealtimeRefresh() {
    if (realtimeDebounce) clearTimeout(realtimeDebounce);
    if (refreshFallback) clearInterval(refreshFallback);

    realtimeDebounce = setTimeout(function () {
      if (typeof pageRefreshCallback === "function") {
        Promise.resolve(pageRefreshCallback()).catch(function (error) {
          console.error("TRCM Realtime refresh:", error);
        });
      }
    }, 350);
  }

  window.addEventListener("beforeunload", function () {
    if (realtimeClient) realtimeClient.removeAllChannels();
    if (realtimeDebounce) clearTimeout(realtimeDebounce);
  });
})();