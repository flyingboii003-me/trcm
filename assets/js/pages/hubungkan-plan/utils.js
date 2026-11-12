(function () {
  "use strict";
  function localDateInputValue(value) {
    const date = value ? new Date(value) : new Date();
    if (Number.isNaN(date.getTime())) return "";
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
  }
  function formatPlanDate(value) {
    if (!value) return "Tanggal tidak tersedia";
    const parts = value.split("-");
    return parts.length === 3 ? parts[2] + "/" + parts[1] + "/" + parts[0] : value;
  }
  function formatRegisteredDate(value) {
    if (!value) return "—";
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "—";
    return new Intl.DateTimeFormat("id-ID", { day: "2-digit", month: "long", year: "numeric", timeZone: "Asia/Jakarta" }).format(date);
  }
  function escapeHtml(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (character) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[character];
    });
  }
  function getPlanShipmentGroups(items) {
    const groups = new Map();
    items.forEach(function (item) {
      const doNumber = String(item.do_number || "").trim();
      const shipmentNumber = String(item.shipment_number || "").trim();
      const activityLabel = item.activity_type === "inbound" ? "Inbound" : "Outbound";
      const rawKey = doNumber ? "do:" + doNumber : shipmentNumber ? "shipment:" + shipmentNumber : "item:" + item.id;
      const key = String(item.plan_id + ":" + rawKey).trim().toLowerCase();
      const label = [activityLabel, doNumber ? "DO " + doNumber : "", shipmentNumber ? "Shipment " + shipmentNumber : ""].filter(Boolean).join(" · ") || ("Baris " + item.row_number);
      if (!groups.has(key)) groups.set(key, { key: key, label: label, items: [], trip: item.trip || null });
      const group = groups.get(key);
      group.items.push(item);
      if (!group.trip && item.trip) group.trip = item.trip;
    });
    return Array.from(groups.values());
  }
  function docLabel(link) {
    const parts = [];
    if (link.snapshot_do_number) parts.push("DO " + link.snapshot_do_number);
    if (link.snapshot_shipment_number) parts.push("Shipment " + link.snapshot_shipment_number);
    return parts.join(" · ") || "Dokumen Plan lama";
  }
  function getClient(visit) {
    const client = Array.isArray(visit.clients) ? visit.clients[0] : visit.clients;
    return client && client.name || "—";
  }
  function matches(visit, term) {
    if (!term) return true;
    const linked = Array.isArray(visit.visit_plan_items) ? visit.visit_plan_items : [];
    const values = [visit.plate_number, visit.container_num, visit.driver_name, visit.vendor, visit.destination_city, getClient(visit), visit.shipment_number].concat(linked.map(docLabel));
    return values.some(function (value) { return String(value || "").toLocaleLowerCase("id-ID").includes(term); });
  }
  window.TRCM = window.TRCM || {};
  window.TRCM.hubungkanPlan = window.TRCM.hubungkanPlan || {};
  window.TRCM.hubungkanPlan.utils = {
    localDateInputValue: localDateInputValue,
    formatPlanDate: formatPlanDate,
    formatRegisteredDate: formatRegisteredDate,
    escapeHtml: escapeHtml,
    getPlanShipmentGroups: getPlanShipmentGroups,
    docLabel: docLabel,
    getClient: getClient,
    matches: matches
  };
})();
