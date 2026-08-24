(function () {
  "use strict";

  const amountFormatter = new Intl.NumberFormat("es-AR", {
    maximumFractionDigits: 1
  });
  const percentFormatter = new Intl.NumberFormat("es-AR", {
    style: "percent",
    maximumFractionDigits: 1
  });

  function formatAmount(value) {
    return "USD " + amountFormatter.format(value) + " millones";
  }

  function initModule(root) {
    if (root.dataset.investmentReady === "true") return;
    const source = root.querySelector("[data-investment-data]");
    const chart = root.querySelector("[data-investment-chart]");
    const note = root.querySelector("[data-investment-note]");
    const limit = root.querySelector("[data-investment-limit]");
    const buttons = Array.from(root.querySelectorAll("[data-investment-view]"));
    if (!source || !chart || !note || !limit || !buttons.length) return;

    let config;
    try {
      config = JSON.parse(source.textContent);
    } catch (error) {
      chart.textContent = "No se pudo cargar este gráfico.";
      return;
    }

    let activeView = "project";

    function viewLabel(view) {
      if (view === "sector") return "sector";
      if (view === "province") return "provincia";
      return "proyecto";
    }

    function updateNote() {
      if (activeView === "province") {
        note.textContent = "Los proyectos multiprovinciales se distribuyen en partes iguales entre sus provincias; la suma provincial reconcilia con el total del universo.";
      } else if (activeView === "sector") {
        note.textContent = "Los valores corresponden a la suma de los proyectos con información disponible en cada sector.";
      } else {
        note.textContent = "Los proyectos se ordenan de mayor a menor. Las etiquetas muestran monto y participación sobre el total con información disponible.";
      }
    }

    function render() {
      const rows = (config.views[activeView] || []).slice().sort(function (a, b) {
        return b.value - a.value || a.label.localeCompare(b.label, "es");
      });
      const requested = limit.value === "all" ? rows.length : Number(limit.value);
      const visible = rows.slice(0, requested);
      const maximum = rows.length ? rows[0].value : 0;
      const total = rows.reduce(function (sum, row) { return sum + Number(row.value || 0); }, 0);

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
        const share = total > 0 ? row.value / total : 0;
        const width = maximum > 0 ? Math.max(0, Math.min(100, row.value / maximum * 100)) : 0;
        const item = document.createElement("div");
        item.className = "rigi-investment-row";
        item.tabIndex = 0;
        item.setAttribute(
          "aria-label",
          row.label + ": " + formatAmount(row.value) + ", participación "
            + percentFormatter.format(share) + ", " + row.count
            + (row.count === 1 ? " proyecto" : " proyectos")
        );
        item.title = row.label + "\n" + formatAmount(row.value)
          + "\nParticipación: " + percentFormatter.format(share)
          + "\n" + row.count + (row.count === 1 ? " proyecto" : " proyectos");

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
        bar.setAttribute("role", "img");
        bar.setAttribute("aria-label", row.label + ": " + formatAmount(row.value) + ", " + percentFormatter.format(share));
        track.appendChild(bar);
        barCell.appendChild(track);

        const value = document.createElement("div");
        value.className = "rigi-investment-row__value";
        value.textContent = formatAmount(row.value) + " · " + percentFormatter.format(share);

        item.append(label, barCell, value);
        chart.appendChild(item);
      });

      const summary = document.createElement("p");
      summary.className = "visually-hidden";
      summary.textContent = "Se muestran " + visible.length + " de " + rows.length + " resultados por " + viewLabel(activeView) + ".";
      chart.appendChild(summary);
    }

    function activate(view, focus) {
      activeView = view;
      buttons.forEach(function (button) {
        const active = button.dataset.investmentView === view;
        button.setAttribute("aria-selected", active ? "true" : "false");
        button.tabIndex = active ? 0 : -1;
        if (active && focus) button.focus();
      });
      render();
    }

    buttons.forEach(function (button, index) {
      button.addEventListener("click", function () {
        activate(button.dataset.investmentView, false);
      });
      button.addEventListener("keydown", function (event) {
        if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
        event.preventDefault();
        const direction = event.key === "ArrowRight" ? 1 : -1;
        const next = buttons[(index + direction + buttons.length) % buttons.length];
        activate(next.dataset.investmentView, true);
      });
    });

    limit.addEventListener("change", render);
    root.dataset.investmentReady = "true";
    render();
  }

  function initAll() {
    document.querySelectorAll("[data-investment-module]").forEach(initModule);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll, { once: true });
  } else {
    initAll();
  }
})();
