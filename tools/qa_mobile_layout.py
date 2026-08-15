#!/usr/bin/env python3
"""Source-level regression checks for the mobile chart layout."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    plots_r = (root / "R/04_plots.R").read_text(encoding="utf-8")
    imports_js = (root / "assets/importaciones.js").read_text(encoding="utf-8")
    responsive_js = (root / "assets/rigi-responsive.js").read_text(encoding="utf-8")
    css = (root / "styles.css").read_text(encoding="utf-8")

    checks = {
        "horizontal_mobile_left_margin_capped": "var mobileLeftCap" in plots_r,
        "horizontal_mobile_right_labels_reserved": "originalRight + 32" in plots_r,
        "horizontal_full_tooltips_preserved": "plotly::ggplotly(p, tooltip = \"text\")" in plots_r,
        "imports_mobile_period_width_compact": "mobilePixelsPerPeriod: 50" in imports_js,
        "imports_scroll_only_for_long_series": "scrollThreshold: 6" in imports_js,
        "imports_mobile_height_compact": "mobileHeight: 390" in imports_js,
        "imports_viewport_range_present": "function viewportYRange" in imports_js,
        "imports_viewport_scroll_throttled": "_rigiViewportScaleFrame" in imports_js,
        "imports_scroll_listener_passive": 'addEventListener("scroll", chart._rigiViewportScrollHandler, { passive: true })' in imports_js,
        "imports_listener_idempotent": "chart._rigiViewportWrapper !== wrapper" in imports_js,
        "imports_month_two_line_labels": 'monthLabel + "<br>" + year' in imports_js,
        "plotly_responsive": "responsive: true" in responsive_js,
        "plotly_scroll_zoom_disabled": "scrollZoom: false" in responsive_js,
        "plotly_double_click_disabled": "doubleClick: false" in responsive_js,
        "plotly_fixed_ranges": "fixedrange" in imports_js,
        "mobile_sticky_anchor_offset": "--rigi-mobile-anchor-gap" in css and "scroll-padding-top" in css,
        "mobile_import_chart_height_css": ".impo-chart {\n    min-height: 390px;" in css,
        "mobile_back_to_top_safe_area": "env(safe-area-inset-bottom)" in css,
        "css_braces_balanced": css.count("{") == css.count("}"),
    }

    result = {"checks": checks, "failed": [name for name, ok in checks.items() if not ok]}
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    return 1 if result["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
