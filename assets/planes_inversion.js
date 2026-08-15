(function () {
  "use strict";

  function initPlansInvestment() {
    const root = document.getElementById("planes-inversion-module");
    if (!root || root.dataset.initialized === "true") return;

    if (typeof window.Plotly === "undefined" || typeof window.RigiResponsive === "undefined") {
      window.setTimeout(initPlansInvestment, 100);
      return;
    }

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
      if (responsive.isMobile()) return 1.22;
      if (responsive.isTablet()) return 1.19;
      return 1.16;
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
        mobilePixelsPerPeriod: 50,
        tabletPixelsPerPeriod: 46,
        scrollThreshold: 12,
        mobileHeight: 400,
        tabletHeight: 440,
        desktopHeight: 470
      });
      const cumulativeProfile = responsive.prepareScrollablePlot(cumulativeChart, visibleYears.length, {
        mobilePixelsPerPeriod: 50,
        tabletPixelsPerPeriod: 46,
        scrollThreshold: 12,
        mobileHeight: 400,
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

      const baseLayout = {
        autosize: true,
        height: annualProfile.height,
        dragmode: false,
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
          b: annualProfile.compact ? 108 : 100
        },
        legend: {
          orientation: "h",
          x: 0.5,
          xanchor: "center",
          y: annualProfile.compact ? -0.20 : -0.18,
          yanchor: "top",
          font: { size: annualProfile.legendFontSize }
        },
        hoverlabel: { bgcolor: "#FFFFFF", bordercolor: "#CBD5E1", font: { color: "#0F172A" } },
        uniformtext: { mode: "hide", minsize: 9 },
        xaxis: {
          title: { text: "Año", standoff: 8, font: { size: annualProfile.titleFontSize } },
          tickmode: "linear",
          dtick: annualProfile.compact ? 1 : Math.max(1, Math.ceil(Math.max(1, end - start + 1) / 12)),
          tickfont: { size: annualProfile.tickFontSize },
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
            "Monto: US$ " + formatter.format(y[i]) + " millones<br>" +
            "Participación: " + pctFormatter.format(share) + "<br>" +
            "Subsectores: " + sectorSubsectorLabel[sector]
          );
        });

        return {
          type: "bar",
          name: sector,
          x: visibleYears,
          y: y,
          marker: { color: sectorColors[sector] || "#64748B" },
          customdata: hover,
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });

      const annualTotals = visibleYears.map((year) => byYear.get(year) || 0);
      const annualLabels = annualTotals.map((value) => value > 0 ? formatter.format(value) : "");
      annualTraces.push({
        type: "scatter",
        mode: "text",
        name: "Total",
        showlegend: false,
        x: visibleYears,
        y: annualTotals,
        text: annualLabels,
        textposition: "top center",
        textfont: { color: "#334155", size: annualProfile.textFontSize },
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
        const hover = visibleYears.map((year, i) =>
          "<b>" + sector + "</b><br>" +
          "Año: " + year + "<br>" +
          "Acumulado del sector: US$ " + formatter.format(y[i]) + " millones<br>" +
          "Acumulado total: US$ " + formatter.format(cumulativeTotal[year] || 0) + " millones"
        );

        return {
          type: "scatter",
          mode: "lines",
          name: sector,
          x: visibleYears,
          y: y,
          stackgroup: "planes-total",
          line: { color: sectorColors[sector] || "#64748B", width: 1.5 },
          fillcolor: sectorColors[sector] || "#64748B",
          customdata: hover,
          hovertemplate: "%{customdata}<extra></extra>"
        };
      });

      cumulativeTraces.push({
        type: "scatter",
        mode: "lines",
        name: "Total acumulado",
        x: visibleYears,
        y: visibleYears.map((year) => cumulativeTotal[year] || 0),
        line: { color: "#0F172A", width: 2.5 },
        customdata: visibleYears.map((year) =>
          "<b>Total acumulado</b><br>Año: " + year + "<br>US$ " + formatter.format(cumulativeTotal[year] || 0) + " millones"
        ),
        hovertemplate: "%{customdata}<extra></extra>"
      });

      const cumulativeLayout = Object.assign({}, baseLayout, {
        height: cumulativeProfile.height,
        hovermode: "x unified"
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
      const labels = totals.map((value) => value > 0 ? formatter.format(value) : "");
      const maxTotal = Math.max.apply(null, totals.concat([0]));

      syncingAnnualLegend = true;
      Promise.resolve(
        Plotly.restyle(
          annualChart,
          { y: [totals], text: [labels] },
          [totalIndex]
        )
      )
        .then(() => Plotly.relayout(annualChart, {
          "yaxis.range": maxTotal > 0 ? [0, maxTotal * labelHeadroom()] : [0, 1]
        }))
        .finally(() => {
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
      const visibleSectorTraces = cumulativeChart.data.filter((trace, index) =>
        index !== totalIndex &&
        trace.type === "scatter" &&
        trace.stackgroup === "planes-total" &&
        traceIsVisible(trace)
      );

      const totals = xValues.map((year, i) =>
        visibleSectorTraces.reduce(
          (sum, trace) => sum + Number((trace.y || [])[i] || 0),
          0
        )
      );
      const hover = xValues.map((year, i) =>
        "<b>Total acumulado</b><br>Año: " + year +
        "<br>US$ " + formatter.format(totals[i] || 0) + " millones"
      );

      syncingCumulativeLegend = true;
      Promise.resolve(
        Plotly.restyle(
          cumulativeChart,
          { y: [totals], customdata: [hover] },
          [totalIndex]
        )
      )
        .then(() => Plotly.relayout(cumulativeChart, { "yaxis.autorange": true }))
        .finally(() => {
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
    });

    sectorInputs.forEach((input) => {
      input.addEventListener("change", function () {
        updateMasterCheckbox(sectorAll, sectorInputs);
        updateSummary(sectorSummary, sectorInputs, "Todos los sectores", "seleccionados");
        refreshSubsectorAvailability(true);
        renderCharts();
      });
    });

    subsectorAll.addEventListener("change", function () {
      subsectorInputs.forEach((input) => {
        if (!input.disabled) input.checked = subsectorAll.checked;
      });
      refreshControlsAndCharts();
    });

    subsectorInputs.forEach((input) => {
      input.addEventListener("change", refreshControlsAndCharts);
    });

    resetButton.addEventListener("click", function () {
      yearStart.value = String(minYear);
      yearEnd.value = String(maxYear);
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
