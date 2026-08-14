(function () {
  "use strict";

  if (window.RigiResponsive) return;

  const mobileQuery = window.matchMedia("(max-width: 640px)");
  const tabletQuery = window.matchMedia("(max-width: 1100px)");
  const subscribers = new Map();
  let resizeTimer = null;

  function isMobile() {
    return mobileQuery.matches;
  }

  function isTablet() {
    return tabletQuery.matches;
  }

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

  function findHint(wrapper, explicitHint) {
    if (explicitHint) return explicitHint;
    const id = wrapper && wrapper.dataset ? wrapper.dataset.scrollHint : "";
    return id ? document.getElementById(id) : null;
  }

  function updateOverflowHint(wrapper, explicitHint) {
    if (!wrapper) return false;
    const hint = findHint(wrapper, explicitHint);
    const overflowing = isTablet() && wrapper.scrollWidth > wrapper.clientWidth + 2;
    wrapper.classList.toggle("is-overflowing", overflowing);
    if (hint) hint.hidden = !overflowing;
    return overflowing;
  }

  function prepareScrollablePlot(chart, periodCount, options) {
    const opts = options || {};
    const profile = getResponsivePlotConfig(opts);
    const wrapper = chart ? chart.closest(".rigi-plot-scroll") : null;
    if (!chart || !wrapper) return profile;

    const availableWidth = Math.max(1, wrapper.clientWidth || wrapper.parentElement.clientWidth || window.innerWidth);
    const periods = Math.max(1, Number(periodCount) || 1);
    const pixelsPerPeriod = profile.mobile
      ? (opts.mobilePixelsPerPeriod || opts.pixelsPerPeriod || 54)
      : (opts.tabletPixelsPerPeriod || opts.pixelsPerPeriod || 48);
    const scrollThreshold = Number(opts.scrollThreshold || 12);
    const calculatedWidth = periods * pixelsPerPeriod + profile.leftMargin + profile.rightMargin;
    const shouldScroll = profile.compact && periods > scrollThreshold && calculatedWidth > availableWidth + 2;
    const targetWidth = shouldScroll ? Math.ceil(calculatedWidth) : availableWidth;

    chart.style.width = shouldScroll ? targetWidth + "px" : "100%";
    chart.style.minWidth = shouldScroll ? targetWidth + "px" : "0";
    chart.style.maxWidth = "none";
    chart.style.height = profile.height + "px";
    wrapper.classList.toggle("is-scroll-enabled", shouldScroll);

    window.requestAnimationFrame(function () {
      updateOverflowHint(wrapper, opts.hint || null);
    });

    return profile;
  }

  function notifySubscribers() {
    subscribers.forEach(function (callback) {
      try {
        callback();
      } catch (error) {
        window.setTimeout(function () { throw error; }, 0);
      }
    });
  }

  function scheduleResize() {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(notifySubscribers, 160);
  }

  function subscribe(key, callback) {
    subscribers.set(String(key), callback);
    return function () {
      subscribers.delete(String(key));
    };
  }

  window.addEventListener("resize", scheduleResize, { passive: true });
  window.addEventListener("orientationchange", scheduleResize, { passive: true });

  window.RigiResponsive = {
    isMobile: isMobile,
    isTablet: isTablet,
    getResponsivePlotConfig: getResponsivePlotConfig,
    prepareScrollablePlot: prepareScrollablePlot,
    updateOverflowHint: updateOverflowHint,
    subscribe: subscribe
  };
})();
