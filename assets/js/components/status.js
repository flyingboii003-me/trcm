(function () {
  "use strict";

  const contracts = window.TRCM && window.TRCM.contracts;
  if (!contracts || !contracts.statuses) {
    throw new Error("TRCM status contract belum dimuat.");
  }
  const statusConfig = contracts.statuses;

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
