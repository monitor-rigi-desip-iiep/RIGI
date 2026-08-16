(function () {
  "use strict";

  if (window.RigiResponsive) return;

  const mobileQuery = window.matchMedia("(max-width: 640px)");
  const tabletQuery = window.matchMedia("(max-width: 900px)");
  const subscribers = new Map();
  let resizeTimer = null;

  function isMobile() { return mobileQuery.matches; }
  function isTablet() { return tabletQuery.matches; }

  function getResponsivePlotConfig(options) {
    const opts = options || {};
    const mobile = isMobile();
    const tablet = !mobile && isTablet();
    return {
      mobile: mobile,
      tablet: tablet,
      compact: mobile || tablet,
      height: mobile ? (opts.mobileHeight || 390) : (tablet ? (opts.tabletHeight || 440) : (opts.desktopHeight || 470)),
      fontSize: mobile ? 10 : (tablet ? 11 : 12),
      tickFontSize: mobile ? 9.5 : (tablet ? 10 : 11),
      titleFontSize: mobile ? 11 : (tablet ? 11.5 : 12),
      textFontSize: mobile ? 10 : 11,
      legendFontSize: mobile ? 10 : (tablet ? 10.5 : 11),
      leftMargin: mobile ? 54 : (tablet ? 64 : 72),
      rightMargin: mobile ? 12 : (tablet ? 18 : 24),
      topMargin: mobile ? 28 : (tablet ? 30 : 36)
    };
  }

  function getPlotlyInteractionConfig() {
    return { displayModeBar: false, responsive: true, scrollZoom: false, doubleClick: false };
  }

  function findHint(wrapper, explicitHint) {
    if (explicitHint) return explicitHint;
    const id = wrapper && wrapper.dataset ? wrapper.dataset.scrollHint : "";
    return id ? document.getElementById(id) : null;
  }

  function updateOverflowHint(wrapper, explicitHint) {
    if (!wrapper) return false;
    const hint = findHint(wrapper, explicitHint);
    const overflowing = wrapper.scrollWidth > wrapper.clientWidth + 2;
    wrapper.classList.toggle("is-overflowing", overflowing);
    if (hint) hint.hidden = !overflowing;
    return overflowing;
  }

  function prepareScrollablePlot(chart, periodCount, options) {
    const opts = options || {};
    const profile = getResponsivePlotConfig(opts);
    const wrapper = chart ? chart.closest(".rigi-plot-scroll") : null;
    if (!chart || !wrapper) return profile;
    const availableWidth = Math.max(1, wrapper.clientWidth || window.innerWidth);
    const periods = Math.max(1, Number(periodCount) || 1);
    const pixelsPerPeriod = profile.mobile
      ? (opts.mobilePixelsPerPeriod || opts.pixelsPerPeriod || 54)
      : (profile.tablet
        ? (opts.tabletPixelsPerPeriod || opts.pixelsPerPeriod || 48)
        : (opts.desktopPixelsPerPeriod || opts.pixelsPerPeriod || 42));
    const calculatedWidth = periods * pixelsPerPeriod + profile.leftMargin + profile.rightMargin;
    const shouldScroll = periods > Number(opts.scrollThreshold || 12) && calculatedWidth > availableWidth + 2;
    const targetWidth = shouldScroll ? Math.ceil(calculatedWidth) : availableWidth;
    chart.style.width = shouldScroll ? targetWidth + "px" : "100%";
    chart.style.minWidth = shouldScroll ? targetWidth + "px" : "0";
    chart.style.maxWidth = "none";
    chart.style.height = profile.height + "px";
    wrapper.classList.toggle("is-scroll-enabled", shouldScroll);
    window.requestAnimationFrame(function () { updateOverflowHint(wrapper, opts.hint || null); });
    return profile;
  }

  function insertAfter(reference, node) {
    if (reference && reference.parentNode && node) reference.parentNode.insertBefore(node, reference.nextSibling);
  }

  function ensureVerticalHint(wrapper, text) {
    if (!wrapper || !wrapper.parentNode) return null;
    if (wrapper._rigiVerticalHint && document.body.contains(wrapper._rigiVerticalHint)) return wrapper._rigiVerticalHint;
    const hint = document.createElement("p");
    hint.className = "rigi-scroll-hint rigi-vertical-scroll-hint";
    hint.textContent = text || "Deslizá verticalmente para ver todos los proyectos ↓";
    hint.hidden = true;
    insertAfter(wrapper, hint);
    wrapper._rigiVerticalHint = hint;
    return hint;
  }

  function updateVerticalOverflow(wrapper, text) {
    if (!wrapper || !wrapper.classList.contains("rigi-plot-viewport--vertical")) return false;
    const hint = ensureVerticalHint(wrapper, text);
    const overflowing = wrapper.scrollHeight > wrapper.clientHeight + 2;
    wrapper.classList.toggle("is-vertical-overflowing", overflowing);
    if (hint) hint.hidden = !overflowing;
    return overflowing;
  }

  function enhanceStaticPlot(chart, options) {
    const opts = options || {};
    if (!chart) return;
    const host = chart.closest(".cell-output-display") || chart.parentElement;
    if (!host) return;
    host.classList.add("rigi-static-plot-host");
    if (opts.verticalScroll) {
      host.classList.add("rigi-plot-viewport--vertical");
      window.requestAnimationFrame(function () { updateVerticalOverflow(host, opts.verticalHint); });
    }
  }

  function lockPlotlyChart(chart) {
    if (!chart || typeof window.Plotly === "undefined" || typeof window.Plotly.relayout !== "function") return;
    const update = { dragmode: false };
    Object.keys(chart.layout || {}).forEach(function (key) {
      if (/^[xy]axis\d*$/.test(key)) update[key + ".fixedrange"] = true;
    });
    try { window.Plotly.relayout(chart, update); } catch (error) { /* R ya aplica el mismo bloqueo. */ }
  }

  function addInteractiveBadge(section) {
    if (!section) return;
    let heading = null;
    try { heading = section.querySelector(":scope > h2, :scope > h3"); }
    catch (error) { heading = section.querySelector("h2, h3"); }
    if (!heading || heading.querySelector(".interactive-badge")) return;
    const badge = document.createElement("span");
    badge.className = "interactive-badge";
    badge.textContent = "INTERACTIVO";
    heading.appendChild(badge);
  }

  function decorateInteractiveSections() {
    document.querySelectorAll(".plans-module, .impo-module").forEach(function (widget) {
      addInteractiveBadge(widget.closest("section"));
    });
    document.querySelectorAll(".js-plotly-plot, .rigi-project-cards, .dataTables_wrapper").forEach(function (widget) {
      if (widget.closest(".plans-module, .impo-module")) return;
      if (widget.closest(".rigi-timeline-desktop") && isMobile()) return;
      addInteractiveBadge(widget.closest("section"));
    });
    document.querySelectorAll(".rigi-timeline-desktop .js-plotly-plot").forEach(function (widget) {
      const section = widget.closest("section");
      let heading = null;
      try { heading = section ? section.querySelector(":scope > h2, :scope > h3") : null; }
      catch (error) { heading = section ? section.querySelector("h2, h3") : null; }
      const badge = heading ? heading.querySelector(".interactive-badge") : null;
      if (isMobile() && badge) badge.remove();
      if (!isMobile()) addInteractiveBadge(section);
    });
    document.querySelectorAll(".js-plotly-plot").forEach(lockPlotlyChart);
  }

  function syncDetailsAria(details) {
    if (!details) return;
    const summary = details.querySelector("summary");
    if (!summary) return;
    summary.setAttribute("aria-expanded", details.open ? "true" : "false");
  }

  function setupDetailsMenu(details) {
    if (!details || details.dataset.rigiReady === "true") return;
    details.dataset.rigiReady = "true";
    const sync = function () { syncDetailsAria(details); };
    details.addEventListener("toggle", sync);
    details.querySelectorAll("a[href^='#']").forEach(function (link) {
      link.addEventListener("click", function () { details.open = false; sync(); });
    });
    sync();
  }

  function setupSectionContents() {
    const source = document.querySelector(".page-subnav");
    if (!source) return;
    const details = document.createElement("details");
    details.className = "mobile-section-contents";
    const summary = document.createElement("summary");
    summary.textContent = "En esta sección";
    const nav = document.createElement("nav");
    nav.id = "mobile-section-links";
    nav.setAttribute("aria-label", "En esta sección");
    summary.setAttribute("aria-controls", nav.id);
    Array.from(source.childNodes).forEach(function (node) { nav.appendChild(node.cloneNode(true)); });
    details.appendChild(summary);
    details.appendChild(nav);
    source.insertAdjacentElement("afterend", details);
    setupDetailsMenu(details);
  }

  function setupActiveNavigation() {
    const links = Array.from(document.querySelectorAll(".page-subnav a[href^='#'], .mobile-section-contents a[href^='#']"));
    if (!links.length || !("IntersectionObserver" in window)) return;
    const byId = new Map();
    links.forEach(function (link) {
      const id = link.getAttribute("href").slice(1);
      if (!byId.has(id)) byId.set(id, []);
      byId.get(id).push(link);
    });
    const observer = new IntersectionObserver(function (entries) {
      const visible = entries.filter(function (entry) { return entry.isIntersecting; })
        .sort(function (a, b) { return a.boundingClientRect.top - b.boundingClientRect.top; });
      if (!visible.length) return;
      links.forEach(function (link) { link.removeAttribute("aria-current"); });
      const active = byId.get(visible[0].target.id) || [];
      active.forEach(function (link) { link.setAttribute("aria-current", "location"); });
      const mobileSummary = document.querySelector(".mobile-section-contents > summary");
      const activeLabel = active.length ? active[0].textContent.trim() : "";
      if (mobileSummary) {
        mobileSummary.textContent = activeLabel ? "En esta sección · " + activeLabel : "En esta sección";
      }
    }, { rootMargin: "-22% 0px -68% 0px", threshold: 0 });
    byId.forEach(function (_, id) {
      const section = document.getElementById(id);
      if (section) observer.observe(section);
    });
  }

  function setupAboutMonitor() {
    const container = document.querySelector(".about-monitor");
    const body = container ? container.querySelector(".about-monitor__body") : null;
    if (!container || !body) return;
    body.id = body.id || "about-monitor-description";
    const button = document.createElement("button");
    button.type = "button";
    button.className = "about-monitor__toggle";
    button.setAttribute("aria-controls", body.id);
    let expanded = false;
    const render = function () {
      const mobile = isMobile();
      button.hidden = !mobile;
      body.hidden = mobile && !expanded;
      button.setAttribute("aria-expanded", expanded ? "true" : "false");
      button.textContent = expanded ? "Ocultar descripción completa" : "Leer descripción completa";
    };
    button.addEventListener("click", function () { expanded = !expanded; render(); });
    container.insertBefore(button, body);
    if (typeof mobileQuery.addEventListener === "function") mobileQuery.addEventListener("change", render);
    else if (typeof mobileQuery.addListener === "function") mobileQuery.addListener(render);
    render();
  }

  function setupAccessibleDetails() {
    document.querySelectorAll(
      ".plans-multiselect, .impo-multiselect, .impo-project-dropdown, .rigi-milestone__details"
    ).forEach(setupDetailsMenu);
    document.addEventListener("keydown", function (event) {
      if (event.key !== "Escape") return;
      document.querySelectorAll("details[open]").forEach(function (details) {
        details.open = false;
        syncDetailsAria(details);
      });
      const collapse = document.querySelector(".navbar-collapse.show");
      const toggler = document.querySelector(".navbar-toggler[aria-expanded='true']");
      if (collapse && toggler) toggler.click();
    });
  }

  function resetTransientNavigation() {
    const closeNavbar = function () {
      const collapse = document.querySelector(".navbar-collapse.show");
      const toggler = document.querySelector(".navbar-toggler[aria-expanded='true']");
      if (collapse && toggler) toggler.click();
      document.querySelectorAll(".mobile-section-contents[open]").forEach(function (details) {
        details.open = false;
        syncDetailsAria(details);
      });
      document.querySelectorAll(".impo-project-dropdown[open]").forEach(function (details) {
        details.open = false;
        syncDetailsAria(details);
      });
    };
    window.addEventListener("pageshow", closeNavbar);
  }

  function setupBackToTop() {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "back-to-top";
    button.setAttribute("aria-label", "Volver al inicio de la página");
    button.textContent = "↑";
    button.hidden = true;
    button.addEventListener("click", function () {
      const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      window.scrollTo({ top: 0, behavior: reduced ? "auto" : "smooth" });
    });
    document.body.appendChild(button);
    const update = function () { button.hidden = window.scrollY < 700; };
    window.addEventListener("scroll", update, { passive: true });
    update();
  }

  function notifySubscribers() {
    subscribers.forEach(function (callback) {
      try { callback(); } catch (error) { window.setTimeout(function () { throw error; }, 0); }
    });
    document.querySelectorAll(".rigi-plot-viewport--vertical").forEach(function (wrapper) { updateVerticalOverflow(wrapper); });
    decorateInteractiveSections();
  }

  function scheduleResize() {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(notifySubscribers, 160);
  }

  function subscribe(key, callback) {
    subscribers.set(String(key), callback);
    return function () { subscribers.delete(String(key)); };
  }

  window.addEventListener("resize", scheduleResize, { passive: true });
  window.addEventListener("orientationchange", scheduleResize, { passive: true });
  document.addEventListener("DOMContentLoaded", function () {
    setupSectionContents();
    setupActiveNavigation();
    setupAboutMonitor();
    setupAccessibleDetails();
    resetTransientNavigation();
    setupBackToTop();
    decorateInteractiveSections();
    window.setTimeout(decorateInteractiveSections, 500);
  });

  window.RigiResponsive = {
    isMobile: isMobile,
    isTablet: isTablet,
    getResponsivePlotConfig: getResponsivePlotConfig,
    getPlotlyInteractionConfig: getPlotlyInteractionConfig,
    prepareScrollablePlot: prepareScrollablePlot,
    updateOverflowHint: updateOverflowHint,
    enhanceStaticPlot: enhanceStaticPlot,
    updateVerticalOverflow: updateVerticalOverflow,
    subscribe: subscribe
  };
})();
