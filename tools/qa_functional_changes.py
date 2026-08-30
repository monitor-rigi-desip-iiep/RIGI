#!/usr/bin/env python3
"""Static QA for the functional corrections requested in August 2026."""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> int:
    quarto = yaml.safe_load(read("_quarto.yml"))
    workflow = yaml.safe_load(read(".github/workflows/render.yml"))
    plans_r = read("R/05_planes_inversion.R")
    plans_js = read("assets/planes_inversion.js")
    imports_r = read("R/06_importaciones.R")
    imports_js = read("assets/importaciones.js")
    responsive_js = read("assets/rigi-responsive.js")
    plots_r = read("R/04_plots.R")
    timeline_r = plots_r.split("plot_timeline <-", 1)[1].split("make_datatable <-", 1)[0]
    styles = read("styles.css")
    index = read("index.qmd")
    evaluation = read("evaluacion.qmd")
    approved = read("aprobados.qmd")
    ranked_r = read("R/07_investment_modules.R")
    ranked_js = read("assets/investment_modules.js")

    push_paths = workflow[True]["push"]["paths"]
    packages = workflow["jobs"]["build"]["steps"][3]["with"]["packages"]

    checks = {
        "plans_default_start_2024": "default_year_start" in plans_r and "2024L" in plans_r,
        "plans_default_end_2034": "default_year_end" in plans_r and "2034L" in plans_r,
        "plans_defaults_exposed_to_js": "data-default-year-start" in plans_r and "data-default-year-end" in plans_r,
        "plans_reset_uses_defaults": "yearStart.value = String(defaultStartYear)" in plans_js and "yearEnd.value = String(defaultEndYear)" in plans_js,
        "timeline_has_no_amount_annotations": "timeline_annotations" not in timeline_r and "monto_label" not in timeline_r,
        "timeline_keeps_amount_tooltip": '"<br>Monto: ", fmt_currency_mill(monto_usd_mill' in timeline_r,
        "timeline_help_updated": all(token in evaluation for token in [
            "Los proyectos se ordenan desde la presentación más reciente.",
            "Cada entrada muestra la fecha de presentación relevada, el sector y el monto informado.",
        ]),
        "timeline_uses_single_vertical_component": (
            "rigi-timeline-desktop" not in evaluation
            and "plot_timeline(" not in evaluation
            and evaluation.count("make_mobile_timeline(") == 1
        ),
        "timeline_vertical_component_is_universal": (
            ".rigi-timeline-mobile {\n  display: block;" in styles
            and "max-width: 900px;" in styles
            and "@media (max-width: 719px) {\n  .rigi-timeline-desktop" not in styles
        ),
        "hero_publication_label_removed": "PUBLICACIÓN ESTADÍSTICA" not in index,
        "imports_dropdown_markup": all(token in imports_r for token in [
            "impo-project-details", "impo-project-summary", "impo-project-search",
            "impo-project-options", "impo-project-option-input"
        ]),
        "imports_chips_removed": "impo-project-chips" not in imports_r and ".impo-project-chip" not in imports_js,
        "imports_multiple_selection": "selectedProjectInputs" in imports_js and "compatibleProjectInputs" in imports_js,
        "imports_search": "filterProjectOptions" in imports_js and "normalizeProjectSearch" in imports_js,
        "imports_escape_and_aria": ".impo-project-dropdown" in responsive_js and "aria-expanded" in responsive_js,
        "milestones_use_details": "rigi-milestones--accordion" in plots_r and plots_r.count("htmltools::tags$details(") >= 2,
        "milestones_metadata_preserved": all(token in plots_r for token in [
            '"Sector", sector', '"Provincia", province', '"Monto", amount',
            '"Presentación", presentation_date', '"Titular", owner'
        ]),
        "sticky_subnavigation": "position: sticky !important" in styles and ".mobile-section-contents" in styles,
        "no_global_horizontal_scroll_container": "overflow-x: clip" in styles,
        "ci_clean_render": quarto["execute"]["cache"] is False and quarto["execute"]["freeze"] is False,
        "ci_trigger_coverage": all(path in push_paths for path in [
            "*.qmd", "_partials/**", "assets/**", "R/**", "data/**", "downloads/**"
        ]),
        "ci_package_coverage": all(package in packages for package in [
            "any::jsonlite", "any::htmltools", "any::htmlwidgets", "any::plotly",
            "any::readxl", "any::writexl"
        ]),
        "project_resources": all(resource in quarto["project"]["resources"] for resource in [
            "assets/rigi-responsive.js", "assets/investment_modules.js",
            "assets/planes_inversion.js", "assets/importaciones.js"
        ]),
        "plotly_dependency_explicit_and_ordered": all(token in plans_r for token in [
            "rigi_plotly_dependency <- function",
            "htmlwidgets::getDependency(",
            'package = "plotly"',
            "plotly::plot_ly(",
            "minimal_widget$dependencies",
            "htmltools::resolveDependencies(",
            "htmltools::attachDependencies(",
            'startsWith(dependency_names, "plotly-main")',
        ]) and "plotly:::plotlyMainBundle" not in plans_r
        and approved.count("rigi_plotly_dependency()") == 1
        and approved.index("rigi_plotly_dependency()") < approved.index("make_planes_inversion_module("),
        "plotly_failure_is_visible_and_accessible": all(
            'No se pudo cargar el componente gráfico.' in source
            and 'setAttribute("role", "alert")' in source
            for source in [plans_js, imports_js]
        ),
        "ci_runs_rendered_plotly_qa": "python3 tools/qa_plotly_modules.py" in read(".github/workflows/render.yml"),
        "ci_runs_plotly_dependency_diagnostic": "Rscript tools/diagnose_plotly_dependency.R" in read(".github/workflows/render.yml"),
        "ranked_modules_reject_object_coercion": all(token in ranked_r for token in [
            ".data$variable == .env$variable_name",
            'null = "null"',
            "share_total_value <-",
            "note_override_value <-",
        ]) and all(token in ranked_js for token in [
            'typeof value !== "string"',
            'typeof config.noteOverride === "string"',
        ]),
        "ci_runs_ranked_modules_qa": "python3 tools/qa_ranked_modules.py" in read(".github/workflows/render.yml"),
    }

    js_results = {}
    for relative in [
        "assets/rigi-responsive.js", "assets/investment_modules.js",
        "assets/planes_inversion.js", "assets/importaciones.js"
    ]:
        result = subprocess.run(
            ["node", "--check", str(ROOT / relative)],
            check=False,
            capture_output=True,
            text=True,
        )
        js_results[relative] = {
            "ok": result.returncode == 0,
            "stderr": result.stderr.strip(),
        }
        checks[f"javascript_syntax_{Path(relative).stem}"] = result.returncode == 0

    expected_ids = [
        "planes-inversion-module", "planes-inversion-data", "planes-annual-chart",
        "planes-cumulative-chart", "importaciones-module", "importaciones-data",
        "impo-sector-monthly-chart", "impo-sector-cumulative-chart",
        "impo-project-monthly-chart", "impo-project-cumulative-chart",
    ]
    combined_modules = plans_r + imports_r
    checks["interactive_module_ids_in_sources"] = all(identifier in combined_modules for identifier in expected_ids)

    result = {
        "checks": checks,
        "javascript": js_results,
        "failed": sorted(name for name, ok in checks.items() if not ok),
    }
    output = ROOT / "qa" / "functional_source_qa.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
