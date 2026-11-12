(function () {
  "use strict";

  function create(options) {
    const state = options.state;
    const elements = options.elements;
    const helpers = options.helpers;
    const activityLabels = options.activityLabels;
    const planService = options.planService;
    const getSelectedVisit = options.getSelectedVisit;
    const getLinkedIds = options.getLinkedIds;
    const {
      planDateFromInput,
      planDateToInput,
      planSelect,
      planDropdownToggle,
      planDropdownLabel,
      planDropdownMenu,
      planShipmentList,
      planSelectionContext,
      planShipmentCount,
      clearPlanSelection
    } = elements;
    const { escapeHtml: esc, getPlanShipmentGroups, formatPlanDate } = helpers;

    function refreshPlanDropdown() {
      const options = Array.from(planSelect.options).filter(option => Boolean(option.value));
      const selected = options.filter(option => option.selected);
      planDropdownToggle.disabled = planSelect.disabled || options.length === 0;
      planDropdownLabel.textContent = selected.length ? selected.length + " Plan dipilih" : (options.length ? "Pilih Plan aktif…" : (planSelect.options[0] ? planSelect.options[0].textContent : "Pilih Plan aktif…"));
      if (!options.length) {
        planDropdownMenu.innerHTML = '<div class="small text-muted px-2 py-1">' + esc(planDropdownLabel.textContent) + '</div>';
        return;
      }
      planDropdownMenu.innerHTML = options.map((option, index) => '<label class="dropdown-item d-flex align-items-start gap-2 text-wrap" for="hub-plan-option-' + index + '"><input class="form-check-input mt-1 flex-shrink-0" type="checkbox" id="hub-plan-option-' + index + '" data-plan-id="' + esc(option.value) + '"' + (option.selected ? " checked" : "") + '><span>' + esc(option.textContent) + '</span></label>').join("");
      planDropdownMenu.querySelectorAll("[data-plan-id]").forEach(checkbox => {
        checkbox.addEventListener("change", () => {
          const option = Array.from(planSelect.options).find(item => item.value === checkbox.dataset.planId);
          if (!option) return;
          option.selected = checkbox.checked;
          refreshPlanDropdown();
          loadPlanItems(Array.from(planSelect.selectedOptions).map(item => item.value));
        });
      });
    }

    function updatePlanShipmentCount() {
      const selectedGroups = getPlanShipmentGroups(state.availablePlanItems).filter(group => group.items.some(item => state.selectedPlanItemIds.has(item.id))).length;
      planShipmentCount.textContent = selectedGroups + " DO/Shipment dipilih · " + state.selectedPlanItemIds.size + " item";
      clearPlanSelection.disabled = state.selectedPlanItemIds.size === 0;
    }

    function resetPlanShipmentSelection(message) {
      state.availablePlanItems = [];
      state.selectedPlanItemIds = new Set();
      planShipmentList.innerHTML = '<div class="border rounded-3 p-3 text-muted small">' + esc(message) + '</div>';
      updatePlanShipmentCount();
    }

    function renderPlanShipments() {
      if (!state.availablePlanItems.length) {
        resetPlanShipmentSelection("Plan ini belum memiliki detail DO atau Shipment.");
        return;
      }
      const trips = new Map();
      getPlanShipmentGroups(state.availablePlanItems).forEach(group => {
        const trip = group.trip;
        const tripLabel = trip ? ["Trip " + (trip.trip_number || "—"), trip.plate_number || "Armada Plan", trip.vendor || "", trip.destination || ""].filter(Boolean).join(" · ") : "Detail Plan";
        if (!trips.has(tripLabel)) trips.set(tripLabel, []);
        trips.get(tripLabel).push(group);
      });
      planShipmentList.innerHTML = Array.from(trips.entries()).map(entry => {
        const rows = entry[1].map((group, index) => {
          const groupId = "hub-shipment-" + index + "-" + group.key.replace(/[^a-z0-9_-]/g, "-");
          const alreadyProcessed = group.items.some(item => state.processedPlanItemIds.has(item.id));
          const selectableItems = group.items.filter(item => !state.processedPlanItemIds.has(item.id));
          const allSelected = !alreadyProcessed && selectableItems.length > 0 && selectableItems.every(item => state.selectedPlanItemIds.has(item.id));
          const someSelected = !alreadyProcessed && selectableItems.some(item => state.selectedPlanItemIds.has(item.id));
          const tripName = group.trip ? ["Trip " + (group.trip.trip_number || "—"), group.trip.plate_number || "Armada Plan", group.trip.vendor || "", group.trip.destination || ""].filter(Boolean).join(" · ") : "";
          return '<label class="border rounded-3 p-3 mb-2 d-block' + (someSelected ? ' border-primary bg-primary-subtle' : '') + (alreadyProcessed ? ' border-secondary bg-body-tertiary' : '') + '"' + (alreadyProcessed ? '' : ' for="' + esc(groupId) + '"') + '><div class="d-flex align-items-start gap-3">' +
            (alreadyProcessed ? '<span class="text-muted mt-1 flex-shrink-0" aria-hidden="true"><i class="bi bi-check-circle-fill"></i></span>' : '<input class="form-check-input mt-1 flex-shrink-0" type="checkbox" id="' + esc(groupId) + '" data-plan-group-key="' + esc(group.key) + '"' + (allSelected ? " checked" : "") + ' aria-label="Pilih DO/Shipment ' + esc(group.label) + '">' ) +
            '<div class="flex-grow-1 min-w-0"><div class="d-flex flex-wrap align-items-center gap-2"><span class="fw-semibold text-break">' + esc(group.label) + '</span><span class="badge text-bg-light border">' + group.items.length + ' referensi</span>' +
            (alreadyProcessed ? '<span class="badge text-bg-secondary">Sudah terhubung / diproses</span>' : '') + (tripName ? '<span class="small text-muted">' + esc(tripName) + '</span>' : '') + '</div></div></div></label>';
        }).join("");
        return '<section class="mb-3"><div class="small fw-semibold text-muted mb-2">' + esc(entry[0]) + '</div>' + rows + '</section>';
      }).join("");
      planShipmentList.querySelectorAll("[data-plan-group-key]").forEach(checkbox => {
        checkbox.addEventListener("change", () => {
          const group = getPlanShipmentGroups(state.availablePlanItems).find(item => item.key === checkbox.dataset.planGroupKey);
          if (!group) return;
          group.items.forEach(item => {
            if (state.processedPlanItemIds.has(item.id)) return;
            if (checkbox.checked) state.selectedPlanItemIds.add(item.id);
            else state.selectedPlanItemIds.delete(item.id);
          });
          renderPlanShipments();
        });
      });
      updatePlanShipmentCount();
    }

    async function loadPlansForSelectedVisit() {
      const sequence = ++state.planLoadSequence;
      const visit = getSelectedVisit();
      const dateFrom = planDateFromInput.value, dateTo = planDateToInput.value;
      state.availablePlans = [];
      state.availablePlanItems = [];
      state.selectedPlanItemIds = new Set();
      planSelect.disabled = true;
      planSelect.innerHTML = '<option value="">Memuat Plan…</option>';
      refreshPlanDropdown();
      resetPlanShipmentSelection("Memuat Plan dan DO/Shipment…");
      if (!visit || !dateFrom || !dateTo || !visit.client_id || !visit.activity_type) {
        planSelect.innerHTML = '<option value="">Lengkapi rentang tanggal terlebih dahulu</option>';
        planSelectionContext.textContent = "Plan difilter berdasarkan klien, aktivitas, dan rentang tanggal operasional.";
        refreshPlanDropdown();
        return;
      }
      if (dateFrom > dateTo) {
        planSelect.innerHTML = '<option value="">Rentang tanggal tidak valid</option>';
        planSelectionContext.textContent = "Tanggal awal harus sama dengan atau sebelum tanggal akhir.";
        resetPlanShipmentSelection("Periksa kembali rentang tanggal yang dipilih.");
        refreshPlanDropdown();
        return;
      }
      try {
        const filters = "client_id=eq." + encodeURIComponent(visit.client_id) +
          "&activity_type=eq." + encodeURIComponent(String(visit.activity_type).toLowerCase()) +
          "&operational_date=gte." + encodeURIComponent(dateFrom) +
          "&operational_date=lte." + encodeURIComponent(dateTo) +
          "&status=eq.active&order=operational_date.asc,created_at.desc";
        const plans = await planService.request("/rest/v1/import_plans?select=id,client_id,operational_date,activity_type,status,row_count,import_plan_trips(count)&" + filters, {}, { errorMessage: "Daftar Plan gagal dimuat." });
        if (sequence !== state.planLoadSequence) return;
        if (!Array.isArray(plans)) throw new Error("Respons Plan tidak valid.");
        state.availablePlans = plans;
        planSelect.innerHTML = plans.length ? plans.map(plan => {
          const truckCount = Array.isArray(plan.import_plan_trips) && plan.import_plan_trips.length ? Number(plan.import_plan_trips[0].count || 0) : 0;
          return '<option value="' + esc(plan.id) + '">' + esc(activityLabels[plan.activity_type] || plan.activity_type) + ' · Plan ' + esc(formatPlanDate(plan.operational_date)) + ' · ' + esc(truckCount) + ' Truk</option>';
        }).join("") : '<option value="" disabled selected>Tidak ada Plan aktif yang cocok dengan filter</option>';
        planSelect.disabled = plans.length === 0;
        planSelectionContext.textContent = plans.length ? plans.length + " Plan aktif ditemukan dari " + formatPlanDate(dateFrom) + " sampai " + formatPlanDate(dateTo) + "." : "Tidak ada Plan aktif dalam rentang tanggal ini untuk klien dan aktivitas armada.";
        if (!plans.length) resetPlanShipmentSelection("Tidak ada Plan aktif yang sesuai. Periksa rentang tanggal atau data Plan.");
        refreshPlanDropdown();
      } catch (error) {
        if (sequence !== state.planLoadSequence) return;
        planSelect.innerHTML = '<option value="">Plan gagal dimuat</option>';
        planSelectionContext.textContent = error.message || "Plan tidak dapat dimuat.";
        resetPlanShipmentSelection("Gagal memuat Plan. Silakan ubah rentang tanggal atau coba kembali.");
        refreshPlanDropdown();
        console.error("TRCM Hubungkan Plan picker:", error);
      }
    }

    async function loadPlanItems(planIds) {
      const sequence = ++state.planLoadSequence;
      const ids = Array.from(new Set((Array.isArray(planIds) ? planIds : [planIds]).filter(Boolean)));
      const plans = ids.map(id => state.availablePlans.find(item => item.id === id)).filter(Boolean);
      const selectedPlanIdSet = new Set(ids);
      state.selectedPlanItemIds = new Set(Array.from(state.selectedPlanItemIds).filter(id => state.availablePlanItems.some(item => item.id === id && selectedPlanIdSet.has(item.plan_id))));
      state.availablePlanItems = state.availablePlanItems.filter(item => selectedPlanIdSet.has(item.plan_id));
      state.processedPlanItemIds = new Set(Array.from(state.processedPlanItemIds).filter(id => state.availablePlanItems.some(item => item.id === id)));
      updatePlanShipmentCount();
      if (!plans.length) {
        state.availablePlanItems = [];
        state.processedPlanItemIds = new Set();
        state.selectedPlanItemIds = new Set();
        resetPlanShipmentSelection("Pilih satu atau beberapa Plan aktif untuk melihat DO/Shipment.");
        return;
      }
      planShipmentList.innerHTML = '<div class="border rounded-3 p-3 text-muted small">Memuat DO/Shipment dari Plan terpilih…</div>';
      try {
        const results = await Promise.all(plans.map(async plan => {
          const [items, trips] = await Promise.all([
            planService.request("/rest/v1/import_plan_items?select=id,plan_id,trip_id,row_number,do_number,shipment_number,manual_processed&plan_id=eq." + encodeURIComponent(plan.id) + "&order=row_number.asc", {}, { errorMessage: "Detail DO/Shipment gagal dimuat." }),
            planService.request("/rest/v1/import_plan_trips?select=id,plan_id,trip_number,vendor,plate_number,destination&plan_id=eq." + encodeURIComponent(plan.id) + "&order=trip_number.asc", {}, { errorMessage: "Detail armada Plan gagal dimuat." })
          ]);
          if (!Array.isArray(items) || !Array.isArray(trips)) throw new Error("Rincian DO/Shipment Plan tidak valid.");
          const tripById = new Map(trips.map(trip => [trip.id, trip]));
          return items.map(item => Object.assign({}, item, { trip: tripById.get(item.trip_id) || null, activity_type: plan.activity_type, plan_date: plan.operational_date }));
        }));
        if (sequence !== state.planLoadSequence) return;
        const loadedItems = results.flat();
        const loadedIds = new Set(loadedItems.map(item => item.id));
        state.availablePlanItems = loadedItems;
        state.processedPlanItemIds = new Set(loadedItems.filter(item => item.manual_processed === true || getLinkedIds().has(item.id)).map(item => item.id));
        state.selectedPlanItemIds = new Set(Array.from(state.selectedPlanItemIds).filter(id => loadedIds.has(id) && !state.processedPlanItemIds.has(id)));
        renderPlanShipments();
        planSelectionContext.textContent = plans.length + " Plan dipilih; DO dan Shipment ditampilkan sesuai aktivitas armada.";
      } catch (error) {
        if (sequence !== state.planLoadSequence) return;
        resetPlanShipmentSelection("Rincian DO/Shipment gagal dimuat. Perbarui pilihan Plan untuk mencoba lagi.");
        planSelectionContext.textContent = error.message || "Rincian DO/Shipment tidak dapat dimuat.";
        console.error("TRCM Hubungkan Plan items:", error);
      }
    }

    function resetForVisit() {
      planSelect.innerHTML = '<option value="">Memuat Plan…</option>';
      planSelect.disabled = true;
      refreshPlanDropdown();
      planSelectionContext.textContent = "Plan difilter berdasarkan klien, aktivitas, dan rentang tanggal operasional armada.";
      resetPlanShipmentSelection("Pilih rentang tanggal untuk melihat Plan dan DO/Shipment yang tersedia.");
    }

    function bind() {
      planDateFromInput.addEventListener("change", loadPlansForSelectedVisit);
      planDateToInput.addEventListener("change", loadPlansForSelectedVisit);
      planSelect.addEventListener("change", () => {
        refreshPlanDropdown();
        loadPlanItems(Array.from(planSelect.selectedOptions).map(option => option.value));
      });
      clearPlanSelection.addEventListener("click", () => {
        state.selectedPlanItemIds = new Set();
        renderPlanShipments();
      });
    }

    function invalidate() {
      state.planLoadSequence++;
    }

    return {
      bind: bind,
      invalidate: invalidate,
      loadPlansForSelectedVisit: loadPlansForSelectedVisit,
      resetForVisit: resetForVisit
    };
  }

  window.TRCM = window.TRCM || {};
  window.TRCM.hubungkanPlan = window.TRCM.hubungkanPlan || {};
  window.TRCM.hubungkanPlan.planPicker = { create: create };
})();