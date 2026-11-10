(function () {
  "use strict";

  const statusConfig = {
    wh_in: { label: "Terdaftar", className: "status-wh-in" },
    queue: { label: "Parkir", className: "status-queue" },
    parked: { label: "Parkir", className: "status-queue" },
    start_loading: { label: "Proses Loading", className: "status-start-loading" },
    done_loading: { label: "Selesai Loading", className: "status-done-loading" },
    wh_out: { label: "WH Out", className: "status-wh-out" },
    registered: { label: "Terdaftar", className: "status-wh-in" },
    started: { label: "Proses", className: "status-start-loading" },
    processing: { label: "Proses", className: "status-start-loading" },
    completed: { label: "Selesai Loading", className: "status-done-loading" }
  };

  window.trcmStatusConfig = statusConfig;
  window.trcmStatusLabels = Object.keys(statusConfig).reduce(function (labels, key) {
    labels[key] = statusConfig[key].label;
    return labels;
  }, {});

  window.trcmVisitStatus = function (visit) {
    if (visit && visit.wh_out_at) return "wh_out";
    return visit && visit.process_status ? visit.process_status : "";
  };

  window.trcmStatusClass = function (status) {
    const safeStatus = String(status || "");
    return statusConfig[safeStatus] ? statusConfig[safeStatus].className : "status-unknown";
  };

  window.trcmStatusBadge = function (status) {
    const safeStatus = String(status || "");
    const config = statusConfig[safeStatus];
    const label = config ? config.label : safeStatus || "—";
    const className = config ? config.className : "status-unknown";
    return '<span class="status-badge ' + className + '">' +
      '<span class="status-dot"></span>' + escapeHtml(label) + '</span>';
  };
})();