(function () {
  "use strict";

  function initPlansInvestment() {
    const root = document.getElementById("planes-inversion-module");
    if (!root || root.dataset.initialized === "true") return;

    if (typeof window.Plotly === "undefined") {
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

      if (profile.mobile) target = Math.max(available, periodCount * 46 + 88);
      else if (profile.tablet) target = Math.max(available, periodCount * 34 + 82);

      const scrolling = target > available + 8;
      chart.style.width = scrolling ? Math.ceil(target) + "px" : "100%";
      chart.style.minWidth = scrolling ? Math.ceil(target) + "px" : "0";
      if (parts.hint) parts.hint.classList.toggle("is-visible", scrolling);
      return { profile, scrolling };
    }

    function responsiveLayoutParts(periodCount, hasLegend) {
      const profile = viewportProfile();
      const mobile = profile.mobile;
      const tablet = profile.tablet;
      return {
        margin: mobile
          ? { l: 52, r: 12, t: 30, b: hasLegend ? 96 : 66 }
          : tablet
            ? { l: 62, r: 18, t: 28, b: hasLegend ? 100 : 72 }
            : { l: 72, r: 22, t: 24, b: 100 },
        fontSize: mobile ? 10.5 : tablet ? 11 : 12,
        tickSize: mobile ? 9.5 : tablet ? 10 : 11,
        titleSize: mobile ? 10.5 : tablet ? 11 : 12,
        labelSize: mobile ? 9.5 : 11,
        height: mobile ? 390 : tablet ? 440 : 470,
        legend: {
          orientation: "h",
          x: mobile ? 0 : 0.5,
          xanchor: mobile ? "left" : "center",
          y: mobile ? -0.22 : -0.18,
          yanchor: "top",
          font: { size: mobile ? 9.5 : tablet ? 10 : 11 }
        }
      };
    }

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

    function renderCharts() {
      const start = Number(yearStart.value);
      const end = Number(yearEnd.value);
      const selectedSectors = selectedValues(sectorInputs);
      const selectedSubsectors = selectedValues(subsectorInputs);

      const baseFiltered = rawData.filter((d) =>
        selectedSectors.includes(d.sector) && selectedSubsectors.includes(d.subsector)
      );

      const visibleYears = allYears.filter((y) => y >= start && y <= end);
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

      const responsive = responsiveLayoutParts(visibleYears.length, true);
      prepareChartWidth(annualChart, visibleYears.length);
      prepareChartWidth(cumulativeChart, visibleYears.length);

      const baseLayout = {
        autosize: true,
        height: responsive.height,
        paper_bgcolor: "rgba(0,0,0,0)",
        plot_bgcolor: "rgba(0,0,0,0)",
        font: { family: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif", color: "#334155", size: responsive.fontSize },
        margin: responsive.margin,
        legend: responsive.legend,
        hoverlabel: { bgcolor: "#FFFFFF", bordercolor: "#CBD5E1", font: { color: "#0F172A" } },
        xaxis: {
          title: { text: "Año", standoff: 10, font: { size: responsive.titleSize } },
          tickmode: "linear",
          dtick: Math.max(1, Math.ceil(Math.max(1, end - start + 1) / 12)),
          showgrid: false,
          zeroline: false,
          automargin: true,
          tickfont: { size: responsive.tickSize }
        },
        yaxis: {
          title: { text: "Millones de USD", standoff: 10, font: { size: responsive.titleSize } },
          gridcolor: "#E5E7EB",
          zeroline: false,
          rangemode: "tozero",
          automargin: true,
          tickformat: ",.0f",
          tickfont: { size: responsive.tickSize }
        }
      };

      if (selectedSectors.length === 0 || selectedSubsectors.length === 0 || baseFiltered.length === 0) {
        const emptyLayout = Object.assign({}, baseLayout, {
          annotations: emptyAnnotation("No hay datos para los filtros seleccionados.")
        });
        Plotly.react(annualChart, [], emptyLayout, { displayModeBar: false, responsive: true });
        Promise.resolve(
          Plotly.react(cumulativeChart, [], emptyLayout, { displayModeBar: false, responsive: true })
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
        textfont: { color: "#334155", size: responsive.labelSize },
        cliponaxis: false,
        hoverinfo: "skip"
      });

      const maxAnnual = Math.max.apply(null, annualTotals.concat([0]));
      const annualLayout = Object.assign({}, baseLayout, {
        barmode: "stack",
        bargap: 0.2,
        yaxis: Object.assign({}, baseLayout.yaxis, {
          range: maxAnnual > 0 ? [0, maxAnnual * 1.16] : [0, 1]
        })
      });

      Plotly.react(annualChart, annualTraces, annualLayout, { displayModeBar: false, responsive: true });

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
        hovermode: "x unified"
      });

      Promise.resolve(
        Plotly.react(cumulativeChart, cumulativeTraces, cumulativeLayout, { displayModeBar: false, responsive: true })
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
          "yaxis.range": maxTotal > 0 ? [0, maxTotal * 1.16] : [0, 1]
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

    let responsiveResizeTimer = null;
    function resizePlansCharts() {
      const start = Number(yearStart.value);
      const end = Number(yearEnd.value);
      const count = allYears.filter((y) => y >= start && y <= end).length;
      const responsive = responsiveLayoutParts(count, true);
      [annualChart, cumulativeChart].forEach((chart) => {
        prepareChartWidth(chart, count);
        if (!chart || !chart.layout) return;
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
      responsiveResizeTimer = window.setTimeout(resizePlansCharts, 140);
    });

    refreshSubsectorAvailability(true);
    refreshControlsAndCharts();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initPlansInvestment);
  } else {
    initPlansInvestment();
  }
})();
