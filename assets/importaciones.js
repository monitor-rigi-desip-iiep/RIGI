(function () {
  "use strict";

  function initImportaciones() {
    const root = document.getElementById("importaciones-module");
    if (!root || root.dataset.initialized === "true") return;

    if (typeof window.Plotly === "undefined") {
      window.setTimeout(initImportaciones, 100);
      return;
    }

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
        chips: Array.from(root.querySelectorAll(".impo-project-chip")),
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


    function viewportProfile() {
      const width = window.innerWidth || document.documentElement.clientWidth || 1440;
      return {
        mobile: width <= 640,
        tablet: width > 640 && width <= 900
      };
    }

    function ensureChartScroller(chart) {
      let wrapper = chart.parentElement && chart.parentElement.classList.contains("rigi-chart-scroll")
        ? chart.parentElement
        : null;
      let hint = null;

      if (!wrapper) {
        wrapper = document.createElement("div");
        wrapper.className = "rigi-chart-scroll";
        chart.parentNode.insertBefore(wrapper, chart);
        wrapper.appendChild(chart);

        hint = document.createElement("p");
        hint.className = "rigi-chart-scroll-hint";
        hint.textContent = "Deslizá el gráfico horizontalmente para ver más períodos →";
        wrapper.insertAdjacentElement("afterend", hint);
      } else {
        hint = wrapper.nextElementSibling && wrapper.nextElementSibling.classList.contains("rigi-chart-scroll-hint")
          ? wrapper.nextElementSibling
          : null;
      }
      return { wrapper, hint };
    }

    function prepareChartWidth(chart, periodCount) {
      const parts = ensureChartScroller(chart);
      const profile = viewportProfile();
      const available = Math.max(parts.wrapper.clientWidth || chart.parentElement.clientWidth || 320, 280);
      let target = available;

      if (profile.mobile) target = Math.max(available, periodCount * 62 + 88);
      else if (profile.tablet) target = Math.max(available, periodCount * 42 + 80);

      const scrolling = target > available + 8;
      chart.style.width = scrolling ? Math.ceil(target) + "px" : "100%";
      chart.style.minWidth = scrolling ? Math.ceil(target) + "px" : "0";
      if (parts.hint) parts.hint.classList.toggle("is-visible", scrolling);
      return { profile, scrolling };
    }

    function responsiveLayoutParts(showLegend, bottomMargin) {
      const profile = viewportProfile();
      const mobile = profile.mobile;
      const tablet = profile.tablet;
      const legendBottom = showLegend ? (mobile ? 96 : tablet ? 100 : (bottomMargin || 105)) : (mobile ? 64 : tablet ? 70 : (bottomMargin || 76));
      return {
        margin: mobile
          ? { l: 52, r: 12, t: 30, b: legendBottom }
          : tablet
            ? { l: 62, r: 18, t: 32, b: legendBottom }
            : { l: 72, r: 24, t: 36, b: bottomMargin || 105 },
        fontSize: mobile ? 10.5 : tablet ? 11 : 12,
        tickSize: mobile ? 9.5 : tablet ? 10 : 11,
        titleSize: mobile ? 10.5 : tablet ? 11 : 12,
        labelSize: mobile ? 9.5 : 11,
        height: mobile ? 390 : tablet ? 440 : 470,
        legend: {
          orientation: "h",
          x: mobile ? 0 : 0.5,
          xanchor: mobile ? "left" : "center",
          y: mobile ? -0.22 : -0.22,
          yanchor: "top",
          font: { size: mobile ? 9.5 : tablet ? 10 : 11 }
        }
      };
    }

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
      const profile = viewportProfile();
      if (profile.mobile) {
        if (count <= 24) return 1;
        if (count <= 48) return 2;
        return 3;
      }
      if (profile.tablet) {
        if (count <= 18) return 1;
        if (count <= 36) return 2;
      }
      if (count <= 12) return 1;
      if (count <= 24) return 2;
      if (count <= 36) return 3;
      if (count <= 60) return 6;
      return 12;
    }

    function buildTicks(months) {
      const step = tickStep(months.length);
      const selected = months.filter((month, i) => i % step === 0 || i === months.length - 1);
      return {
        vals: selected.map(monthToDate),
        text: selected.map(formatMonth)
      };
    }

    function buildBaseLayout(months, options) {
      const opts = options || {};
      const ticks = buildTicks(months);
      const responsive = responsiveLayoutParts(opts.showLegend !== false, opts.bottomMargin || 105);
      return {
        autosize: true,
        height: responsive.height,
        margin: responsive.margin,
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(0,0,0,0)",
        font: {
          family: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
          color: "#334155",
          size: responsive.fontSize
        },
        hoverlabel: {
          bgcolor: "#FFFFFF",
          bordercolor: "#CBD5E1",
          font: { color: "#0F172A" }
        },
        legend: responsive.legend,
        showlegend: opts.showLegend !== false,
        xaxis: {
          type: "date",
          tickmode: "array",
          tickvals: ticks.vals,
          ticktext: ticks.text,
          title: { text: "Período", standoff: 10, font: { size: responsive.titleSize } },
          showgrid: false,
          automargin: true,
          fixedrange: true,
          tickfont: { size: responsive.tickSize }
        },
        yaxis: {
          title: { text: "Millones de USD", standoff: 8, font: { size: responsive.titleSize } },
          gridcolor: "#E5E7EB",
          zerolinecolor: "#CBD5E1",
          rangemode: "tozero",
          automargin: true,
          fixedrange: true,
          tickformat: ",.1f",
          tickfont: { size: responsive.tickSize }
        }
      };
    }

    function renderEmpty(chart, message) {
      const layout = {
        autosize: true,
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
      Plotly.react(chart, [], layout, { displayModeBar: false, responsive: true });
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

    function totalTextTrace(months, totals, name) {
      return {
        type: "scatter",
        mode: "text",
        name: name,
        showlegend: false,
        x: months.map(monthToDate),
        y: totals,
        text: totals.map(barLabel),
        textposition: "top center",
        textfont: { color: "#334155", size: responsiveLayoutParts(false, 76).labelSize },
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

    // ---------------------------------------------------------------------
    // Sector
    // ---------------------------------------------------------------------
    function selectedSectorFilters() {
      return selectedValues(controls.sector.inputs);
    }

    function renderSectorCharts() {
      const selectedSectors = selectedSectorFilters();
      const months = visibleMonths(controls.sector.start.value, controls.sector.end.value);
      prepareChartWidth(charts.sectorMonthly, months.length);
      prepareChartWidth(charts.sectorCumulative, months.length);

      if (!selectedSectors.length || !months.length) {
        renderEmpty(charts.sectorMonthly, "Seleccioná al menos un sector y un período válido.");
        renderEmpty(charts.sectorCumulative, "Seleccioná al menos un sector y un período válido.");
        return;
      }

      const rows = rawData.filter((d) => selectedSectors.includes(d.sector));
      const bySectorMonth = aggregate(rows, "sector");

      const monthlyTraces = selectedSectors.map((sector) => {
        const y = months.map((month) => bySectorMonth.get(sector + "|||" + month) || 0);
        return {
          type: "bar",
          name: sector,
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
            "<b>" + trace.name + "</b><br>" +
            "Período: " + formatMonth(d.month) + "<br>" +
            "Importaciones: US$ " + formatter.format(d.value) + " millones<br>" +
            "Participación: " + pctFormatter.format(share)
          );
        });
      });
      monthlyTraces.push(totalTextTrace(months, monthlyTotals, "Total"));

      const maxMonthly = Math.max.apply(null, monthlyTotals.concat([0]));
      const monthlyLayout = Object.assign({}, buildBaseLayout(months), {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, buildBaseLayout(months).yaxis, {
          range: maxMonthly > 0 ? [0, maxMonthly * 1.17] : [0, 1]
        })
      });
      Plotly.react(charts.sectorMonthly, monthlyTraces, monthlyLayout, {
        displayModeBar: false,
        responsive: true
      });

      const cumulative = cumulativeSeries(selectedSectors, bySectorMonth);
      const cumulativeTraces = selectedSectors.map((sector) => {
        const y = months.map((month) => cumulative[sector][month] || 0);
        return {
          type: "bar",
          name: sector,
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
            "<b>" + trace.name + "</b><br>" +
            "Período: " + formatMonth(d.month) + "<br>" +
            "Importaciones acumuladas: US$ " + formatter.format(d.value) + " millones<br>" +
            "Participación: " + pctFormatter.format(share)
          );
        });
      });
      cumulativeTraces.push(totalTextTrace(months, cumulativeTotals, "Total acumulado"));

      const maxCumulative = Math.max.apply(null, cumulativeTotals.concat([0]));
      const cumulativeLayout = Object.assign({}, buildBaseLayout(months), {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, buildBaseLayout(months).yaxis, {
          range: maxCumulative > 0 ? [0, maxCumulative * 1.17] : [0, 1]
        })
      });
      Plotly.react(charts.sectorCumulative, cumulativeTraces, cumulativeLayout, {
        displayModeBar: false,
        responsive: true
      });

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
      const maxTotal = Math.max.apply(null, totals.concat([0]));

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
              "<b>" + trace.name + "</b><br>" +
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
        Plotly.relayout(chart, { "yaxis.range": maxTotal > 0 ? [0, maxTotal * 1.17] : [0, 1] })
      ])).finally(() => {
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

    function compatibleProjectChips() {
      const selectedSectors = projectSectorFilters();
      return controls.project.chips.filter((chip) => selectedSectors.includes(projectSector(chip.dataset.project)));
    }

    function selectedProjectChips() {
      return controls.project.chips.filter(
        (chip) => !chip.hidden && chip.getAttribute("aria-pressed") === "true"
      );
    }

    function selectedProjects() {
      return selectedProjectChips().map((chip) => chip.dataset.project);
    }

    function setChipSelected(chip, selected) {
      chip.setAttribute("aria-pressed", selected ? "true" : "false");
      chip.classList.toggle("is-selected", selected);
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
      const compatible = compatibleProjectChips();
      const selected = selectedProjectChips();
      controls.project.status.textContent = selected.length === compatible.length && compatible.length > 0
        ? compatible.length + " proyectos seleccionados (todos los visibles)"
        : selected.length + " de " + compatible.length + " proyectos seleccionados";
    }

    function refreshProjectAvailability(options) {
      const opts = options || {};
      const selectedSectors = projectSectorFilters();
      const compatible = new Set(
        rawData.filter((d) => selectedSectors.includes(d.sector)).map((d) => d.project)
      );

      controls.project.chips.forEach((chip) => {
        const allowed = compatible.has(chip.dataset.project);
        chip.hidden = !allowed;
        chip.disabled = !allowed;
        if (!allowed) setChipSelected(chip, false);
      });

      const visible = compatibleProjectChips();
      const selected = selectedProjectChips();
      if (opts.selectAll || (visible.length > 0 && selected.length === 0 && opts.ensureSelection !== false)) {
        visible.forEach((chip) => setChipSelected(chip, true));
      }

      updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
      updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
      updateProjectStatus();
      updateProjectCardControls();
    }

    function renderProjectCharts() {
      const projects = selectedProjects();
      const months = visibleMonths(controls.project.start.value, controls.project.end.value);
      const sectors = projectSectorFilters();
      prepareChartWidth(charts.projectMonthly, months.length);
      prepareChartWidth(charts.projectCumulative, months.length);

      if (!projects.length || !months.length) {
        renderEmpty(charts.projectMonthly, "Seleccioná al menos un proyecto y un período válido.");
        renderEmpty(charts.projectCumulative, "Seleccioná al menos un proyecto y un período válido.");
        return;
      }

      const rows = rawData.filter((d) => projects.includes(d.project) && sectors.includes(d.sector));
      const byProjectMonth = aggregate(rows, "project");

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
      const monthlyTraces = monthlyBars.concat([totalTextTrace(months, monthlyTotals, "Total")]);
      const maxMonthly = Math.max.apply(null, monthlyTotals.concat([0]));
      const monthlyLayout = Object.assign({}, buildBaseLayout(months, { showLegend: false, bottomMargin: 76 }), {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, buildBaseLayout(months).yaxis, {
          range: maxMonthly > 0 ? [0, maxMonthly * 1.17] : [0, 1]
        })
      });
      Plotly.react(charts.projectMonthly, monthlyTraces, monthlyLayout, {
        displayModeBar: false,
        responsive: true
      });

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
      const cumulativeTraces = cumulativeBars.concat([totalTextTrace(months, cumulativeTotals, "Total acumulado")]);
      const maxCumulative = Math.max.apply(null, cumulativeTotals.concat([0]));
      const cumulativeLayout = Object.assign({}, buildBaseLayout(months, { showLegend: false, bottomMargin: 76 }), {
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, buildBaseLayout(months).yaxis, {
          range: maxCumulative > 0 ? [0, maxCumulative * 1.17] : [0, 1]
        })
      });
      Plotly.react(charts.projectCumulative, cumulativeTraces, cumulativeLayout, {
        displayModeBar: false,
        responsive: true
      });
    }

    function refreshProjectControls() {
      updateMasterCheckbox(controls.project.sectorAll, controls.project.sectorInputs);
      updateSummary(controls.project.sectorSummary, controls.project.sectorInputs, "Todos los sectores");
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
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
    });

    controls.sector.inputs.forEach((input) => {
      input.addEventListener("change", refreshSectorControls);
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
    });

    controls.project.sectorInputs.forEach((input) => {
      input.addEventListener("change", function () {
        refreshProjectAvailability({ ensureSelection: true });
        renderProjectCharts();
      });
    });

    controls.project.chips.forEach((chip) => {
      chip.addEventListener("click", function () {
        if (chip.disabled || chip.hidden) return;
        setChipSelected(chip, chip.getAttribute("aria-pressed") !== "true");
        updateProjectStatus();
        updateProjectCardControls();
        renderProjectCharts();
      });
    });

    controls.project.selectAll.addEventListener("click", function () {
      compatibleProjectChips().forEach((chip) => setChipSelected(chip, true));
      updateProjectStatus();
      updateProjectCardControls();
      renderProjectCharts();
    });

    controls.project.clear.addEventListener("click", function () {
      compatibleProjectChips().forEach((chip) => setChipSelected(chip, false));
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
      controls.project.chips.forEach((chip) => {
        chip.hidden = false;
        chip.disabled = false;
        setChipSelected(chip, true);
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
    });

    let responsiveResizeTimer = null;
    function applyResponsiveChartSizing() {
      const sectorMonths = visibleMonths(controls.sector.start.value, controls.sector.end.value);
      const projectMonths = visibleMonths(controls.project.start.value, controls.project.end.value);
      const specs = [
        [charts.sectorMonthly, sectorMonths, true, 105],
        [charts.sectorCumulative, sectorMonths, true, 105],
        [charts.projectMonthly, projectMonths, false, 76],
        [charts.projectCumulative, projectMonths, false, 76]
      ];

      specs.forEach(([chart, months, showLegend, bottomMargin]) => {
        if (!chart) return;
        prepareChartWidth(chart, months.length);
        if (!chart.layout) return;
        const responsive = responsiveLayoutParts(showLegend, bottomMargin);
        Plotly.relayout(chart, {
          "height": responsive.height,
          "margin.l": responsive.margin.l,
          "margin.r": responsive.margin.r,
          "margin.t": responsive.margin.t,
          "margin.b": responsive.margin.b,
          "font.size": responsive.fontSize,
          "legend.orientation": responsive.legend.orientation,
          "legend.x": responsive.legend.x,
          "legend.xanchor": responsive.legend.xanchor,
          "legend.y": responsive.legend.y,
          "legend.font.size": responsive.legend.font.size,
          "xaxis.tickfont.size": responsive.tickSize,
          "xaxis.title.font.size": responsive.titleSize,
          "yaxis.tickfont.size": responsive.tickSize,
          "yaxis.title.font.size": responsive.titleSize
        }).then(() => Plotly.Plots.resize(chart));
      });
    }

    window.addEventListener("resize", function () {
      window.clearTimeout(responsiveResizeTimer);
      responsiveResizeTimer = window.setTimeout(applyResponsiveChartSizing, 140);
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
