(function () {
  "use strict";

  const INIT_RETRY_DELAY_MS = 100;
  const INIT_MAX_ATTEMPTS = 100;
  const RESPONSIVE_SCRIPT_URL = new URL("assets/rigi-responsive.js", document.baseURI).href;
  let initAttempts = 0;
  let initRetryTimer = null;
  let initErrorReported = false;

  function missingDependencies() {
    const missing = [];
    if (typeof window.Plotly === "undefined") missing.push("window.Plotly");
    if (typeof window.RigiResponsive === "undefined") missing.push("window.RigiResponsive");
    return missing;
  }

  function retryInitialization(root, missing) {
    initAttempts += 1;
    if (initAttempts < INIT_MAX_ATTEMPTS) {
      if (initRetryTimer === null) {
        initRetryTimer = window.setTimeout(function () {
          initRetryTimer = null;
          initImportaciones();
        }, INIT_RETRY_DELAY_MS);
      }
      return;
    }

    root.dataset.initializationError = missing.join(", ");
    if (!initErrorReported) {
      initErrorReported = true;
      console.error(
        "[Monitor RIGI] No se pudo inicializar Importaciones. " +
        "Dependencias faltantes: " + missing.join(", ") + ". " +
        "Script responsive esperado: " + RESPONSIVE_SCRIPT_URL
      );
    }
  }

  function initImportaciones() {
    const root = document.getElementById("importaciones-module");
    if (!root || root.dataset.initialized === "true") return;

    const missing = missingDependencies();
    if (missing.length > 0) {
      retryInitialization(root, missing);
      return;
    }

    delete root.dataset.initializationError;
    root.dataset.initialized = "true";

    const rawData = JSON.parse(document.getElementById("importaciones-data").textContent || "[]").map((d) => ({
      month: String(d.fecha_mes || "").slice(0, 7),
      sector: String(d.sector),
      project: String(d.proyecto),
      value: Number(d.fob_mill_usd || 0)
    }));
    const sectorColors = JSON.parse(document.getElementById("importaciones-colors").textContent || "{}");
    const projectColors = JSON.parse(document.getElementById("importaciones-project-colors").textContent || "{}");
    const projectMetadataRows = JSON.parse(document.getElementById("importaciones-project-metadata").textContent || "[]");
    const projectMetadata = new Map(projectMetadataRows.map((d) => [String(d.project), d]));
    const responsive = window.RigiResponsive;
    const plotConfig = responsive.getPlotlyInteractionConfig();

    const charts = {
      sectorMonthly: document.getElementById("impo-sector-monthly-chart"),
      sectorCumulative: document.getElementById("impo-sector-cumulative-chart"),
      projectMonthly: document.getElementById("impo-project-monthly-chart"),
      projectCumulative: document.getElementById("impo-project-cumulative-chart")
    };

    const controls = {
      sector: {
        start: document.getElementById("impo-sector-month-start"),
        end: document.getElementById("impo-sector-month-end"),
        all: document.getElementById("impo-sector-filter-all"),
        summary: document.getElementById("impo-sector-filter-summary"),
        reset: document.getElementById("impo-sector-reset"),
        inputs: Array.from(root.querySelectorAll(".impo-sector-filter-option"))
      },
      project: {
        start: document.getElementById("impo-project-month-start"),
        end: document.getElementById("impo-project-month-end"),
        sectorAll: document.getElementById("impo-project-sector-filter-all"),
        sectorSummary: document.getElementById("impo-project-sector-filter-summary"),
        reset: document.getElementById("impo-project-reset"),
        sectorInputs: Array.from(root.querySelectorAll(".impo-project-sector-filter-option")),
        details: document.getElementById("impo-project-details"),
        summary: document.getElementById("impo-project-summary"),
        search: document.getElementById("impo-project-search"),
        empty: document.getElementById("impo-project-empty"),
        inputs: Array.from(root.querySelectorAll(".impo-project-option-input")),
        selectAll: document.getElementById("impo-project-select-all"),
        clear: document.getElementById("impo-project-clear"),
        status: document.getElementById("impo-project-selection-status"),
        cardToggle: document.getElementById("impo-project-card-toggle"),
        cardHelp: document.getElementById("impo-project-card-help"),
        card: document.getElementById("impo-project-info")
      }
    };

    const observedMonths = rawData.map((d) => d.month).filter(Boolean).sort();
    const minMonth = observedMonths[0];
    const maxMonth = observedMonths[observedMonths.length - 1];
    const allMonths = monthSequence(minMonth, maxMonth);

    const formatter = new Intl.NumberFormat("es-AR", { maximumFractionDigits: 1 });
    const pctFormatter = new Intl.NumberFormat("es-AR", {
      style: "percent",
      maximumFractionDigits: 1
    });
    const monthFormatter = new Intl.DateTimeFormat("es-AR", {
      month: "short",
      year: "numeric",
      timeZone: "UTC"
    });

    let syncingSectorMonthly = false;
    let syncingSectorCumulative = false;
    let projectCardOpen = false;

    function monthSequence(start, end) {
      if (!start || !end) return [];
      const out = [];
      let year = Number(start.slice(0, 4));
      let month = Number(start.slice(5, 7));
      const endYear = Number(end.slice(0, 4));
      const endMonth = Number(end.slice(5, 7));

      while (year < endYear || (year === endYear && month <= endMonth)) {
        out.push(String(year).padStart(4, "0") + "-" + String(month).padStart(2, "0"));
        month += 1;
        if (month === 13) {
          month = 1;
          year += 1;
        }
      }
      return out;
    }

    function monthToDate(month) {
      return month + "-01";
    }

    function dateToMonth(value) {
      return String(value || "").slice(0, 7);
    }

    function formatMonth(month) {
      const year = Number(month.slice(0, 4));
      const monthNumber = Number(month.slice(5, 7));
      const date = new Date(Date.UTC(year, monthNumber - 1, 1));
      return monthFormatter.format(date).replace(/^./, (x) => x.toUpperCase());
    }

    function formatMonthTick(month) {
      const monthNames = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
      const year = month.slice(0, 4);
      const monthNumber = Number(month.slice(5, 7));
      const monthLabel = monthNames[monthNumber - 1] || "";
      return monthLabel + "<br>" + year;
    }

    function visibleMonths(start, end) {
      return allMonths.filter((month) => month >= start && month <= end);
    }

    function selectedValues(inputs) {
      return inputs.filter((input) => input.checked && !input.disabled).map((input) => input.value);
    }

    function updateMasterCheckbox(master, inputs) {
      const active = inputs.filter((input) => !input.disabled);
      const checked = active.filter((input) => input.checked);
      master.checked = active.length > 0 && checked.length === active.length;
      master.indeterminate = checked.length > 0 && checked.length < active.length;
      master.disabled = active.length === 0;
    }

    function updateSummary(summary, inputs, allLabel) {
      const active = inputs.filter((input) => !input.disabled);
      const selected = active.filter((input) => input.checked);

      if (active.length > 0 && selected.length === active.length) {
        summary.textContent = allLabel;
      } else if (selected.length === 0) {
        summary.textContent = "Ninguno seleccionado";
      } else if (selected.length === 1) {
        summary.textContent = selected[0].value;
      } else {
        summary.textContent = selected.length + " seleccionados";
      }
    }

    function traceIsVisible(trace) {
      return trace.visible !== "legendonly" && trace.visible !== false;
    }

    function barLabel(value) {
      return value > 0 ? formatter.format(value) : "";
    }

    function tickStep(count) {
      if (count <= 12) return 1;
      if (count <= 24) return 2;
      if (count <= 36) return 3;
      if (count <= 60) return 6;
      return 12;
    }

    function buildTicks(months, profile) {
      const step = profile && profile.compact
        ? Math.max(1, Math.ceil(months.length / 24))
        : tickStep(months.length);
      const selected = months.filter((month, i) => i % step === 0 || i === months.length - 1);
      return {
        vals: selected.map(monthToDate),
        text: selected.map((month) => formatMonthTick(month))
      };
    }

    function buildBaseLayout(months, options) {
      const opts = options || {};
      const profile = opts.profile || responsive.getResponsivePlotConfig();
      const ticks = buildTicks(months, profile);
      const hasLegend = opts.showLegend !== false;
      return {
        autosize: true,
        height: profile.height,
        dragmode: false,
        margin: {
          l: profile.leftMargin,
          r: profile.rightMargin,
          t: profile.topMargin,
          b: opts.bottomMargin || (hasLegend ? (profile.compact ? 132 : 112) : (profile.compact ? 76 : 80))
        },
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(0,0,0,0)",
        font: {
          family: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
          color: "#334155",
          size: profile.fontSize
        },
        hoverlabel: {
          bgcolor: "#FFFFFF",
          bordercolor: "#CBD5E1",
          font: { color: "#0F172A" }
        },
        legend: {
          orientation: "h",
          x: 0.5,
          xanchor: "center",
          y: profile.compact ? -0.25 : -0.22,
          yanchor: "top",
          font: { size: profile.legendFontSize }
        },
        showlegend: hasLegend,
        uniformtext: { mode: "hide", minsize: 9 },
        xaxis: {
          type: "date",
          tickmode: "array",
          tickvals: ticks.vals,
          ticktext: ticks.text,
          tickangle: 0,
          title: { text: "Período", standoff: 10, font: { size: profile.titleFontSize } },
          tickfont: { size: profile.tickFontSize },
          showgrid: false,
          automargin: true,
          fixedrange: true
        },
        yaxis: {
          title: { text: "Millones de USD", standoff: profile.mobile ? 4 : 8, font: { size: profile.titleFontSize } },
          tickfont: { size: profile.tickFontSize },
          gridcolor: "#E5E7EB",
          zerolinecolor: "#CBD5E1",
          rangemode: "tozero",
          automargin: true,
          fixedrange: true,
          tickformat: ",.1f"
        }
      };
    }

    function prepareImportChart(chart, months) {
      const profile = responsive.prepareScrollablePlot(chart, months.length, {
        mobilePixelsPerPeriod: 50,
        tabletPixelsPerPeriod: 52,
        scrollThreshold: 6,
        mobileHeight: 390,
        tabletHeight: 420,
        desktopHeight: 470
      });
      return profile;
    }

    function labelHeadroom() {
      if (responsive.isMobile()) return 1.22;
      if (responsive.isTablet()) return 1.19;
      return 1.17;
    }

    function viewportPeriodRange(chart, count) {
      const wrapper = chart ? chart.closest(".rigi-plot-scroll") : null;
      const total = Math.max(0, Number(count) || 0);
      if (!chart || !wrapper || total === 0) return { start: 0, end: total };

      const overflowing = wrapper.scrollWidth > wrapper.clientWidth + 2;
      if (!responsive.isMobile() || !overflowing) return { start: 0, end: total };

      const leftMargin = Number(chart.layout && chart.layout.margin && chart.layout.margin.l) || 54;
      const rightMargin = Number(chart.layout && chart.layout.margin && chart.layout.margin.r) || 12;
      const chartWidth = Math.max(chart.offsetWidth || wrapper.scrollWidth, leftMargin + rightMargin + 1);
      const plotWidth = Math.max(1, chartWidth - leftMargin - rightMargin);
      const visibleLeft = Math.max(0, wrapper.scrollLeft - leftMargin);
      const visibleRight = Math.min(plotWidth, wrapper.scrollLeft + wrapper.clientWidth - leftMargin);
      const start = Math.max(0, Math.floor((visibleLeft / plotWidth) * total));
      const end = Math.min(total, Math.max(start + 1, Math.ceil((visibleRight / plotWidth) * total)));
      return { start: start, end: end };
    }

    function viewportYRange(chart, totals) {
      const values = Array.isArray(totals) ? totals : [];
      const periodRange = viewportPeriodRange(chart, values.length);
      const visibleValues = values.slice(periodRange.start, periodRange.end);
      const maxVisible = Math.max.apply(null, visibleValues.concat([0]));
      return maxVisible > 0 ? [0, maxVisible * labelHeadroom()] : [0, 1];
    }

    function updateViewportScale(chart) {
      if (!chart || !Array.isArray(chart._rigiViewportTotals)) return;
      if (chart._rigiViewportScaleFrame) {
        window.cancelAnimationFrame(chart._rigiViewportScaleFrame);
      }
      chart._rigiViewportScaleFrame = window.requestAnimationFrame(function () {
        chart._rigiViewportScaleFrame = null;
        Plotly.relayout(chart, { "yaxis.range": viewportYRange(chart, chart._rigiViewportTotals) });
      });
    }

    function bindViewportScale(chart, totals) {
      if (!chart) return;
      chart._rigiViewportTotals = Array.isArray(totals) ? totals.slice() : [];
      const wrapper = chart.closest(".rigi-plot-scroll");
      if (!wrapper) return;

      if (chart._rigiViewportWrapper && chart._rigiViewportWrapper !== wrapper && chart._rigiViewportScrollHandler) {
        chart._rigiViewportWrapper.removeEventListener("scroll", chart._rigiViewportScrollHandler);
      }
      if (!chart._rigiViewportScrollHandler) {
        chart._rigiViewportScrollHandler = function () { updateViewportScale(chart); };
      }
      if (chart._rigiViewportWrapper !== wrapper) {
        wrapper.addEventListener("scroll", chart._rigiViewportScrollHandler, { passive: true });
        chart._rigiViewportWrapper = wrapper;
      }
      updateViewportScale(chart);
    }

    function renderEmpty(chart, message) {
      const profile = prepareImportChart(chart, []);
      const layout = {
        autosize: true,
        height: profile.height,
        dragmode: false,
        margin: { l: 20, r: 20, t: 20, b: 20 },
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(0,0,0,0)",
        xaxis: { visible: false },
        yaxis: { visible: false },
        annotations: [{
          text: message,
          x: 0.5,
          y: 0.5,
          xref: "paper",
          yref: "paper",
          showarrow: false,
          font: { color: "#64748B", size: 15 }
        }]
      };
      Promise.resolve(Plotly.react(chart, [], layout, plotConfig))
        .then(function () { bindViewportScale(chart, []); });
    }

    function aggregate(rows, dimension) {
      const map = new Map();
      rows.forEach((d) => {
        const group = dimension === "sector" ? d.sector : d.project;
        const key = group + "|||" + d.month;
        map.set(key, (map.get(key) || 0) + d.value);
      });
      return map;
    }

    function cumulativeSeries(groups, byGroupMonth) {
      const out = {};
      groups.forEach((group) => {
        let running = 0;
        out[group] = {};
        allMonths.forEach((month) => {
          running += byGroupMonth.get(group + "|||" + month) || 0;
          out[group][month] = running;
        });
      });
      return out;
    }

    function totalsFromBars(traces) {
      if (!traces.length) return [];
      const count = (traces[0].y || []).length;
      return Array.from({ length: count }, (_, i) =>
        traces.reduce((sum, trace) => sum + Number((trace.y || [])[i] || 0), 0)
      );
    }

    function totalTextTrace(months, totals, name, profile) {
      return {
        type: "scatter",
        mode: "text",
        name: name,
        showlegend: false,
        x: months.map(monthToDate),
        y: totals,
        text: totals.map(barLabel),
        textposition: "top center",
        textfont: { color: "#334155", size: profile ? profile.textFontSize : 11 },
        cliponaxis: false,
        hoverinfo: "skip"
      };
    }

    function projectSector(project) {
      const row = rawData.find((d) => d.project === project);
      return row ? row.sector : "No informado";
    }

    function escapeHtml(value) {
      return String(value == null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    }

    function legendLabel(value) {
      const words = String(value).split(/\s+/);
      const lines = [];
      let line = "";
      words.forEach((word) => {
        if (line && (line + " " + word).length > 24) {
          lines.push(line);
          line = word;
        } else {
          line = line ? line + " " + word : word;
        }
      });
      if (line) lines.push(line);
      return lines.slice(0, 2).join("<br>");
    }

    // ---------------------------------------------------------------------
    // Sector
    // ---------------------------------------------------------------------
    function selectedSectorFilters() {
      return selectedValues(controls.sector.inputs);
    }

    function renderSectorCharts() {
      const selectedSectors = selectedSectorFilters();
      const months = visibleMonths(controls.sector.start.value, controls.sector.end.value);

      if (!selectedSectors.length || !months.length) {
        renderEmpty(charts.sectorMonthly, "Seleccioná al menos un sector y un período válido.");
        renderEmpty(charts.sectorCumulative, "Seleccioná al menos un sector y un período válido.");
        return;
      }

      const rows = rawData.filter((d) => selectedSectors.includes(d.sector));
      const bySectorMonth = aggregate(rows, "sector");
      const monthlyProfile = prepareImportChart(charts.sectorMonthly, months);
      const cumulativeProfile = prepareImportChart(charts.sectorCumulative, months);

      const monthlyTraces = selectedSectors.map((sector) => {
        const y = months.map((month) => bySectorMonth.get(sector + "|||" + month) || 0);
        return {
          type: "bar",
          name: legendLabel(sector),
          legendgroup: sector,
          meta: { sector: sector },
          x: months.map(monthToDate),
          y: y,
          marker: { color: sectorColors[sector] || "#64748B" },
          customdata: months.map((month, i) => ({ month: month, value: y[i] })),
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });

      const monthlyTotals = totalsFromBars(monthlyTraces);
      monthlyTraces.forEach((trace) => {
        trace.customdata = trace.customdata.map((d, i) => {
          const share = monthlyTotals[i] > 0 ? d.value / monthlyTotals[i] : 0;
          return (
            "<b>" + trace.meta.sector + "</b><br>" +
            "Período: " + formatMonth(d.month) + "<br>" +
            "Importaciones: US$ " + formatter.format(d.value) + " millones<br>" +
            "Participación: " + pctFormatter.format(share)
          );
        });
      });
      monthlyTraces.push(totalTextTrace(months, monthlyTotals, "Total", monthlyProfile));

      const maxMonthly = Math.max.apply(null, monthlyTotals.concat([0]));
      const monthlyBaseLayout = buildBaseLayout(months, { profile: monthlyProfile });
      const monthlyLayout = Object.assign({}, monthlyBaseLayout, {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, monthlyBaseLayout.yaxis, {
          range: maxMonthly > 0 ? [0, maxMonthly * labelHeadroom()] : [0, 1]
        })
      });
      Promise.resolve(Plotly.react(charts.sectorMonthly, monthlyTraces, monthlyLayout, plotConfig))
        .then(function () { bindViewportScale(charts.sectorMonthly, monthlyTotals); });

      const cumulative = cumulativeSeries(selectedSectors, bySectorMonth);
      const cumulativeTraces = selectedSectors.map((sector) => {
        const y = months.map((month) => cumulative[sector][month] || 0);
        return {
          type: "bar",
          name: legendLabel(sector),
          legendgroup: sector,
          meta: { sector: sector },
          x: months.map(monthToDate),
          y: y,
          marker: { color: sectorColors[sector] || "#64748B" },
          customdata: months.map((month, i) => ({ month: month, value: y[i] })),
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });
      const cumulativeTotals = totalsFromBars(cumulativeTraces);
      cumulativeTraces.forEach((trace) => {
        trace.customdata = trace.customdata.map((d, i) => {
          const share = cumulativeTotals[i] > 0 ? d.value / cumulativeTotals[i] : 0;
          return (
            "<b>" + trace.meta.sector + "</b><br>" +
            "Período: " + formatMonth(d.month) + "<br>" +
            "Importaciones acumuladas: US$ " + formatter.format(d.value) + " millones<br>" +
            "Participación: " + pctFormatter.format(share)
          );
        });
      });
      cumulativeTraces.push(totalTextTrace(months, cumulativeTotals, "Total acumulado", cumulativeProfile));

      const maxCumulative = Math.max.apply(null, cumulativeTotals.concat([0]));
      const cumulativeBaseLayout = buildBaseLayout(months, { profile: cumulativeProfile });
      const cumulativeLayout = Object.assign({}, cumulativeBaseLayout, {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, cumulativeBaseLayout.yaxis, {
          range: maxCumulative > 0 ? [0, maxCumulative * labelHeadroom()] : [0, 1]
        })
      });
      Promise.resolve(Plotly.react(charts.sectorCumulative, cumulativeTraces, cumulativeLayout, plotConfig))
        .then(function () { bindViewportScale(charts.sectorCumulative, cumulativeTotals); });

      bindSectorLegendSync();
    }

    function syncSectorBarChart(chart, totalName, cumulative) {
      const syncing = cumulative ? syncingSectorCumulative : syncingSectorMonthly;
      if (syncing || !chart.data || chart.data.length === 0) return;

      const totalIndex = chart.data.findIndex((trace) => trace.name === totalName && trace.type === "scatter");
      if (totalIndex < 0) return;

      const xValues = Array.from(chart.data[totalIndex].x || []);
      const visibleBars = chart.data.filter((trace) => trace.type === "bar" && traceIsVisible(trace));
      const totals = totalsFromBars(visibleBars);
      if (cumulative) syncingSectorCumulative = true;
      else syncingSectorMonthly = true;

      const updates = chart.data
        .map((trace, index) => ({ trace, index }))
        .filter(({ trace }) => trace.type === "bar")
        .map(({ trace, index }) => {
          const hover = xValues.map((x, i) => {
            const value = Number((trace.y || [])[i] || 0);
            const total = totals[i] || 0;
            const share = total > 0 ? value / total : 0;
            return (
              "<b>" + (trace.meta && trace.meta.sector ? trace.meta.sector : trace.name) + "</b><br>" +
              "Período: " + formatMonth(dateToMonth(x)) + "<br>" +
              (cumulative ? "Importaciones acumuladas: " : "Importaciones: ") +
              "US$ " + formatter.format(value) + " millones<br>" +
              "Participación: " + pctFormatter.format(share)
            );
          });
          return Plotly.restyle(chart, { customdata: [hover] }, [index]);
        });

      Promise.all(updates.concat([
        Plotly.restyle(chart, { y: [totals], text: [totals.map(barLabel)] }, [totalIndex]),
        Plotly.relayout(chart, { "yaxis.range": viewportYRange(chart, totals) })
      ])).then(() => {
        bindViewportScale(chart, totals);
      }).finally(() => {
        if (cumulative) syncingSectorCumulative = false;
        else syncingSectorMonthly = false;
      });
    }

    function bindSectorLegendSync() {
      if (charts.sectorMonthly.dataset.legendSyncBound !== "true") {
        charts.sectorMonthly.dataset.legendSyncBound = "true";
        charts.sectorMonthly.on("plotly_restyle", () => {
          if (!syncingSectorMonthly) {
            window.requestAnimationFrame(() => syncSectorBarChart(charts.sectorMonthly, "Total", false));
          }
        });
      }

      if (charts.sectorCumulative.dataset.legendSyncBound !== "true") {
        charts.sectorCumulative.dataset.legendSyncBound = "true";
        charts.sectorCumulative.on("plotly_restyle", () => {
          if (!syncingSectorCumulative) {
            window.requestAnimationFrame(() => syncSectorBarChart(charts.sectorCumulative, "Total acumulado", true));
          }
        });
      }
    }

    function refreshSectorControls() {
      updateMasterCheckbox(controls.sector.all, controls.sector.inputs);
      updateSummary(controls.sector.summary, controls.sector.inputs, "Todos los sectores");
      renderSectorCharts();
    }

    // ---------------------------------------------------------------------
    // Proyecto
    // ---------------------------------------------------------------------
    function projectSectorFilters() {
      return selectedValues(controls.project.sectorInputs);
    }

    function compatibleProjectInputs() {
      const selectedSectors = projectSectorFilters();
      return controls.project.inputs.filter((input) => selectedSectors.includes(projectSector(input.value)));
    }

    function selectedProjectInputs() {
      return controls.project.inputs.filter((input) => !input.disabled && input.checked);
    }

    function selectedProjects() {
      return selectedProjectInputs().map((input) => input.value);
    }

    function normalizeProjectSearch(value) {
      return String(value || "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLocaleLowerCase("es");
    }

    function filterProjectOptions() {
      const query = normalizeProjectSearch(controls.project.search.value.trim());
      let visibleCount = 0;
      controls.project.inputs.forEach((input) => {
        const wrapper = input.closest(".impo-project-option");
        if (!wrapper) return;
        const sectorVisible = wrapper.dataset.sectorVisible !== "false";
        const matches = !query || normalizeProjectSearch(input.value).includes(query);
        wrapper.hidden = !sectorVisible || !matches;
        if (!wrapper.hidden) visibleCount += 1;
      });
      controls.project.empty.hidden = visibleCount > 0;
    }

    function hideProjectCard() {
      projectCardOpen = false;
      controls.project.card.hidden = true;
      controls.project.card.innerHTML = "";
      controls.project.cardToggle.textContent = "Ver ficha resumida";
      controls.project.cardToggle.setAttribute("aria-expanded", "false");
    }

    function showProjectInfo(project) {
      const meta = projectMetadata.get(project) || {
        project: project,
        estado: "No informado",
        peelp: false,
        titular: "No informado",
        empresa: "No informado",
        sector: projectSector(project),
        provincia: "No informado",
        adhesion: "No informado"
      };

      const companyLine = meta.empresa && meta.empresa !== "No informado" && meta.empresa !== meta.titular
        ? '<p class="impo-project-mini-card__company"><strong>Empresa:</strong> ' + escapeHtml(meta.empresa) + "</p>"
        : "";

      controls.project.card.innerHTML =
        '<article class="impo-project-mini-card">' +
          '<div class="impo-project-mini-card__badges">' +
            '<span class="rigi-badge rigi-badge--approved">' + escapeHtml(meta.estado) + "</span>" +
            (meta.peelp ? '<span class="rigi-badge rigi-badge--peelp">PEELP</span>' : "") +
          "</div>" +
          '<h4 class="impo-project-mini-card__title">' + escapeHtml(project) + "</h4>" +
          '<p class="impo-project-mini-card__holder">' + escapeHtml(meta.titular) + "</p>" +
          companyLine +
          '<dl class="impo-project-mini-card__grid">' +
            '<div><dt>Sector</dt><dd>' + escapeHtml(meta.sector) + "</dd></div>" +
            '<div><dt>Provincia</dt><dd>' + escapeHtml(meta.provincia) + "</dd></div>" +
            '<div><dt>Adhesión</dt><dd>' + escapeHtml(meta.adhesion) + "</dd></div>" +
          "</dl>" +
        "</article>";
      controls.project.card.hidden = false;
      projectCardOpen = true;
      controls.project.cardToggle.textContent = "Ocultar ficha resumida";
      controls.project.cardToggle.setAttribute("aria-expanded", "true");
    }

    function updateProjectCardControls() {
      const selected = selectedProjects();
      hideProjectCard();

      if (selected.length === 1) {
        controls.project.cardToggle.disabled = false;
        controls.project.cardHelp.textContent = "Podés consultar la ficha resumida del proyecto seleccionado.";
      } else {
        controls.project.cardToggle.disabled = true;
        controls.project.cardHelp.textContent = selected.length === 0
          ? "Seleccioná un proyecto para habilitar la ficha resumida."
          : "Para consultar la ficha resumida, dejá seleccionado un solo proyecto.";
      }
    }

    function updateProjectStatus() {
      const compatible = compatibleProjectInputs();
      const selected = selectedProjectInputs();
      if (compatible.length > 0 && selected.length === compatible.length) {
        controls.project.summary.textContent = "Todos los proyectos";
        controls.project.status.textContent = compatible.length + " proyectos seleccionados (todos los disponibles)";
      } else if (selected.length === 0) {
        controls.project.summary.textContent = "Ningún proyecto seleccionado";
        controls.project.status.textContent = "0 de " + compatible.length + " proyectos seleccionados";
      } else if (selected.length === 1) {
        controls.project.summary.textContent = "1 proyecto seleccionado";
        controls.project.status.textContent = "1 de " + compatible.length + " proyectos seleccionados";
      } else {
        controls.project.summary.textContent = selected.length + " proyectos seleccionados";
        controls.project.status.textContent = selected.length + " de " + compatible.length + " proyectos seleccionados";
      }
    }

    function refreshProjectAvailability(options) {
      const opts = options || {};
      const selectedSectors = projectSectorFilters();
      const compatible = new Set(
        rawData.filter((d) => selectedSectors.includes(d.sector)).map((d) => d.project)
      );

      controls.project.inputs.forEach((input) => {
        const wrapper = input.closest(".impo-project-option");
        const allowed = compatible.has(input.value);
        input.disabled = !allowed;
        if (wrapper) wrapper.dataset.sectorVisible = allowed ? "true" : "false";
        if (!allowed) input.checked = false;
      });

      const visible = compatibleProjectInputs();
      const selected = selectedProjectInputs();
      if (opts.selectAll || (visible.length > 0 && selected.length === 0 && opts.ensureSelection !== false)) {
        visible.forEach((input) => { input.checked = true; });
      }

      filterProjectOptions();
      updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
      updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
      updateProjectStatus();
      updateProjectCardControls();
    }

    function renderProjectCharts() {
      const projects = selectedProjects();
      const months = visibleMonths(controls.project.start.value, controls.project.end.value);
      const sectors = projectSectorFilters();

      if (!projects.length || !months.length) {
        renderEmpty(charts.projectMonthly, "Seleccioná al menos un proyecto y un período válido.");
        renderEmpty(charts.projectCumulative, "Seleccioná al menos un proyecto y un período válido.");
        return;
      }

      const rows = rawData.filter((d) => projects.includes(d.project) && sectors.includes(d.sector));
      const byProjectMonth = aggregate(rows, "project");
      const monthlyProfile = prepareImportChart(charts.projectMonthly, months);
      const cumulativeProfile = prepareImportChart(charts.projectCumulative, months);

      const monthlyBars = projects.map((project) => {
        const y = months.map((month) => byProjectMonth.get(project + "|||" + month) || 0);
        const sector = projectSector(project);
        return {
          type: "bar",
          name: project,
          showlegend: false,
          x: months.map(monthToDate),
          y: y,
          marker: { color: projectColors[project] || "#64748B" },
          customdata: months.map((month, i) =>
            "<b>" + project + "</b><br>" +
            "Sector: " + sector + "<br>" +
            "Período: " + formatMonth(month) + "<br>" +
            "Importaciones: US$ " + formatter.format(y[i]) + " millones"
          ),
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });
      const monthlyTotals = totalsFromBars(monthlyBars);
      const monthlyTraces = monthlyBars.concat([totalTextTrace(months, monthlyTotals, "Total", monthlyProfile)]);
      const maxMonthly = Math.max.apply(null, monthlyTotals.concat([0]));
      const monthlyBaseLayout = buildBaseLayout(months, { showLegend: false, profile: monthlyProfile });
      const monthlyLayout = Object.assign({}, monthlyBaseLayout, {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, monthlyBaseLayout.yaxis, {
          range: maxMonthly > 0 ? [0, maxMonthly * labelHeadroom()] : [0, 1]
        })
      });
      Promise.resolve(Plotly.react(charts.projectMonthly, monthlyTraces, monthlyLayout, plotConfig))
        .then(function () { bindViewportScale(charts.projectMonthly, monthlyTotals); });

      const cumulative = cumulativeSeries(projects, byProjectMonth);
      const cumulativeBars = projects.map((project) => {
        const y = months.map((month) => cumulative[project][month] || 0);
        const sector = projectSector(project);
        return {
          type: "bar",
          name: project,
          showlegend: false,
          x: months.map(monthToDate),
          y: y,
          marker: { color: projectColors[project] || "#64748B" },
          customdata: months.map((month, i) =>
            "<b>" + project + "</b><br>" +
            "Sector: " + sector + "<br>" +
            "Período: " + formatMonth(month) + "<br>" +
            "Importaciones acumuladas: US$ " + formatter.format(y[i]) + " millones"
          ),
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });
      const cumulativeTotals = totalsFromBars(cumulativeBars);
      const cumulativeTraces = cumulativeBars.concat([totalTextTrace(months, cumulativeTotals, "Total acumulado", cumulativeProfile)]);
      const maxCumulative = Math.max.apply(null, cumulativeTotals.concat([0]));
      const cumulativeBaseLayout = buildBaseLayout(months, { showLegend: false, profile: cumulativeProfile });
      const cumulativeLayout = Object.assign({}, cumulativeBaseLayout, {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, cumulativeBaseLayout.yaxis, {
          range: maxCumulative > 0 ? [0, maxCumulative * labelHeadroom()] : [0, 1]
        })
      });
      Promise.resolve(Plotly.react(charts.projectCumulative, cumulativeTraces, cumulativeLayout, plotConfig))
        .then(function () { bindViewportScale(charts.projectCumulative, cumulativeTotals); });
    }

    function refreshProjectControls() {
      updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
      updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
    }

    function closeCompactMenu(input) {
      if (!responsive.isMobile() || !input) return;
      const details = input.closest("details");
      if (details) details.open = false;
    }

    // ---------------------------------------------------------------------
    // Eventos: sector
    // ---------------------------------------------------------------------
    controls.sector.start.addEventListener("change", function () {
      if (controls.sector.start.value > controls.sector.end.value) {
        controls.sector.end.value = controls.sector.start.value;
      }
      renderSectorCharts();
    });

    controls.sector.end.addEventListener("change", function () {
      if (controls.sector.end.value < controls.sector.start.value) {
        controls.sector.start.value = controls.sector.end.value;
      }
      renderSectorCharts();
    });

    controls.sector.all.addEventListener("change", function () {
      controls.sector.inputs.forEach((input) => { input.checked = controls.sector.all.checked; });
      refreshSectorControls();
      closeCompactMenu(controls.sector.all);
    });

    controls.sector.inputs.forEach((input) => {
      input.addEventListener("change", function () {
        refreshSectorControls();
        closeCompactMenu(input);
      });
    });

    controls.sector.reset.addEventListener("click", function () {
      controls.sector.start.value = minMonth;
      controls.sector.end.value = maxMonth;
      controls.sector.inputs.forEach((input) => { input.checked = true; });
      refreshSectorControls();
    });

    // ---------------------------------------------------------------------
    // Eventos: proyecto
    // ---------------------------------------------------------------------
    controls.project.start.addEventListener("change", function () {
      if (controls.project.start.value > controls.project.end.value) {
        controls.project.end.value = controls.project.start.value;
      }
      renderProjectCharts();
    });

    controls.project.end.addEventListener("change", function () {
      if (controls.project.end.value < controls.project.start.value) {
        controls.project.start.value = controls.project.end.value;
      }
      renderProjectCharts();
    });

    controls.project.sectorAll.addEventListener("change", function () {
      controls.project.sectorInputs.forEach((input) => { input.checked = controls.project.sectorAll.checked; });
      refreshProjectAvailability({ selectAll: controls.project.sectorAll.checked });
      renderProjectCharts();
      closeCompactMenu(controls.project.sectorAll);
    });

    controls.project.sectorInputs.forEach((input) => {
      input.addEventListener("change", function () {
        refreshProjectAvailability({ ensureSelection: true });
        renderProjectCharts();
        closeCompactMenu(input);
      });
    });

    controls.project.inputs.forEach((input) => {
      input.addEventListener("change", function () {
        if (input.disabled) return;
        updateProjectStatus();
        updateProjectCardControls();
        renderProjectCharts();
      });
    });

    controls.project.search.addEventListener("input", filterProjectOptions);

    controls.project.selectAll.addEventListener("click", function () {
      compatibleProjectInputs().forEach((input) => { input.checked = true; });
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
    });

    controls.project.clear.addEventListener("click", function () {
      compatibleProjectInputs().forEach((input) => { input.checked = false; });
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
    });

    controls.project.cardToggle.addEventListener("click", function () {
      const selected = selectedProjects();
      if (selected.length !== 1) return;
      if (projectCardOpen) {
        hideProjectCard();
      } else {
        showProjectInfo(selected[0]);
      }
    });

    controls.project.reset.addEventListener("click", function () {
      controls.project.start.value = minMonth;
      controls.project.end.value = maxMonth;
      controls.project.sectorInputs.forEach((input) => { input.checked = true; });
      controls.project.search.value = "";
      controls.project.inputs.forEach((input) => {
        input.disabled = false;
        input.checked = true;
        const wrapper = input.closest(".impo-project-option");
        if (wrapper) wrapper.dataset.sectorVisible = "true";
      });
      updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
      updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
    });

    document.addEventListener("click", function (event) {
      root.querySelectorAll(".impo-multiselect[open]").forEach((details) => {
        if (!details.contains(event.target)) details.removeAttribute("open");
      });
      if (controls.project.details.open && !controls.project.details.contains(event.target)) {
        controls.project.details.removeAttribute("open");
      }
    });

    responsive.subscribe("importaciones", function () {
      renderSectorCharts();
      renderProjectCharts();
    });

    // ---------------------------------------------------------------------
    // Estado inicial
    // ---------------------------------------------------------------------
    updateMasterCheckbox(controls.sector.all, controls.sector.inputs);
    updateSummary(controls.sector.summary, controls.sector.inputs, "Todos los sectores");
    updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
    updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
    refreshProjectAvailability({ selectAll: true });
    renderSectorCharts();
    renderProjectCharts();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initImportaciones);
  } else {
    initImportaciones();
  }
})();
