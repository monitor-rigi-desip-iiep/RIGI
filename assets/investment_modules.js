(function () {
  "use strict";

  const numberFormatter = new Intl.NumberFormat("es-AR", { maximumFractionDigits: 1 });
  const percentFormatter = new Intl.NumberFormat("es-AR", {
    style: "percent",
    maximumFractionDigits: 1
  });
  const dateFormatter = new Intl.DateTimeFormat("es-AR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    timeZone: "UTC"
  });

  function finiteNumber(value) {
    if (value === null || value === undefined || value === "") return null;
    if (typeof value === "number") return Number.isFinite(value) ? value : null;
    if (typeof value !== "string") return null;
    const normalized = value.trim();
    if (!normalized) return null;
    const parsed = Number(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }

  function formatCurrency(value) {
    const parsed = finiteNumber(value);
    return parsed === null ? "No informado" : "USD " + numberFormatter.format(parsed) + " millones";
  }

  function formatEmployment(value) {
    const parsed = finiteNumber(value);
    return parsed === null ? "No informado" : numberFormatter.format(parsed) + " empleos";
  }

  function formatPercent(value) {
    return Number.isFinite(value) ? percentFormatter.format(value) : "No informado";
  }

  function parseDate(value) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ""))) return null;
    const parsed = new Date(value + "T00:00:00Z");
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }

  function formatDate(value) {
    const parsed = value instanceof Date ? value : parseDate(value);
    return parsed ? dateFormatter.format(parsed) : "No informado";
  }

  function readJson(root, selector, fallbackTarget) {
    const source = root.querySelector(selector);
    if (!source) return null;
    try {
      return JSON.parse(source.textContent);
    } catch (error) {
      if (fallbackTarget) fallbackTarget.textContent = "No se pudo cargar este componente.";
      return null;
    }
  }

  function bindTabs(buttons, dataKey, activate) {
    buttons.forEach(function (button, index) {
      button.addEventListener("click", function () {
        activate(button.dataset[dataKey], false);
      });
      button.addEventListener("keydown", function (event) {
        let nextIndex = null;
        if (event.key === "ArrowRight") nextIndex = (index + 1) % buttons.length;
        if (event.key === "ArrowLeft") nextIndex = (index - 1 + buttons.length) % buttons.length;
        if (event.key === "Home") nextIndex = 0;
        if (event.key === "End") nextIndex = buttons.length - 1;
        if (nextIndex === null) return;
        event.preventDefault();
        activate(buttons[nextIndex].dataset[dataKey], true);
      });
    });
  }

  function setActiveTab(buttons, dataKey, activeView, focus) {
    buttons.forEach(function (button) {
      const active = button.dataset[dataKey] === activeView;
      button.setAttribute("aria-selected", active ? "true" : "false");
      button.tabIndex = active ? 0 : -1;
      if (active && focus) button.focus();
    });
  }

  function requestedRows(limit, length) {
    return limit.value === "all" ? length : Math.min(length, Number(limit.value));
  }

  function initRankedModule(root) {
    if (root.dataset.rankedReady === "true") return;
    const chart = root.querySelector("[data-ranked-chart]");
    const note = root.querySelector("[data-ranked-note]");
    const limit = root.querySelector("[data-ranked-limit]");
    const buttons = Array.from(root.querySelectorAll("[data-ranked-view]"));
    if (!chart || !note || !limit) return;
    const config = readJson(root, "[data-ranked-data]", chart);
    if (!config) return;

    let activeView = config.defaultView || Object.keys(config.views || {})[0] || "project";
    if (config.defaultLimit && Array.from(limit.options).some(function (option) {
      return option.value === config.defaultLimit;
    })) {
      limit.value = config.defaultLimit;
    }
    const valueFormatter = config.valueType === "employment" ? formatEmployment : formatCurrency;
    const noteOverride = typeof config.noteOverride === "string"
      ? config.noteOverride.trim()
      : "";

    function updateNote() {
      if (noteOverride) {
        note.textContent = noteOverride;
      } else if (activeView === "province") {
        note.textContent = config.valueType === "employment"
          ? "Los proyectos multiprovinciales se distribuyen en partes iguales entre sus provincias. Las fracciones se conservan y se muestran con hasta un decimal cuando es necesario."
          : "Los proyectos multiprovinciales se distribuyen en partes iguales entre sus provincias; la suma provincial reconcilia con el total del universo.";
      } else if (activeView === "sector") {
        note.textContent = "Los valores corresponden a la suma de los proyectos con información disponible en cada sector.";
      } else {
        note.textContent = config.valueType === "employment"
          ? "Los proyectos se ordenan de mayor a menor. Las etiquetas muestran empleo informado y participación sobre el total con información disponible."
          : "Los proyectos se ordenan de mayor a menor. Las etiquetas muestran monto y participación sobre el total con información disponible.";
      }
    }

    function render() {
      const rows = (config.views[activeView] || []).slice().sort(function (a, b) {
        return Number(b.value) - Number(a.value) || String(a.label).localeCompare(String(b.label), "es");
      });
      const visible = rows.slice(0, requestedRows(limit, rows.length));
      const maximum = rows.reduce(function (max, row) {
        const value = finiteNumber(row.value);
        return value === null ? max : Math.max(max, value);
      }, 0);
      const calculatedTotal = rows.reduce(function (sum, row) {
        const value = finiteNumber(row.value);
        return value === null ? sum : sum + value;
      }, 0);
      const configuredTotal = finiteNumber(config.shareTotal);
      const total = configuredTotal !== null ? configuredTotal : calculatedTotal;

      chart.replaceChildren();
      updateNote();
      if (!visible.length) {
        const empty = document.createElement("p");
        empty.className = "rigi-investment-module__empty";
        empty.textContent = "No hay datos disponibles para esta vista.";
        chart.appendChild(empty);
        return;
      }

      visible.forEach(function (row, index) {
        const numericValue = finiteNumber(row.value);
        const share = numericValue !== null && total > 0 ? numericValue / total : NaN;
        const width = numericValue !== null && maximum > 0 ? Math.max(0, numericValue / maximum * 100) : 0;
        const formatted = valueFormatter(row.value);
        const accessible = row.label + ": " + formatted + ", participación " + formatPercent(share);

        const item = document.createElement("div");
        item.className = "rigi-investment-row";
        item.tabIndex = 0;
        item.setAttribute("aria-label", accessible);
        item.title = accessible + ". " + row.count + (row.count === 1 ? " proyecto" : " proyectos");

        const label = document.createElement("div");
        label.className = "rigi-investment-row__label";
        label.textContent = (index + 1) + ". " + row.label;

        const barCell = document.createElement("div");
        barCell.className = "rigi-investment-row__bar-cell";
        const track = document.createElement("div");
        track.className = "rigi-investment-row__track";
        const bar = document.createElement("div");
        bar.className = "rigi-investment-row__bar";
        bar.style.width = width + "%";
        bar.style.backgroundColor = config.color;
        bar.setAttribute("aria-hidden", "true");
        track.appendChild(bar);
        barCell.appendChild(track);

        const value = document.createElement("div");
        value.className = "rigi-investment-row__value";
        value.textContent = formatted + " · " + formatPercent(share);
        item.append(label, barCell, value);
        chart.appendChild(item);
      });

      const summary = document.createElement("p");
      summary.className = "visually-hidden";
      summary.textContent = "Se muestran " + visible.length + " de " + rows.length + " resultados.";
      chart.appendChild(summary);
    }

    function activate(view, focus) {
      activeView = view;
      setActiveTab(buttons, "rankedView", activeView, focus);
      render();
    }

    if (buttons.length) bindTabs(buttons, "rankedView", activate);
    limit.addEventListener("change", render);
    root.dataset.rankedReady = "true";
    render();
  }

  function initScheduleModule(root) {
    if (root.dataset.scheduleReady === "true") return;
    const chart = root.querySelector("[data-schedule-chart]");
    const note = root.querySelector("[data-schedule-note]");
    const status = root.querySelector("[data-schedule-status]");
    const limit = root.querySelector("[data-schedule-limit]");
    const buttons = Array.from(root.querySelectorAll("[data-schedule-view]"));
    if (!chart || !note || !status || !limit || !buttons.length) return;
    const config = readJson(root, "[data-schedule-data]", chart);
    if (!config) return;
    let activeView = "commitment";

    function updateText(view) {
      const meta = config.views[view] || {};
      note.textContent = view === "commitment"
        ? "Cada barra comienza en la fecha de adhesión y finaliza 24 meses después. El orden corresponde a la fecha de adhesión."
        : "Cada barra comienza en la fecha de adhesión y finaliza en la fecha límite específica del proyecto; el punto marca el vencimiento.";
      const parts = [(meta.included || 0) + " proyectos incluidos"];
      if (meta.excludedMissing) parts.push(meta.excludedMissing + " excluidos por fechas faltantes");
      if (meta.invalid) parts.push(meta.invalid + " excluidos por una fecha límite anterior a la adhesión (error de datos)");
      status.textContent = parts.join(" · ");
      status.classList.toggle("has-data-error", Boolean(meta.invalid));
    }

    function render() {
      const meta = config.views[activeView] || { rows: [] };
      const rows = (meta.rows || []).slice().sort(function (a, b) {
        return String(a.start).localeCompare(String(b.start)) || String(a.label).localeCompare(String(b.label), "es");
      });
      const visible = rows.slice(0, requestedRows(limit, rows.length));
      const starts = rows.map(function (row) { return parseDate(row.start); }).filter(Boolean);
      const ends = rows.map(function (row) { return parseDate(row.end); }).filter(Boolean);
      const minimum = starts.length ? Math.min.apply(null, starts.map(function (date) { return date.getTime(); })) : 0;
      const maximum = ends.length ? Math.max.apply(null, ends.map(function (date) { return date.getTime(); })) : 0;
      const span = Math.max(1, maximum - minimum);

      chart.replaceChildren();
      updateText(activeView);
      if (!visible.length) {
        const empty = document.createElement("p");
        empty.className = "rigi-investment-module__empty";
        empty.textContent = "No hay fechas completas y válidas para esta vista.";
        chart.appendChild(empty);
        return;
      }

      visible.forEach(function (row, index) {
        const start = parseDate(row.start);
        const end = parseDate(row.end);
        if (!start || !end) return;
        const left = Math.max(0, (start.getTime() - minimum) / span * 100);
        const width = Math.max(0.7, (end.getTime() - start.getTime()) / span * 100);
        const amount = formatCurrency(row.amount);
        const endLabel = activeView === "commitment" ? "Fin del horizonte" : "Fecha límite";
        const accessible = row.label + ". Fecha de adhesión: " + formatDate(start) + ". "
          + endLabel + ": " + formatDate(end) + ". " + amount + ". La barra representa tiempo.";

        const item = document.createElement("div");
        item.className = "rigi-schedule-row";
        item.tabIndex = 0;
        item.setAttribute("aria-label", accessible);
        item.title = accessible;

        const label = document.createElement("div");
        label.className = "rigi-schedule-row__label";
        label.textContent = (index + 1) + ". " + row.label;

        const timeline = document.createElement("div");
        timeline.className = "rigi-schedule-row__timeline";
        const track = document.createElement("div");
        track.className = "rigi-schedule-row__track";
        const bar = document.createElement("span");
        bar.className = "rigi-schedule-row__bar" + (activeView === "deadline" ? " is-deadline" : "");
        bar.style.left = left + "%";
        bar.style.width = Math.min(100 - left, width) + "%";
        bar.setAttribute("aria-hidden", "true");
        track.appendChild(bar);

        const dates = document.createElement("div");
        dates.className = "rigi-schedule-row__dates";
        const startText = document.createElement("span");
        startText.textContent = "Adhesión: " + formatDate(start);
        const endText = document.createElement("span");
        endText.textContent = (activeView === "commitment" ? "Fin: " : "Límite: ") + formatDate(end);
        dates.append(startText, endText);
        timeline.append(track, dates);

        const value = document.createElement("div");
        value.className = "rigi-schedule-row__value";
        value.textContent = amount;
        item.append(label, timeline, value);
        chart.appendChild(item);
      });
    }

    function activate(view, focus) {
      activeView = view;
      setActiveTab(buttons, "scheduleView", activeView, focus);
      render();
    }

    bindTabs(buttons, "scheduleView", activate);
    limit.addEventListener("change", render);
    root.dataset.scheduleReady = "true";
    render();
  }

  function initComparisonModule(root) {
    if (root.dataset.comparisonReady === "true") return;
    const chart = root.querySelector("[data-comparison-chart]");
    const note = root.querySelector("[data-comparison-note]");
    const limit = root.querySelector("[data-comparison-limit]");
    const buttons = Array.from(root.querySelectorAll("[data-comparison-view]"));
    if (!chart || !note || !limit || !buttons.length) return;
    const config = readJson(root, "[data-comparison-data]", chart);
    if (!config) return;
    let activeView = "sector";

    function renderSeries(container, label, value, total, maximum, color) {
      const parsed = finiteNumber(value);
      const share = parsed !== null && total > 0 ? parsed / total : NaN;
      const width = parsed !== null && maximum > 0 ? parsed / maximum * 100 : 0;
      const series = document.createElement("div");
      series.className = "rigi-comparison-series";
      series.setAttribute("aria-label", label + ": " + formatCurrency(parsed) + ", " + formatPercent(share));
      const name = document.createElement("span");
      name.className = "rigi-comparison-series__name";
      name.textContent = label;
      const track = document.createElement("span");
      track.className = "rigi-comparison-series__track";
      const bar = document.createElement("span");
      bar.className = "rigi-comparison-series__bar";
      bar.style.width = width + "%";
      bar.style.backgroundColor = color;
      track.appendChild(bar);
      const formatted = document.createElement("span");
      formatted.className = "rigi-comparison-series__value";
      formatted.textContent = formatCurrency(parsed) + " · " + formatPercent(share);
      series.append(name, track, formatted);
      container.appendChild(series);
    }

    function render() {
      const rows = (config.views[activeView] || []).slice().sort(function (a, b) {
        const totalA = (finiteNumber(a.approved) || 0) + (finiteNumber(a.evaluation) || 0);
        const totalB = (finiteNumber(b.approved) || 0) + (finiteNumber(b.evaluation) || 0);
        return totalB - totalA || String(a.label).localeCompare(String(b.label), "es");
      });
      const visible = rows.slice(0, requestedRows(limit, rows.length));
      const approvedTotal = rows.reduce(function (sum, row) { return sum + (finiteNumber(row.approved) || 0); }, 0);
      const evaluationTotal = rows.reduce(function (sum, row) { return sum + (finiteNumber(row.evaluation) || 0); }, 0);
      const maximum = rows.reduce(function (max, row) {
        return Math.max(max, finiteNumber(row.approved) || 0, finiteNumber(row.evaluation) || 0);
      }, 0);

      note.textContent = activeView === "province"
        ? "Los montos multiprovinciales se distribuyen en partes iguales. Cada porcentaje usa como denominador el total informado de su respectivo estado."
        : "Las categorías se ordenan por el monto conjunto. Cada porcentaje usa como denominador el total informado de su respectivo estado.";
      chart.replaceChildren();

      visible.forEach(function (row, index) {
        const item = document.createElement("div");
        item.className = "rigi-comparison-row";
        item.tabIndex = 0;
        item.title = row.label + ". Aprobados: " + formatCurrency(row.approved)
          + ". En evaluación: " + formatCurrency(row.evaluation) + ".";
        const label = document.createElement("div");
        label.className = "rigi-comparison-row__label";
        label.textContent = (index + 1) + ". " + row.label;
        const series = document.createElement("div");
        series.className = "rigi-comparison-row__series";
        renderSeries(series, "Aprobados", row.approved, approvedTotal, maximum, config.colors.approved);
        renderSeries(series, "En evaluación", row.evaluation, evaluationTotal, maximum, config.colors.evaluation);
        item.append(label, series);
        chart.appendChild(item);
      });
    }

    function activate(view, focus) {
      activeView = view;
      setActiveTab(buttons, "comparisonView", activeView, focus);
      render();
    }

    bindTabs(buttons, "comparisonView", activate);
    limit.addEventListener("change", render);
    root.dataset.comparisonReady = "true";
    render();
  }

  function initAll() {
    document.querySelectorAll("[data-ranked-module]").forEach(initRankedModule);
    document.querySelectorAll("[data-schedule-module]").forEach(initScheduleModule);
    document.querySelectorAll("[data-comparison-module]").forEach(initComparisonModule);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll, { once: true });
  } else {
    initAll();
  }
})();
