(function () {
  "use strict";

  function escapeHtml(value) {
    if (typeof window.escapeHtml === "function") return window.escapeHtml(value);
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (character) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[character];
    });
  }

  function localDateInputValue(value) {
    const date = value ? new Date(value) : new Date();
    if (Number.isNaN(date.getTime())) return "";
    return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, "0"), String(date.getDate()).padStart(2, "0")].join("-");
  }

  function formatActivity(value) {
    if (value === "inbound") return "Inbound";
    if (value === "outbound") return "Outbound";
    return value || "—";
  }

  function formatPlanDate(value) {
    if (!value) return "Tanggal tidak tersedia";
    const parts = value.split("-");
    return parts.length === 3 ? parts[2] + "/" + parts[1] + "/" + parts[0] : value;
  }

  function showMessage(icon, title, text) {
    return Swal.fire({
      icon: icon,
      title: title,
      text: text,
      confirmButtonText: "Tutup",
      confirmButtonColor: "#006ECD"
    });
  }

  window.trcmComponentsReady.then(async function () {
    "use strict";

    const session = getTrcmSession();
    if (!session || !session.access_token || !session.user) {
      window.location.replace("../index.html");
      return;
    }

    const permission = {
      startView: window.trcmPermissions.can("start_loading", "view"),
      startUpdate: window.trcmPermissions.can("start_loading", "update"),
      finishView: window.trcmPermissions.can("finish_loading", "view"),
      finishUpdate: window.trcmPermissions.can("finish_loading", "update"),
      finishUpload: window.trcmPermissions.can("finish_loading", "upload")
    };

    const elements = {
      startMode: document.getElementById("mode-start-button"),
      finishMode: document.getElementById("mode-finish-button"),
      description: document.getElementById("mode-description"),
      table: document.getElementById("bulk-visit-table"),
      visitCount: document.getElementById("visit-count"),
      selectionCount: document.getElementById("selection-count"),
      search: document.getElementById("search-card"),
      client: document.getElementById("client-filter"),
      selectAll: document.getElementById("select-all-visits"),
      empty: document.getElementById("bulk-empty-selection"),
      startFields: document.getElementById("bulk-start-fields"),
      finishFields: document.getElementById("bulk-finish-fields"),
      startDetails: document.getElementById("start-visit-details"),
      finishDetails: document.getElementById("finish-visit-details"),
      gate: document.getElementById("shared-gate"),
      line: document.getElementById("shared-line"),
      startNotes: document.getElementById("shared-start-notes"),
      finishNotes: document.getElementById("shared-finish-notes"),
      startNotesCount: document.getElementById("start-notes-count"),
      detailCount: document.getElementById("selected-detail-count"),
      actionCount: document.getElementById("action-selection-count"),
      saveStart: document.getElementById("save-bulk-start"),
      saveFinish: document.getElementById("save-bulk-finish"),
      refresh: document.getElementById("page-refresh-button"),
      resultsCard: document.getElementById("bulk-results-card"),
      resultSummary: document.getElementById("bulk-result-summary"),
      resultList: document.getElementById("bulk-result-list"),
      retryActions: document.getElementById("retry-actions"),
      retryButton: document.getElementById("retry-failed-button"),
      clearResults: document.getElementById("clear-results-button")
    };

    let mode = permission.startView ? "start" : "finish";
    let visits = [];
    let gates = [];
    let lines = [];
    let selectedIds = new Set();
    let startStates = new Map();
    let finishPhotos = new Map();
    let photoPreviewUrls = new Map();
    let results = [];
    let processing = false;

    const request = function (path, options, settings) {
      const config = Object.assign({
        errorFields: ["message", "details", "hint"],
        errorMessage: "Permintaan ke database gagal."
      }, settings || {});
      if (window.TRCM.visit.handles(path)) return window.TRCM.visit.request(path, options, config);
      if (window.TRCM.masterData.handles(path)) return window.TRCM.masterData.request(path, options, config);
      if (window.TRCM.plan.handles(path)) return window.TRCM.plan.request(path, options, config);
      if (window.TRCM.photo.handles(path)) return window.TRCM.photo.request(path, options, config);
      return window.TRCM.api.request(path, options, config);
    };

    function createStartState(visit) {
      const operationalDate = localDateInputValue(visit.wh_in_at || visit.registered_at);
      return {
        sealNumber: visit.seal_number || "",
        dateFrom: operationalDate,
        dateTo: operationalDate,
        allActivities: !visit.activity_type,
        plans: [],
        selectedPlanIds: new Set(),
        availableItems: [],
        processedIds: new Set(),
        selectedItemIds: new Set(),
        loadingPlans: false,
        plansLoaded: false,
        loadingItems: false,
        error: "",
        itemError: ""
      };
    }

    function getStartState(visit) {
      if (!startStates.has(visit.id)) startStates.set(visit.id, createStartState(visit));
      return startStates.get(visit.id);
    }

    function getSelectedVisits() {
      return visits.filter(function (visit) { return selectedIds.has(visit.id); });
    }

    function visibleVisits() {
      const needle = elements.search.value.trim().toLocaleLowerCase("id-ID");
      const clientName = elements.client.value;
      return visits.filter(function (visit) {
        const card = visit.cards && visit.cards.card_number ? visit.cards.card_number : "";
        const plate = visit.plate_number || "";
        const client = visit.clients && visit.clients.name ? visit.clients.name : "";
        return (!needle || card.toLocaleLowerCase("id-ID").includes(needle) || plate.toLocaleLowerCase("id-ID").includes(needle)) &&
          (clientName === "all" || client === clientName);
      });
    }

    function renderTable() {
      const rows = visibleVisits();
      elements.visitCount.textContent = rows.length + " armada tersedia";
      elements.selectionCount.textContent = selectedIds.size + " dipilih";
      elements.actionCount.textContent = String(selectedIds.size);
      elements.detailCount.textContent = selectedIds.size ? selectedIds.size + " armada dipilih" : "Belum ada armada dipilih";

      if (!rows.length) {
        const message = mode === "start"
          ? "Belum ada armada yang sudah dikonfirmasi WH In."
          : "Tidak ada armada yang menunggu Selesai Loading.";
        elements.table.innerHTML = '<tr><td colspan="8" class="table-state">' + message + '</td></tr>';
      } else {
        elements.table.innerHTML = rows.map(function (visit) {
          const card = visit.cards && visit.cards.card_number ? visit.cards.card_number : "—";
          const client = visit.clients && visit.clients.name ? visit.clients.name : "—";
          const activity = formatActivity(visit.activity_type);
          return '<tr>' +
            '<td><input class="form-check-input bulk-visit-checkbox" type="checkbox" data-visit-id="' + escapeHtml(visit.id) + '" aria-label="Pilih armada ' + escapeHtml(card) + '"' + (selectedIds.has(visit.id) ? " checked" : "") + (processing ? " disabled" : "") + '></td>' +
            '<td><span class="table-card-number">' + escapeHtml(card) + '</span></td>' +
            '<td class="font-monospace fw-semibold">' + escapeHtml(visit.plate_number || "—") + '</td>' +
            '<td>' + escapeHtml(activity) + '</td>' +
            '<td>' + escapeHtml(visit.destination_city || "—") + '</td>' +
            '<td>' + escapeHtml(visit.vendor || "—") + '</td>' +
            '<td>' + escapeHtml(client) + '</td>' +
            '<td>' + window.trcmStatusBadge(window.trcmVisitStatus(visit)) + '</td>' +
            '</tr>';
        }).join("");
      }

      const visibleIds = rows.map(function (visit) { return visit.id; });
      const selectedVisible = visibleIds.filter(function (id) { return selectedIds.has(id); }).length;
      elements.selectAll.checked = visibleIds.length > 0 && selectedVisible === visibleIds.length;
      elements.selectAll.indeterminate = selectedVisible > 0 && selectedVisible < visibleIds.length;
      elements.selectAll.disabled = processing || visibleIds.length === 0;
      elements.saveStart.disabled = processing || !permission.startUpdate || selectedIds.size === 0;
      elements.saveFinish.disabled = processing || !permission.finishUpdate || !permission.finishUpload || selectedIds.size === 0;
    }

    function populateClients() {
      const selected = elements.client.value;
      const names = Array.from(new Set(visits.map(function (visit) {
        return visit.clients && visit.clients.name ? visit.clients.name : "";
      }).filter(Boolean))).sort(function (a, b) { return a.localeCompare(b, "id"); });
      elements.client.innerHTML = '<option value="all">Semua Klien</option>' + names.map(function (name) {
        return '<option value="' + escapeHtml(name) + '">' + escapeHtml(name) + '</option>';
      }).join("");
      elements.client.value = names.includes(selected) ? selected : "all";
    }

    async function loadReferenceData() {
      const values = await Promise.all([
        request("/rest/v1/gates?select=id,gate_number&order=gate_number.asc"),
        request("/rest/v1/line_numbers?select=id,gate_id,line_number&order=line_number.asc")
      ]);
      gates = Array.isArray(values[0]) ? values[0] : [];
      lines = Array.isArray(values[1]) ? values[1] : [];
      elements.gate.innerHTML = '<option value="">Pilih gerbang</option>' + gates.map(function (gate) {
        return '<option value="' + escapeHtml(gate.id) + '">Gate ' + escapeHtml(gate.gate_number) + '</option>';
      }).join("");
    }

    function populateLines(gateId) {
      const matching = lines.filter(function (line) { return line.gate_id === gateId; });
      elements.line.disabled = !gateId;
      elements.line.innerHTML = gateId
        ? '<option value="">Pilih line</option>' + matching.map(function (line) {
            return '<option value="' + escapeHtml(line.id) + '">Line ' + escapeHtml(line.line_number) + '</option>';
          }).join("")
        : '<option value="">Pilih gerbang terlebih dahulu</option>';
    }

    async function loadVisits() {
      if (!session || !session.access_token) return;
      elements.table.innerHTML = '<tr><td colspan="8" class="table-state">Memuat data armada...</td></tr>';
      try {
        const select = [
          "id", "card_id", "client_id", "plate_number", "driver_name", "activity_type", "vendor",
          "shipment_number", "destination_city", "process_status", "wh_in_at", "registered_at",
          "started_at", "completed_at", "wh_out_at", "seal_number", "notes",
          "clients(name)", "cards(card_number)"
        ].join(",");
        const query = mode === "start"
          ? "?select=" + encodeURIComponent(select) + "&process_status=in.(wh_in,queue)&wh_in_at=not.is.null&wh_out_at=is.null&order=wh_in_at.asc"
          : "?select=" + encodeURIComponent(select) + "&process_status=eq.started&wh_out_at=is.null&order=started_at.asc";
        const data = await window.TRCM.visit.list(query);
        if (!Array.isArray(data)) throw new Error("Respons data armada tidak valid.");
        visits = data;
        const currentIds = new Set(visits.map(function (visit) { return visit.id; }));
        selectedIds = new Set(Array.from(selectedIds).filter(function (id) { return currentIds.has(id); }));
        populateClients();
        renderTable();
        renderSelectedDetails();
      } catch (error) {
        console.error("TRCM Bulk Checker load:", error);
        elements.table.innerHTML = '<tr><td colspan="8" class="table-state error-state">Data armada gagal dimuat. Silakan perbarui.</td></tr>';
        throw error;
      }
    }

    function revokePreviewUrls(visitId) {
      const urls = photoPreviewUrls.get(visitId) || [];
      urls.forEach(function (url) { URL.revokeObjectURL(url); });
      photoPreviewUrls.delete(visitId);
    }

    function renderPhotoPreviews(visitId, container) {
      revokePreviewUrls(visitId);
      const files = finishPhotos.get(visitId) || [];
      const urls = [];
      container.innerHTML = files.map(function (file, index) {
        const url = URL.createObjectURL(file);
        urls.push(url);
        return '<div class="bulk-photo-item"><img src="' + escapeHtml(url) + '" alt="Pratinjau foto ' + (index + 1) + '"><button type="button" class="btn btn-light border" data-remove-photo="' + index + '" data-visit-id="' + escapeHtml(visitId) + '" aria-label="Hapus foto ' + (index + 1) + '"><i class="bi bi-x"></i></button></div>';
      }).join("");
      photoPreviewUrls.set(visitId, urls);
    }

    function getPlanGroups(items) {
      const groups = new Map();
      items.forEach(function (item) {
        const doNumber = String(item.do_number || "").trim();
        const shipmentNumber = String(item.shipment_number || "").trim();
        const rawKey = doNumber ? "do:" + doNumber : shipmentNumber ? "shipment:" + shipmentNumber : "item:" + item.id;
        const key = String(item.plan_id + ":" + rawKey).toLocaleLowerCase("id-ID");
        const label = [
          formatActivity(item.activity_type),
          doNumber ? "DO " + doNumber : "",
          shipmentNumber ? "Shipment " + shipmentNumber : ""
        ].filter(Boolean).join(" · ") || ("Baris " + item.row_number);
        if (!groups.has(key)) groups.set(key, { key:key, label:label, items:[], trip:item.trip || null, planId:item.plan_id });
        const group = groups.get(key);
        group.items.push(item);
        if (!group.trip && item.trip) group.trip = item.trip;
      });
      return Array.from(groups.values());
    }

    function renderPlanControls(visit, state) {
      const card = elements.startDetails.querySelector('[data-visit-card="' + CSS.escape(visit.id) + '"]');
      if (!card) return;
      const planContainer = card.querySelector("[data-plan-options]");
      const itemContainer = card.querySelector("[data-plan-items]");
      const planMeta = card.querySelector("[data-plan-meta]");
      if (!planContainer || !itemContainer) return;

      if (state.loadingPlans) {
        planContainer.innerHTML = '<div class="small text-muted">Memuat Plan aktif...</div>';
      } else if (state.error) {
        planContainer.innerHTML = '<div class="small text-danger">' + escapeHtml(state.error) + '</div>';
      } else if (!state.plans.length) {
        planContainer.innerHTML = '<div class="small text-muted">Tidak ada Plan aktif yang cocok dengan klien, aktivitas, dan rentang tanggal.</div>';
      } else {
        planContainer.innerHTML = state.plans.map(function (plan) {
          const tripCount = Array.isArray(plan.import_plan_trips) && plan.import_plan_trips[0]
            ? Number(plan.import_plan_trips[0].count || 0)
            : 0;
          return '<label class="bulk-option"><input class="form-check-input" type="checkbox" data-plan-id="' + escapeHtml(plan.id) + '"' +
            (state.selectedPlanIds.has(plan.id) ? " checked" : "") + (state.loadingItems ? " disabled" : "") + '>' +
            '<span class="bulk-option-label">' + escapeHtml(formatActivity(plan.activity_type)) + ' · Plan ' + escapeHtml(formatPlanDate(plan.operational_date)) +
            '<span class="bulk-option-meta">' + tripCount + ' trip</span></span></label>';
        }).join("");
      }

      const groups = getPlanGroups(state.availableItems);
      const selectableGroups = groups.filter(function (group) {
        return !group.items.some(function (item) { return state.processedIds.has(item.id); });
      });
      if (state.loadingItems) {
        itemContainer.innerHTML = '<div class="small text-muted">Memuat DO/Shipment...</div>';
      } else if (state.itemError) {
        itemContainer.innerHTML = '<div class="small text-danger">' + escapeHtml(state.itemError) + '</div>';
      } else if (state.selectedPlanIds.size === 0) {
        itemContainer.innerHTML = '<div class="small text-muted">Pilih Plan untuk melihat DO/Shipment yang tersedia.</div>';
      } else if (!groups.length) {
        itemContainer.innerHTML = '<div class="small text-muted">Plan terpilih belum memiliki detail DO/Shipment.</div>';
      } else {
        itemContainer.innerHTML = groups.map(function (group, index) {
          const processed = group.items.some(function (item) { return state.processedIds.has(item.id); });
          const checked = !processed && group.items.every(function (item) { return state.selectedItemIds.has(item.id); });
          const trip = group.trip || {};
          const tripMeta = [trip.trip_number ? "Trip " + trip.trip_number : "", trip.plate_number || "", trip.vendor || "", trip.destination || ""].filter(Boolean).join(" · ");
          return '<label class="bulk-option' + (processed ? " is-disabled" : "") + '">' +
            (processed
              ? '<i class="bi bi-check-circle-fill text-muted mt-1"></i>'
              : '<input class="form-check-input" type="checkbox" data-plan-group="' + index + '"' + (checked ? " checked" : "") + '>') +
            '<span class="bulk-option-label">' + escapeHtml(group.label) +
            (processed ? '<span class="bulk-option-meta">Sudah diproses atau ditautkan ke visit lain</span>' : (tripMeta ? '<span class="bulk-option-meta">' + escapeHtml(tripMeta) + '</span>' : "")) +
            '</span></label>';
        }).join("");
      }

      const selectedCount = state.selectedItemIds.size;
      planMeta.textContent = selectedCount + " item DO/Shipment dipilih" +
        (selectableGroups.length ? " · " + selectableGroups.length + " kelompok tersedia" : "");
      planContainer.querySelectorAll("[data-plan-id]").forEach(function (checkbox) {
        checkbox.addEventListener("change", async function () {
          if (checkbox.checked) state.selectedPlanIds.add(checkbox.dataset.planId);
          else state.selectedPlanIds.delete(checkbox.dataset.planId);
          state.selectedItemIds = new Set(Array.from(state.selectedItemIds).filter(function (id) {
            return state.availableItems.some(function (item) { return item.id === id && state.selectedPlanIds.has(item.plan_id); });
          }));
          await loadPlanItemsForVisit(visit, state);
        });
      });
      itemContainer.querySelectorAll("[data-plan-group]").forEach(function (checkbox) {
        checkbox.addEventListener("change", function () {
          const group = groups[Number(checkbox.dataset.planGroup)];
          if (!group) return;
          group.items.forEach(function (item) {
            if (state.processedIds.has(item.id)) return;
            if (checkbox.checked) state.selectedItemIds.add(item.id);
            else state.selectedItemIds.delete(item.id);
          });
          renderPlanControls(visit, state);
        });
      });
    }

    async function loadPlansForVisit(visit, state, force) {
      if (state.plansLoaded && !force) return;
      if (!state.dateFrom || !state.dateTo) {
        state.error = "Lengkapi rentang tanggal Plan.";
        state.plansLoaded = true;
        renderPlanControls(visit, state);
        return;
      }
      if (state.dateFrom > state.dateTo) {
        state.error = "Tanggal awal harus sama dengan atau sebelum tanggal akhir.";
        state.plans = [];
        state.selectedPlanIds.clear();
        state.availableItems = [];
        state.selectedItemIds.clear();
        state.plansLoaded = true;
        renderPlanControls(visit, state);
        return;
      }

      state.loadingPlans = true;
      state.plansLoaded = false;
      state.error = "";
      state.itemError = "";
      state.plans = [];
      state.selectedPlanIds.clear();
      state.availableItems = [];
      state.processedIds.clear();
      state.selectedItemIds.clear();
      renderPlanControls(visit, state);

      try {
        const activityFilter = state.allActivities ? "" : "&activity_type=eq." + encodeURIComponent(String(visit.activity_type || "").toLowerCase());
        const filters = "client_id=eq." + encodeURIComponent(visit.client_id) + activityFilter +
          "&operational_date=gte." + encodeURIComponent(state.dateFrom) +
          "&operational_date=lte." + encodeURIComponent(state.dateTo) +
          "&status=eq.active&order=operational_date.asc,created_at.desc";
        const plans = await window.TRCM.plan.list(
          "import_plans",
          "?select=id,client_id,operational_date,activity_type,status,row_count,import_plan_trips(count)&" + filters
        );
        if (!Array.isArray(plans)) throw new Error("Respons Plan tidak valid.");
        state.plans = plans;
      } catch (error) {
        state.error = error.message || "Plan gagal dimuat.";
      } finally {
        state.loadingPlans = false;
        state.plansLoaded = true;
        renderPlanControls(visit, state);
      }
    }

    async function loadPlanItemsForVisit(visit, state) {
      const selectedPlans = state.plans.filter(function (plan) { return state.selectedPlanIds.has(plan.id); });
      const previousSelectedIds = new Set(state.selectedItemIds);
      state.loadingItems = true;
      state.itemError = "";
      state.availableItems = [];
      state.processedIds.clear();
      renderPlanControls(visit, state);
      if (!selectedPlans.length) {
        state.loadingItems = false;
        state.availableItems = [];
        state.processedIds.clear();
        state.selectedItemIds.clear();
        renderPlanControls(visit, state);
        return;
      }

      try {
        const results = await Promise.all(selectedPlans.map(async function (plan) {
          const planId = encodeURIComponent(plan.id);
          const values = await Promise.all([
            window.TRCM.plan.list("import_plan_items", "?select=id,plan_id,trip_id,row_number,do_number,shipment_number,manual_processed&plan_id=eq." + planId + "&order=row_number.asc"),
            window.TRCM.plan.list("import_plan_trips", "?select=id,plan_id,trip_number,vendor,plate_number,destination&plan_id=eq." + planId + "&order=trip_number.asc"),
            window.TRCM.plan.list("visit_plan_items", "?select=plan_item_id,import_plan_items!inner(plan_id)&import_plan_items.plan_id=eq." + planId)
          ]);
          if (!Array.isArray(values[0]) || !Array.isArray(values[1]) || !Array.isArray(values[2])) {
            throw new Error("Rincian DO/Shipment Plan tidak valid.");
          }
          const tripById = new Map(values[1].map(function (trip) { return [trip.id, trip]; }));
          const linkedIds = new Set(values[2].map(function (link) { return link.plan_item_id; }).filter(Boolean));
          return {
            items: values[0].map(function (item) {
              return Object.assign({}, item, {
                trip: tripById.get(item.trip_id) || null,
                activity_type: plan.activity_type,
                plan_date: plan.operational_date
              });
            }),
            linkedIds: linkedIds
          };
        }));
        const items = results.flatMap(function (result) { return result.items; });
        const loadedIds = new Set(items.map(function (item) { return item.id; }));
        state.availableItems = items;
        state.processedIds = new Set(results.flatMap(function (result) { return Array.from(result.linkedIds); }).filter(function (id) { return loadedIds.has(id); }));
        items.forEach(function (item) { if (item.manual_processed === true) state.processedIds.add(item.id); });
        state.selectedItemIds = new Set(Array.from(previousSelectedIds).filter(function (id) {
          return loadedIds.has(id) && !state.processedIds.has(id);
        }));
      } catch (error) {
        state.itemError = error.message || "Rincian DO/Shipment gagal dimuat.";
      } finally {
        state.loadingItems = false;
        renderPlanControls(visit, state);
      }
    }

    function renderSelectedDetails() {
      const selected = getSelectedVisits();
      elements.empty.hidden = selected.length > 0;
      elements.startFields.hidden = mode !== "start" || selected.length === 0;
      elements.finishFields.hidden = mode !== "finish" || selected.length === 0;

      elements.startDetails.innerHTML = "";
      elements.finishDetails.innerHTML = "";

      if (!selected.length) return;

      if (mode === "start") {
        selected.forEach(function (visit) {
          const state = getStartState(visit);
          const card = document.createElement("section");
          card.className = "bulk-visit-card";
          card.setAttribute("data-visit-card", visit.id);
          const cardNumber = visit.cards && visit.cards.card_number ? visit.cards.card_number : "—";
          card.innerHTML =
            '<div class="bulk-visit-heading mb-3"><div><div class="fw-bold">' + escapeHtml(cardNumber) + ' · ' + escapeHtml(visit.plate_number || "—") + '</div><div class="bulk-visit-meta"><span>' + escapeHtml(visit.clients && visit.clients.name || "—") + '</span><span>' + escapeHtml(formatActivity(visit.activity_type)) + '</span><span>' + escapeHtml(visit.destination_city || "—") + '</span></div></div><span class="badge rounded-pill text-bg-light border">Data individual</span></div>' +
            '<div class="row g-3 mb-3"><div class="col-12 col-md-4"><label class="form-label" for="seal-' + escapeHtml(visit.id) + '">Nomor segel</label><input class="form-control" id="seal-' + escapeHtml(visit.id) + '" data-seal-number value="' + escapeHtml(state.sealNumber) + '" maxlength="100" placeholder="Nomor segel armada"></div>' +
            '<div class="col-6 col-md-4"><label class="form-label" for="date-from-' + escapeHtml(visit.id) + '">Plan dari tanggal</label><input class="form-control" type="date" id="date-from-' + escapeHtml(visit.id) + '" data-plan-date-from value="' + escapeHtml(state.dateFrom) + '"></div>' +
            '<div class="col-6 col-md-4"><label class="form-label" for="date-to-' + escapeHtml(visit.id) + '">Plan sampai tanggal</label><input class="form-control" type="date" id="date-to-' + escapeHtml(visit.id) + '" data-plan-date-to value="' + escapeHtml(state.dateTo) + '"></div></div>' +
            '<div class="form-check mb-3"><input class="form-check-input" type="checkbox" id="all-activities-' + escapeHtml(visit.id) + '" data-all-activities' + (state.allActivities ? " checked" : "") + '><label class="form-check-label" for="all-activities-' + escapeHtml(visit.id) + '">Tampilkan Plan Inbound dan Outbound</label></div>' +
            '<div class="mb-3"><div class="form-label">Plan aktif</div><div class="bulk-plan-list" data-plan-options><div class="small text-muted">Pilih rentang tanggal untuk melihat Plan.</div></div></div>' +
            '<div><div class="form-label">DO / Shipment</div><div class="bulk-item-list" data-plan-items><div class="small text-muted">Pilih Plan untuk melihat DO/Shipment.</div></div><div class="form-text mt-2" data-plan-meta>0 item DO/Shipment dipilih</div></div>';
          elements.startDetails.appendChild(card);
          renderPlanControls(visit, state);
          if (!state.plansLoaded && !state.loadingPlans) loadPlansForVisit(visit, state);
        });
      } else {
        selected.forEach(function (visit) {
          if (!finishPhotos.has(visit.id)) finishPhotos.set(visit.id, []);
          const card = document.createElement("section");
          card.className = "bulk-visit-card";
          card.setAttribute("data-finish-card", visit.id);
          const cardNumber = visit.cards && visit.cards.card_number ? visit.cards.card_number : "—";
          card.innerHTML =
            '<div class="bulk-visit-heading mb-3"><div><div class="fw-bold">' + escapeHtml(cardNumber) + ' · ' + escapeHtml(visit.plate_number || "—") + '</div><div class="bulk-visit-meta"><span>' + escapeHtml(visit.clients && visit.clients.name || "—") + '</span><span>' + escapeHtml(formatActivity(visit.activity_type)) + '</span><span>' + escapeHtml(visit.destination_city || "—") + '</span></div></div><span class="badge rounded-pill text-bg-light border">Foto wajib</span></div>' +
            '<label class="form-label" for="photos-' + escapeHtml(visit.id) + '">Foto Selesai Loading</label>' +
            '<input class="form-control bulk-photo-input" type="file" id="photos-' + escapeHtml(visit.id) + '" data-photo-input accept="image/jpeg,image/png,image/webp" capture="environment" multiple>' +
            '<div class="form-text">JPG, PNG, atau WebP. Maksimal 10 MB per foto.</div>' +
            '<div class="bulk-photo-grid" data-photo-preview></div>' +
            '<div class="form-text" data-photo-count></div>';
          elements.finishDetails.appendChild(card);
          const preview = card.querySelector("[data-photo-preview]");
          const count = card.querySelector("[data-photo-count]");
          renderPhotoPreviews(visit.id, preview);
          count.textContent = (finishPhotos.get(visit.id) || []).length + " foto dipilih";
        });
      }
      renderTable();
    }

    function clearVisitSelection() {
      selectedIds.clear();
      startStates.clear();
      finishPhotos.forEach(function (_, visitId) { revokePreviewUrls(visitId); });
      finishPhotos.clear();
      renderSelectedDetails();
      renderTable();
    }

    function setMode(nextMode) {
      if (nextMode === "start" && !permission.startView) return;
      if (nextMode === "finish" && !permission.finishView) return;
      if (mode === nextMode) return;
      mode = nextMode;
      clearVisitSelection();
      results = [];
      elements.resultsCard.hidden = true;
      elements.startMode.classList.toggle("active", mode === "start");
      elements.finishMode.classList.toggle("active", mode === "finish");
      elements.startMode.setAttribute("aria-pressed", String(mode === "start"));
      elements.finishMode.setAttribute("aria-pressed", String(mode === "finish"));
      elements.description.textContent = mode === "start"
        ? "Pilih armada yang sudah dikonfirmasi WH In."
        : "Pilih armada yang sudah berstatus Proses Loading.";
      elements.startNotes.value = "";
      elements.finishNotes.value = "";
      elements.startNotesCount.textContent = "0";
      elements.saveStart.hidden = mode !== "start";
      elements.saveFinish.hidden = mode !== "finish";
      loadVisits().catch(function (error) {
        showMessage("error", "Gagal memuat data", error.message || "Daftar armada tidak dapat dimuat.");
      });
    }

    function setProcessing(value) {
      processing = value;
      elements.saveStart.disabled = value || !permission.startUpdate || selectedIds.size === 0;
      elements.saveFinish.disabled = value || !permission.finishUpdate || !permission.finishUpload || selectedIds.size === 0;
      elements.retryButton.disabled = value;
      elements.startMode.disabled = value;
      elements.finishMode.disabled = value;
      elements.refresh.disabled = value;
      renderTable();
    }

    function renderResults() {
      if (!results.length) {
        elements.resultsCard.hidden = true;
        return;
      }
      elements.resultsCard.hidden = false;
      const success = results.filter(function (item) { return item.status === "success"; }).length;
      const failed = results.filter(function (item) { return item.status === "failed"; }).length;
      const pending = results.filter(function (item) { return item.status === "pending"; }).length;
      elements.resultSummary.textContent = success + " berhasil · " + failed + " gagal" + (pending ? " · " + pending + " menunggu" : "");
      elements.resultList.innerHTML = results.map(function (item) {
        const visit = item.visit || {};
        const card = visit.cards && visit.cards.card_number ? visit.cards.card_number : "Armada";
        const status = item.status === "success"
          ? '<span class="text-success small fw-semibold"><i class="bi bi-check-circle-fill me-1"></i>Berhasil</span>'
          : item.status === "pending"
            ? '<span class="text-muted small">Menunggu</span>'
            : '<span class="text-danger small fw-semibold"><i class="bi bi-exclamation-circle-fill me-1"></i>Gagal</span>';
        return '<div class="bulk-result-row"><div class="min-w-0"><div class="fw-semibold">' + escapeHtml(card + " · " + (visit.plate_number || "—")) + '</div>' +
          (item.message ? '<div class="small text-muted">' + escapeHtml(item.message) + '</div>' : '') + '</div><div class="text-end flex-shrink-0">' + status + '</div></div>';
      }).join("");
      const hasFailed = results.some(function (item) { return item.status === "failed"; });
      elements.retryActions.hidden = !hasFailed;
      elements.retryButton.disabled = processing || !hasFailed;
    }

    async function getCurrentVisit(visitId) {
      const rows = await window.TRCM.visit.list("?select=id,process_status,wh_in_at,wh_out_at,started_at,completed_at&id=eq." + encodeURIComponent(visitId));
      if (!Array.isArray(rows) || !rows.length) throw new Error("Data armada tidak ditemukan saat validasi ulang.");
      return rows[0];
    }

    async function processStartVisit(visit) {
      const current = await getCurrentVisit(visit.id);
      if (current.process_status === "started" || current.process_status === "completed") {
        return { alreadyDone: true, message: "Status sudah berubah; tidak mengirim ulang proses Mulai." };
      }
      if (!["wh_in", "queue"].includes(current.process_status) || !current.wh_in_at || current.wh_out_at) {
        throw new Error("Status armada tidak lagi memenuhi syarat Mulai Loading.");
      }

      const state = getStartState(visit);
      if (state.loadingPlans || state.loadingItems) {
        throw new Error("Tunggu sampai data Plan dan DO/Shipment selesai dimuat.");
      }
      if (state.error || state.itemError) {
        throw new Error(state.error || state.itemError);
      }
      const hasSelectableItems = state.selectedPlanIds.size > 0 && state.availableItems.some(function (item) {
        return !state.processedIds.has(item.id);
      });
      if (hasSelectableItems && state.selectedItemIds.size === 0) {
        throw new Error("Pilih minimal satu DO atau Shipment dari Plan yang dipilih.");
      }

      const result = await window.TRCM.visit.rpc("start_loading_visit", {
        p_visit_id: visit.id,
        p_gate_id: elements.gate.value,
        p_line_number_id: elements.line.value,
        p_seal_number: state.sealNumber.trim() || null,
        p_notes: elements.startNotes.value.trim() || null,
        p_plan_item_ids: Array.from(state.selectedItemIds)
      });
      if (!result || result.visit_id !== visit.id || result.process_status !== "started") {
        const latest = await getCurrentVisit(visit.id).catch(function () { return null; });
        if (latest && ["started", "completed"].includes(latest.process_status)) {
          return { alreadyDone: true, message: "Mulai Loading sudah tersimpan di database." };
        }
        throw new Error("Respons penyimpanan Mulai Loading tidak valid.");
      }
      return { message: "Mulai Loading tersimpan." };
    }

    async function compressPhoto(file) {
      let imageSource;
      let bitmap = null;
      let objectUrl = null;
      try {
        try {
          bitmap = await createImageBitmap(file);
          imageSource = bitmap;
        } catch (bitmapError) {
          objectUrl = URL.createObjectURL(file);
          const image = new Image();
          await new Promise(function (resolve, reject) {
            image.onload = resolve;
            image.onerror = function () { reject(new Error("Browser tidak dapat membaca file foto yang dipilih.")); };
            image.src = objectUrl;
          });
          imageSource = image;
        }
        const imageWidth = imageSource.width || imageSource.naturalWidth;
        const imageHeight = imageSource.height || imageSource.naturalHeight;
        if (!imageWidth || !imageHeight) throw new Error("Ukuran foto tidak dapat dibaca.");
        const scale = Math.min(1, 1600 / Math.max(imageWidth, imageHeight));
        const canvas = document.createElement("canvas");
        canvas.width = Math.max(1, Math.round(imageWidth * scale));
        canvas.height = Math.max(1, Math.round(imageHeight * scale));
        const context = canvas.getContext("2d", { alpha: false });
        if (!context) throw new Error("Browser tidak dapat memproses foto.");
        context.drawImage(imageSource, 0, 0, canvas.width, canvas.height);
        const blob = await new Promise(function (resolve) { canvas.toBlob(resolve, "image/webp", 0.78); });
        if (!blob) throw new Error("Foto gagal diproses.");
        return blob;
      } finally {
        if (bitmap) bitmap.close();
        if (objectUrl) URL.revokeObjectURL(objectUrl);
      }
    }

    async function cleanupUploadedPhotos(photoRecordIds, objectPaths) {
      for (const photoId of photoRecordIds) {
        try { await window.TRCM.photo.deleteRecord(photoId); }
        catch (error) { console.warn("Bulk Checker cleanup metadata foto:", error); }
      }
      for (const objectPath of objectPaths) {
        try {
          const response = await window.TRCM.photo.remove(objectPath);
          if (!response.ok) throw new Error("Storage tidak menghapus objek foto.");
        } catch (error) { console.warn("Bulk Checker cleanup Storage foto:", error); }
      }
    }

    async function processFinishVisit(visit) {
      const current = await getCurrentVisit(visit.id);
      if (current.process_status === "completed" || current.wh_out_at) {
        return { alreadyDone: true, message: "Selesai Loading sudah tercatat; tidak mengirim ulang proses." };
      }
      if (current.process_status !== "started" || !current.started_at || current.wh_out_at) {
        throw new Error("Status armada tidak lagi memenuhi syarat Selesai Loading.");
      }

      const files = finishPhotos.get(visit.id) || [];
      if (!files.length) throw new Error("Pilih minimal satu foto untuk armada ini.");

      const uploadedPaths = [];
      const photoRecordIds = [];
      try {
        for (const file of files) {
          const blob = await compressPhoto(file);
          const objectPath = visit.id + "/" + crypto.randomUUID() + ".webp";
          const uploadResponse = await window.TRCM.photo.upload(objectPath, blob, "image/webp");
          if (!uploadResponse.ok) {
            const body = await uploadResponse.text();
            let detail = null;
            try { detail = body ? JSON.parse(body) : null; } catch {}
            throw new Error(detail && (detail.message || detail.error) || "Foto gagal diunggah.");
          }
          uploadedPaths.push(objectPath);
          const rows = await window.TRCM.photo.createRecord({
            visit_id: visit.id,
            photo_type: "loading_completion",
            file_location: objectPath,
            uploaded_by: session.user.id
          });
          if (!Array.isArray(rows) || !rows[0] || !rows[0].id) {
            throw new Error("Metadata foto tidak berhasil disimpan.");
          }
          photoRecordIds.push(rows[0].id);
        }

        const result = await window.TRCM.visit.rpc("finish_loading_visit", {
          p_visit_id: visit.id,
          p_notes: elements.finishNotes.value.trim() || null
        });
        if (!result || result.visit_id !== visit.id || result.process_status !== "completed") {
          throw new Error("Respons penyimpanan Selesai Loading tidak valid.");
        }
        return { message: "Selesai Loading dan foto berhasil disimpan." };
      } catch (error) {
        const latest = await getCurrentVisit(visit.id).catch(function () { return null; });
        if (latest && (latest.process_status === "completed" || latest.wh_out_at)) {
          return { alreadyDone: true, message: "Selesai Loading sudah tersimpan. Foto dipertahankan." };
        }
        if (latest && latest.process_status === "started") {
          await cleanupUploadedPhotos(photoRecordIds, uploadedPaths);
        } else {
          console.warn("Status visit tidak dapat dipastikan; foto dipertahankan untuk mencegah penghapusan bukti yang mungkin sudah terpakai.", visit.id);
          throw new Error((error.message || "Penyimpanan Selesai Loading gagal.") + " Status database belum dapat dipastikan; foto yang sudah diunggah dipertahankan. Periksa visit sebelum mencoba ulang.");
        }
        throw error;
      }
    }

    async function processOne(visit) {
      if (mode === "start") return processStartVisit(visit);
      return processFinishVisit(visit);
    }

    async function processBatch(ids, isRetry) {
      if (processing) return;
      const selected = ids.map(function (id) { return visits.find(function (visit) { return visit.id === id; }); }).filter(Boolean);
      if (!selected.length) return;

      if (!isRetry) {
        if (mode === "start") {
          if (!elements.gate.value || !elements.line.value) {
            await showMessage("warning", "Data bersama belum lengkap", "Pilih Nomor gerbang dan Nomor line terlebih dahulu.");
            return;
          }
          const matchingLine = lines.some(function (line) { return line.id === elements.line.value && line.gate_id === elements.gate.value; });
          if (!matchingLine) {
            await showMessage("warning", "Line tidak sesuai", "Pilih Line yang terhubung dengan Gate yang dipilih.");
            return;
          }
          const withoutPlan = selected.filter(function (visit) {
            const state = getStartState(visit);
            return state.selectedPlanIds.size === 0;
          });
          if (withoutPlan.length) {
            const confirmWithoutPlan = await Swal.fire({
              icon: "warning",
              title: "Lanjut tanpa Plan?",
              text: withoutPlan.length + " armada tidak memiliki Plan yang dipilih. Loading tetap dapat dimulai tanpa mengaitkan DO/Shipment.",
              showCancelButton: true,
              confirmButtonText: "Lanjutkan",
              cancelButtonText: "Periksa kembali",
              confirmButtonColor: "#006ECD"
            });
            if (!confirmWithoutPlan.isConfirmed) return;
          }
        } else {
          const withoutPhotos = selected.filter(function (visit) {
            return !(finishPhotos.get(visit.id) || []).length;
          });
          if (withoutPhotos.length) {
            await showMessage("warning", "Foto belum lengkap", withoutPhotos.length + " armada belum memiliki foto. Setiap armada wajib memiliki minimal satu foto.");
            return;
          }
        }

        const confirm = await Swal.fire({
          icon: "question",
          title: mode === "start" ? "Mulai Loading untuk beberapa armada?" : "Selesaikan Loading untuk beberapa armada?",
          text: "Sistem akan memproses " + selected.length + " armada satu per satu.",
          showCancelButton: true,
          confirmButtonText: "Ya, proses",
          cancelButtonText: "Kembali",
          confirmButtonColor: mode === "start" ? "#FF9700" : "#006ECD"
        });
        if (!confirm.isConfirmed) return;
        results = [];
      }

      setProcessing(true);
      try {
        for (const visit of selected) {
          const existing = results.find(function (item) { return item.visit.id === visit.id; });
          const resultItem = existing || { visit: visit, status: "pending", message: "" };
          resultItem.status = "pending";
          resultItem.message = "";
          if (!existing) results.push(resultItem);
          renderResults();

          try {
            const result = await processOne(visit);
            resultItem.status = "success";
            resultItem.message = result.message || "Berhasil.";
            selectedIds.delete(visit.id);
            if (mode === "start") startStates.delete(visit.id);
            else {
              finishPhotos.delete(visit.id);
              revokePreviewUrls(visit.id);
            }
          } catch (error) {
            resultItem.status = "failed";
            resultItem.message = error.message || "Gagal memproses armada.";
          }
          renderResults();
          renderSelectedDetails();
        }

        await loadVisits();
      } finally {
        setProcessing(false);
        renderResults();
        renderSelectedDetails();
      }
    }

    function handlePhotoSelection(input) {
      const visitId = input.closest("[data-finish-card]").getAttribute("data-finish-card");
      const incoming = Array.from(input.files || []);
      const existing = finishPhotos.get(visitId) || [];
      for (const file of incoming) {
        if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
          showMessage("error", "Format foto tidak didukung", "Gunakan foto JPG, PNG, atau WebP.");
          input.value = "";
          return;
        }
        if (file.size > 10 * 1024 * 1024) {
          showMessage("error", "Ukuran foto terlalu besar", "Ukuran setiap foto maksimal 10 MB.");
          input.value = "";
          return;
        }
      }
      const keys = new Set(existing.map(function (file) { return file.name + ":" + file.size + ":" + file.lastModified; }));
      incoming.forEach(function (file) {
        const key = file.name + ":" + file.size + ":" + file.lastModified;
        if (!keys.has(key)) {
          existing.push(file);
          keys.add(key);
        }
      });
      finishPhotos.set(visitId, existing);
      input.value = "";
      renderSelectedDetails();
    }

    elements.startMode.addEventListener("click", function () { setMode("start"); });
    elements.finishMode.addEventListener("click", function () { setMode("finish"); });
    elements.gate.addEventListener("change", function () { populateLines(elements.gate.value); });
    elements.startNotes.addEventListener("input", function () { elements.startNotesCount.textContent = String(elements.startNotes.value.length); });
    elements.search.addEventListener("input", renderTable);
    elements.client.addEventListener("change", renderTable);
    elements.selectAll.addEventListener("change", function () {
      visibleVisits().forEach(function (visit) {
        if (elements.selectAll.checked) selectedIds.add(visit.id);
        else selectedIds.delete(visit.id);
      });
      renderSelectedDetails();
      renderTable();
    });

    elements.table.addEventListener("change", function (event) {
      const checkbox = event.target.closest(".bulk-visit-checkbox");
      if (!checkbox) return;
      if (checkbox.checked) selectedIds.add(checkbox.dataset.visitId);
      else {
        selectedIds.delete(checkbox.dataset.visitId);
        startStates.delete(checkbox.dataset.visitId);
        finishPhotos.delete(checkbox.dataset.visitId);
        revokePreviewUrls(checkbox.dataset.visitId);
      }
      renderSelectedDetails();
      renderTable();
    });

    elements.startDetails.addEventListener("input", function (event) {
      const card = event.target.closest("[data-visit-card]");
      if (!card) return;
      const visitId = card.getAttribute("data-visit-card");
      const state = startStates.get(visitId);
      if (state && event.target.matches("[data-seal-number]")) state.sealNumber = event.target.value;
    });

    elements.startDetails.addEventListener("change", async function (event) {
      const card = event.target.closest("[data-visit-card]");
      if (!card) return;
      const visitId = card.getAttribute("data-visit-card");
      const visit = visits.find(function (item) { return item.id === visitId; });
      const state = startStates.get(visitId);
      if (!visit || !state) return;
      if (event.target.matches("[data-plan-date-from]")) {
        state.dateFrom = event.target.value;
        await loadPlansForVisit(visit, state, true);
      } else if (event.target.matches("[data-plan-date-to]")) {
        state.dateTo = event.target.value;
        await loadPlansForVisit(visit, state, true);
      } else if (event.target.matches("[data-all-activities]")) {
        state.allActivities = event.target.checked;
        await loadPlansForVisit(visit, state, true);
      }
    });

    elements.finishDetails.addEventListener("change", function (event) {
      if (event.target.matches("[data-photo-input]")) handlePhotoSelection(event.target);
    });

    elements.finishDetails.addEventListener("click", function (event) {
      const button = event.target.closest("[data-remove-photo]");
      if (!button) return;
      const visitId = button.dataset.visitId;
      const files = finishPhotos.get(visitId) || [];
      files.splice(Number(button.dataset.removePhoto), 1);
      finishPhotos.set(visitId, files);
      renderSelectedDetails();
    });

    elements.saveStart.addEventListener("click", function () {
      processBatch(Array.from(selectedIds), false);
    });
    elements.saveFinish.addEventListener("click", function () {
      processBatch(Array.from(selectedIds), false);
    });
    elements.retryButton.addEventListener("click", function () {
      const failedIds = results.filter(function (item) { return item.status === "failed"; }).map(function (item) { return item.visit.id; });
      processBatch(failedIds, true);
    });
    elements.clearResults.addEventListener("click", function () {
      results = [];
      renderResults();
    });

    elements.refresh.addEventListener("click", function () {
      window.trcmRunRefresh(elements.refresh, loadVisits);
    });

    if (!permission.startView) elements.startMode.hidden = true;
    if (!permission.finishView) elements.finishMode.hidden = true;
    if (!permission.startView && !permission.finishView) {
      await showMessage("error", "Akses tidak tersedia", "Anda tidak memiliki permission untuk melihat aktivitas Checker.");
      elements.table.innerHTML = '<tr><td colspan="8" class="table-state error-state">Akses tidak tersedia.</td></tr>';
      return;
    }
    if (!permission.startUpdate) elements.saveStart.title = "Anda tidak memiliki permission untuk Mulai Loading.";
    if (!permission.finishUpdate || !permission.finishUpload) {
      elements.saveFinish.title = "Anda tidak memiliki permission untuk menyelesaikan Loading dan mengunggah foto.";
    }

    elements.saveStart.hidden = mode !== "start";
    elements.saveFinish.hidden = mode !== "finish";
    elements.saveStart.disabled = !permission.startUpdate;
    elements.saveFinish.disabled = !permission.finishUpdate || !permission.finishUpload;

    try {
      if (permission.startView) await loadReferenceData();
      await loadVisits();
      window.trcmRegisterRefresh(loadVisits);
    } catch (error) {
      await showMessage("error", "Gagal memuat Bulk Checker", error.message || "Data awal tidak dapat dimuat.");
    }
  }).catch(function (error) {
    console.error("TRCM Bulk Checker initialization:", error);
  });
})();
