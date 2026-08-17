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
          initPlansInvestment();
        }, INIT_RETRY_DELAY_MS);
      }
      return;
    }

    root.dataset.initializationError = missing.join(", ");
    if (!initErrorReported) {
      initErrorReported = true;
      console.error(
        "[Monitor RIGI] No se pudo inicializar Planes de inversión. " +
        "Dependencias faltantes: " + missing.join(", ") + ". " +
        "Script responsive esperado: " + RESPONSIVE_SCRIPT_URL
      );
    }
  }

  function initPlansInvestment() {
    const root = document.getElementById("planes-inversion-module");
    if (!root || root.dataset.initialized === "true") return;

    const missing = missingDependencies();
    if (missing.length > 0) {
      retryInitialization(root, missing);
      return;
    }

    delete root.dataset.initializationError;
    root.dataset.initialized = "true";

    const dataNode = document.getElementById("planes-inversion-data");
    const colorNode = document.getElementById("planes-inversion-colors");
    const rawData = JSON.parse(dataNode.textContent || "[]").map((d) => ({
      anio: Number(d.anio),
      sector: String(d.sector),
      subsector: String(d.subsector),
      monto: Number(d.monto_mill_usd || 0)
    }));
    const sectorColors = JSON.parse(colorNode.textContent || "{}");
    const responsive = window.RigiResponsive;
    const plotConfig = responsive.getPlotlyInteractionConfig();

    const annualChart = document.getElementById("planes-annual-chart");
    const cumulativeChart = document.getElementById("planes-cumulative-chart");
    const yearStart = document.getElementById("planes-year-start");
    const yearEnd = document.getElementById("planes-year-end");
    const sectorAll = document.getElementById("plans-sector-all");
    const subsectorAll = document.getElementById("plans-subsector-all");
    const sectorSummary = document.getElementById("plans-sector-summary");
    const subsectorSummary = document.getElementById("plans-subsector-summary");
    const resetButton = document.getElementById("plans-reset");

    const sectorInputs = Array.from(root.querySelectorAll(".plans-sector-option"));
    const subsectorInputs = Array.from(root.querySelectorAll(".plans-subsector-option"));
    const observedYears = rawData.map((d) => d.anio);
    const minYear = Math.min.apply(null, observedYears);
    const maxYear = Math.max.apply(null, observedYears);
    const allYears = Array.from({ length: maxYear - minYear + 1 }, (_, i) => minYear + i);
    const availableYears = Array.from(new Set(observedYears)).sort((a, b) => a - b);
    const requestedStart = Number(root.dataset.defaultYearStart);
    const requestedEnd = Number(root.dataset.defaultYearEnd);
    const defaultStartYear = availableYears.includes(requestedStart) ? requestedStart : availableYears[0];
    const eligibleEndYears = availableYears.filter((year) => year >= defaultStartYear);
    const defaultEndYear = eligibleEndYears.includes(requestedEnd)
      ? requestedEnd
      : eligibleEndYears.reduce((closest, year) =>
          Math.abs(year - 2034) < Math.abs(closest - 2034) ? year : closest,
        eligibleEndYears[0]
      );
    const formatter = new Intl.NumberFormat("es-AR", { maximumFractionDigits: 1 });
    const pctFormatter = new Intl.NumberFormat("es-AR", { style: "percent", maximumFractionDigits: 1 });
    let syncingAnnualLegend = false;
    let syncingCumulativeLegend = false;

    function selectedValues(inputs) {
      return inputs.filter((input) => input.checked && !input.disabled).map((input) => input.value);
    }

    function compatibleSubsectors(selectedSectors) {
      return new Set(
        rawData
          .filter((d) => selectedSectors.includes(d.sector))
          .map((d) => d.subsector)
      );
    }

    function updateMasterCheckbox(master, inputs) {
      const active = inputs.filter((input) => !input.disabled);
      const checked = active.filter((input) => input.checked);
      master.checked = active.length > 0 && checked.length === active.length;
      master.indeterminate = checked.length > 0 && checked.length < active.length;
    }

    function updateSummary(summary, inputs, allLabel, selectedLabel) {
      const active = inputs.filter((input) => !input.disabled);
      const selected = active.filter((input) => input.checked);
      if (active.length > 0 && selected.length === active.length) {
        summary.textContent = allLabel;
      } else if (selected.length === 0) {
        summary.textContent = "Ninguno seleccionado";
      } else if (selected.length === 1) {
        summary.textContent = selected[0].value;
      } else {
        summary.textContent = selected.length + " " + selectedLabel;
      }
    }

    function refreshSubsectorAvailability(resetToAll) {
      const selectedSectors = selectedValues(sectorInputs);
      const valid = compatibleSubsectors(selectedSectors);

      subsectorInputs.forEach((input) => {
        const wrapper = input.closest(".plans-check-option");
        const isValid = valid.has(input.value);
        input.disabled = !isValid;
        if (wrapper) wrapper.hidden = !isValid;
        if (!isValid) input.checked = false;
        if (isValid && resetToAll) input.checked = true;
      });

      updateMasterCheckbox(subsectorAll, subsectorInputs);
      updateSummary(subsectorSummary, subsectorInputs, "Todos los subsectores", "seleccionados");
    }

    function aggregateAnnual(baseData) {
      const bySectorYear = new Map();
      const byYear = new Map();

      baseData.forEach((d) => {
        const key = d.sector + "|||" + d.anio;
        bySectorYear.set(key, (bySectorYear.get(key) || 0) + d.monto);
        byYear.set(d.anio, (byYear.get(d.anio) || 0) + d.monto);
      });

      return { bySectorYear, byYear };
    }

    function emptyAnnotation(message) {
      return [{
        text: message,
        xref: "paper",
        yref: "paper",
        x: 0.5,
        y: 0.5,
        showarrow: false,
        font: { color: "#64748B", size: 14 }
      }];
    }

    function labelHeadroom() {
      if (responsive.isMobile()) return 1.14;
      if (responsive.isTablet()) return 1.12;
      return 1.10;
    }

    function totalLabels(values) {
      return values.map((value) => value > 0 ? formatter.format(value) : "");
    }

    function totalLabelFontSize(profile) {
      if (profile && profile.mobile) return 8;
      if (profile && profile.tablet) return 9;
      return 10;
    }

    function yearTickFontSize(profile) {
      if (profile && profile.mobile) return 8.5;
      if (profile && profile.tablet) return 9.5;
      return 10.5;
    }

    function renderCharts() {
      const start = Number(yearStart.value);
      const end = Number(yearEnd.value);
      const selectedSectors = selectedValues(sectorInputs);
      const selectedSubsectors = selectedValues(subsectorInputs);

      const baseFiltered = rawData.filter((d) =>
        selectedSectors.includes(d.sector) && selectedSubsectors.includes(d.subsector)
      );

      const visibleYears = allYears.filter((y) => y >= start && y <= end);
      const annualProfile = responsive.prepareScrollablePlot(annualChart, visibleYears.length, {
        mobilePixelsPerPeriod: 56,
        tabletPixelsPerPeriod: 54,
        desktopPixelsPerPeriod: 54,
        scrollThreshold: 14,
        allowDesktopScroll: true,
        mobileHeight: 420,
        tabletHeight: 440,
        desktopHeight: 470
      });
      const cumulativeProfile = responsive.prepareScrollablePlot(cumulativeChart, visibleYears.length, {
        mobilePixelsPerPeriod: 58,
        tabletPixelsPerPeriod: 56,
        desktopPixelsPerPeriod: 56,
        scrollThreshold: 14,
        allowDesktopScroll: true,
        mobileHeight: 420,
        tabletHeight: 440,
        desktopHeight: 470
      });
      const { bySectorYear, byYear } = aggregateAnnual(baseFiltered);
      const selectedSubsectorSet = new Set(selectedSubsectors);
      const sectorSubsectorLabel = {};
      selectedSectors.forEach((sector) => {
        const allSectorSubs = Array.from(new Set(rawData.filter((d) => d.sector === sector).map((d) => d.subsector))).sort();
        const activeSectorSubs = allSectorSubs.filter((subsector) => selectedSubsectorSet.has(subsector));
        sectorSubsectorLabel[sector] = activeSectorSubs.length === allSectorSubs.length
          ? "Todos"
          : activeSectorSubs.join(", ");
      });

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

      const baseLayout = {
        autosize: true,
        height: annualProfile.height,
        dragmode: false,
        separators: ",.",
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(0,0,0,0)",
        font: {
          family: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
          color: "#334155",
          size: annualProfile.fontSize
        },
        margin: {
          l: annualProfile.leftMargin,
          r: annualProfile.rightMargin,
          t: annualProfile.topMargin,
          b: annualProfile.compact ? 132 : 112
        },
        legend: {
          orientation: "h",
          x: 0.5,
          xanchor: "center",
          y: annualProfile.compact ? -0.25 : -0.20,
          yanchor: "top",
          font: { size: annualProfile.legendFontSize }
        },
        hoverlabel: { bgcolor: "#FFFFFF", bordercolor: "#CBD5E1", font: { color: "#0F172A" } },
        xaxis: {
          title: { text: "Año", standoff: 8, font: { size: annualProfile.titleFontSize } },
          tickmode: "array",
          tickvals: visibleYears,
          ticktext: visibleYears.map((year) => String(year)),
          tickangle: 0,
          tickfont: { size: yearTickFontSize(annualProfile) },
          showgrid: false,
          zeroline: false,
          automargin: true,
          fixedrange: true
        },
        yaxis: {
          title: { text: "Millones de USD", standoff: annualProfile.mobile ? 4 : 10, font: { size: annualProfile.titleFontSize } },
          tickfont: { size: annualProfile.tickFontSize },
          gridcolor: "#E5E7EB",
          zeroline: false,
          rangemode: "tozero",
          automargin: true,
          fixedrange: true,
          tickformat: ",.0f"
        }
      };

      if (selectedSectors.length === 0 || selectedSubsectors.length === 0 || baseFiltered.length === 0) {
        const emptyLayout = Object.assign({}, baseLayout, {
          annotations: emptyAnnotation("No hay datos para los filtros seleccionados.")
        });
        Plotly.react(annualChart, [], emptyLayout, plotConfig);
        Promise.resolve(
          Plotly.react(cumulativeChart, [], emptyLayout, plotConfig)
        ).then(bindLegendSync);
        return;
      }

      const annualTraces = selectedSectors.map((sector) => {
        const y = visibleYears.map((year) => bySectorYear.get(sector + "|||" + year) || 0);
        const hover = visibleYears.map((year, i) => {
          const total = byYear.get(year) || 0;
          const share = total > 0 ? y[i] / total : 0;
          return (
            "<b>" + sector + "</b><br>" +
            "Año: " + year + "<br>" +
            "Monto: USD " + formatter.format(y[i]) + " millones<br>" +
            "Participación: " + pctFormatter.format(share) + "<br>" +
            "Subsectores: " + sectorSubsectorLabel[sector] + "<br>" +
            "Total visible: USD " + formatter.format(total) + " millones"
          );
        });

        return {
          type: "bar",
          name: legendLabel(sector),
          legendgroup: sector,
          x: visibleYears,
          y: y,
          marker: { color: sectorColors[sector] || "#64748B" },
          meta: { sector: sector, subsectors: sectorSubsectorLabel[sector] },
          customdata: hover,
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });

      const annualTotals = visibleYears.map((year) => byYear.get(year) || 0);
      const annualLabels = totalLabels(annualTotals);
      annualTraces.push({
        type: "scatter",
        mode: "text",
        name: "Total",
        showlegend: false,
        x: visibleYears,
        y: annualTotals,
        text: annualLabels,
        textposition: "top center",
        textfont: { color: "#334155", size: totalLabelFontSize(annualProfile) },
        cliponaxis: false,
        hoverinfo: "skip"
      });

      const maxAnnual = Math.max.apply(null, annualTotals.concat([0]));
      const annualLayout = Object.assign({}, baseLayout, {
        barmode: "stack",
        bargap: 0.2,
        yaxis: Object.assign({}, baseLayout.yaxis, {
          range: maxAnnual > 0 ? [0, maxAnnual * labelHeadroom()] : [0, 1]
        })
      });

      Plotly.react(annualChart, annualTraces, annualLayout, plotConfig);

      const cumulativeBySector = {};
      selectedSectors.forEach((sector) => {
        let running = 0;
        cumulativeBySector[sector] = {};
        allYears.forEach((year) => {
          running += bySectorYear.get(sector + "|||" + year) || 0;
          cumulativeBySector[sector][year] = running;
        });
      });

      const cumulativeTotal = {};
      allYears.forEach((year) => {
        cumulativeTotal[year] = selectedSectors.reduce(
          (acc, sector) => acc + (cumulativeBySector[sector][year] || 0),
          0
        );
      });

      const cumulativeTraces = selectedSectors.map((sector) => {
        const y = visibleYears.map((year) => cumulativeBySector[sector][year] || 0);
        return {
          type: "bar",
          name: legendLabel(sector),
          legendgroup: sector,
          x: visibleYears,
          y: y,
          marker: { color: sectorColors[sector] || "#64748B" },
          meta: { sector: sector },
          customdata: visibleYears.map((year, i) => ({ year: year, value: y[i] })),
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });

      const cumulativeTotals = visibleYears.map((year) => cumulativeTotal[year] || 0);
      cumulativeTraces.forEach((trace) => {
        trace.customdata = trace.customdata.map((d, i) => {
          const share = cumulativeTotals[i] > 0 ? d.value / cumulativeTotals[i] : 0;
          return (
            "<b>" + trace.meta.sector + "</b><br>" +
            "Año: " + d.year + "<br>" +
            "Plan de inversión acumulado: USD " + formatter.format(d.value) + " millones<br>" +
            "Participación: " + pctFormatter.format(share) + "<br>" +
            "Total acumulado visible: USD " + formatter.format(cumulativeTotals[i]) + " millones"
          );
        });
      });

      cumulativeTraces.push({
        type: "scatter",
        mode: "text",
        name: "Total acumulado",
        showlegend: false,
        x: visibleYears,
        y: cumulativeTotals,
        text: totalLabels(cumulativeTotals),
        textposition: "top center",
        textfont: { color: "#334155", size: totalLabelFontSize(cumulativeProfile) },
        cliponaxis: false,
        hoverinfo: "skip"
      });

      const maxCumulative = Math.max.apply(null, cumulativeTotals.concat([0]));
      const cumulativeLayout = Object.assign({}, baseLayout, {
        height: cumulativeProfile.height,
        barmode: "stack",
        bargap: 0.30,
        yaxis: Object.assign({}, baseLayout.yaxis, {
          range: maxCumulative > 0 ? [0, maxCumulative * labelHeadroom()] : [0, 1]
        })
      });

      Promise.resolve(
        Plotly.react(cumulativeChart, cumulativeTraces, cumulativeLayout, plotConfig)
      ).then(bindLegendSync);
    }

    function traceIsVisible(trace) {
      return trace.visible !== "legendonly" && trace.visible !== false;
    }

    function syncAnnualTotalsWithLegend() {
      if (syncingAnnualLegend || !annualChart.data || annualChart.data.length === 0) return;

      const totalIndex = annualChart.data.findIndex((trace) =>
        trace.type === "scatter" && trace.name === "Total"
      );
      if (totalIndex < 0) return;

      const totalTrace = annualChart.data[totalIndex];
      const xValues = Array.from(totalTrace.x || []);
      const visibleSectorTraces = annualChart.data.filter((trace) =>
        trace.type === "bar" && traceIsVisible(trace)
      );

      const totals = xValues.map((year, i) =>
        visibleSectorTraces.reduce(
          (sum, trace) => sum + Number((trace.y || [])[i] || 0),
          0
        )
      );
      const profile = responsive.getResponsivePlotConfig({
        mobileHeight: 420,
        tabletHeight: 440,
        desktopHeight: 470
      });
      const labels = totalLabels(totals);
      const maxTotal = Math.max.apply(null, totals.concat([0]));

      syncingAnnualLegend = true;

      const hoverUpdates = annualChart.data
        .map((trace, index) => ({ trace, index }))
        .filter(({ trace }) => trace.type === "bar")
        .map(({ trace, index }) => {
          const hover = xValues.map((year, i) => {
            const value = Number((trace.y || [])[i] || 0);
            const total = totals[i] || 0;
            const share = total > 0 ? value / total : 0;
            const subsectors = trace.meta && trace.meta.subsectors ? trace.meta.subsectors : "Todos";
            return (
              "<b>" + (trace.meta && trace.meta.sector ? trace.meta.sector : trace.name) + "</b><br>" +
              "Año: " + year + "<br>" +
              "Monto: USD " + formatter.format(value) + " millones<br>" +
              "Participación: " + pctFormatter.format(share) + "<br>" +
              "Subsectores: " + subsectors + "<br>" +
              "Total visible: USD " + formatter.format(total) + " millones"
            );
          });
          return Plotly.restyle(annualChart, { customdata: [hover] }, [index]);
        });

      Promise.all(hoverUpdates.concat([
        Plotly.restyle(
          annualChart,
          { y: [totals], text: [labels] },
          [totalIndex]
        ),
        Plotly.relayout(annualChart, {
          "yaxis.range": maxTotal > 0 ? [0, maxTotal * labelHeadroom()] : [0, 1]
        })
      ])).finally(() => {
        syncingAnnualLegend = false;
      });
    }

    function syncCumulativeTotalWithLegend() {
      if (syncingCumulativeLegend || !cumulativeChart.data || cumulativeChart.data.length === 0) return;

      const totalIndex = cumulativeChart.data.findIndex((trace) =>
        trace.type === "scatter" && trace.name === "Total acumulado"
      );
      if (totalIndex < 0) return;

      const totalTrace = cumulativeChart.data[totalIndex];
      const xValues = Array.from(totalTrace.x || []);
      const visibleSectorTraces = cumulativeChart.data.filter((trace) =>
        trace.type === "bar" && traceIsVisible(trace)
      );

      const totals = xValues.map((year, i) =>
        visibleSectorTraces.reduce(
          (sum, trace) => sum + Number((trace.y || [])[i] || 0),
          0
        )
      );
      const profile = responsive.getResponsivePlotConfig({
        mobileHeight: 420,
        tabletHeight: 440,
        desktopHeight: 470
      });
      const labels = totalLabels(totals);
      const maxTotal = Math.max.apply(null, totals.concat([0]));

      syncingCumulativeLegend = true;

      const hoverUpdates = cumulativeChart.data
        .map((trace, index) => ({ trace, index }))
        .filter(({ trace }) => trace.type === "bar")
        .map(({ trace, index }) => {
          const hover = xValues.map((year, i) => {
            const value = Number((trace.y || [])[i] || 0);
            const total = totals[i] || 0;
            const share = total > 0 ? value / total : 0;
            return (
              "<b>" + (trace.meta && trace.meta.sector ? trace.meta.sector : trace.name) + "</b><br>" +
              "Año: " + year + "<br>" +
              "Plan de inversión acumulado: USD " + formatter.format(value) + " millones<br>" +
              "Participación: " + pctFormatter.format(share) + "<br>" +
              "Total acumulado visible: USD " + formatter.format(total) + " millones"
            );
          });
          return Plotly.restyle(cumulativeChart, { customdata: [hover] }, [index]);
        });

      Promise.all(hoverUpdates.concat([
        Plotly.restyle(
          cumulativeChart,
          { y: [totals], text: [labels] },
          [totalIndex]
        ),
        Plotly.relayout(cumulativeChart, {
          "yaxis.range": maxTotal > 0 ? [0, maxTotal * labelHeadroom()] : [0, 1]
        })
      ])).finally(() => {
        syncingCumulativeLegend = false;
      });
    }

    function bindLegendSync() {
      if (
        typeof annualChart.on === "function" &&
        annualChart.dataset.legendSyncBound !== "true"
      ) {
        annualChart.dataset.legendSyncBound = "true";
        annualChart.on("plotly_restyle", function () {
          if (!syncingAnnualLegend) {
            window.requestAnimationFrame(syncAnnualTotalsWithLegend);
          }
        });
      }

      if (
        typeof cumulativeChart.on === "function" &&
        cumulativeChart.dataset.legendSyncBound !== "true"
      ) {
        cumulativeChart.dataset.legendSyncBound = "true";
        cumulativeChart.on("plotly_restyle", function () {
          if (!syncingCumulativeLegend) {
            window.requestAnimationFrame(syncCumulativeTotalWithLegend);
          }
        });
      }
    }

    function refreshControlsAndCharts() {
      updateMasterCheckbox(sectorAll, sectorInputs);
      updateMasterCheckbox(subsectorAll, subsectorInputs);
      updateSummary(sectorSummary, sectorInputs, "Todos los sectores", "seleccionados");
      updateSummary(subsectorSummary, subsectorInputs, "Todos los subsectores", "seleccionados");
      renderCharts();
    }

    function closeCompactMenu(input) {
      if (!responsive.isMobile() || !input) return;
      const details = input.closest("details");
      if (details) details.open = false;
    }

    yearStart.addEventListener("change", function () {
      if (Number(yearStart.value) > Number(yearEnd.value)) yearEnd.value = yearStart.value;
      renderCharts();
    });

    yearEnd.addEventListener("change", function () {
      if (Number(yearEnd.value) < Number(yearStart.value)) yearStart.value = yearEnd.value;
      renderCharts();
    });

    sectorAll.addEventListener("change", function () {
      sectorInputs.forEach((input) => { input.checked = sectorAll.checked; });
      refreshSubsectorAvailability(true);
      refreshControlsAndCharts();
      closeCompactMenu(sectorAll);
    });

    sectorInputs.forEach((input) => {
      input.addEventListener("change", function () {
        updateMasterCheckbox(sectorAll, sectorInputs);
        updateSummary(sectorSummary, sectorInputs, "Todos los sectores", "seleccionados");
        refreshSubsectorAvailability(true);
        renderCharts();
        closeCompactMenu(input);
      });
    });

    subsectorAll.addEventListener("change", function () {
      subsectorInputs.forEach((input) => {
        if (!input.disabled) input.checked = subsectorAll.checked;
      });
      refreshControlsAndCharts();
      closeCompactMenu(subsectorAll);
    });

    subsectorInputs.forEach((input) => {
      input.addEventListener("change", function () {
        refreshControlsAndCharts();
        closeCompactMenu(input);
      });
    });

    resetButton.addEventListener("click", function () {
      yearStart.value = String(defaultStartYear);
      yearEnd.value = String(defaultEndYear);
      sectorInputs.forEach((input) => { input.checked = true; });
      sectorAll.checked = true;
      sectorAll.indeterminate = false;
      refreshSubsectorAvailability(true);
      subsectorAll.checked = true;
      subsectorAll.indeterminate = false;
      refreshControlsAndCharts();
    });

    document.addEventListener("click", function (event) {
      root.querySelectorAll(".plans-multiselect[open]").forEach((details) => {
        if (!details.contains(event.target)) details.removeAttribute("open");
      });
    });

    responsive.subscribe("planes-inversion", renderCharts);

    refreshSubsectorAvailability(true);
    refreshControlsAndCharts();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPlansInvestment);
  } else {
    initPlansInvestment();
  }
})();
