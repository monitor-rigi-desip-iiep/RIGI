#!/usr/bin/env python3
"""Static regression checks for the final RIGI interface refinements."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


index = read("index.qmd")
approved = read("aprobados.qmd")
comparison = read("comparacion.qmd")
methodology = read("metodologia.qmd")
plots = read("R/04_plots.R")
modules = read("R/07_investment_modules.R")
javascript = read("assets/investment_modules.js")
quarto = read("_quarto.yml")
workflow = read(".github/workflows/render.yml")

card_start = plots.index("make_rigi_project_card <- function")
card_end = plots.index("make_rigi_project_cards <- function")
card_source = plots[card_start:card_end]

public_sources = "\n".join(
    read(path)
    for path in (
        "index.qmd",
        "aprobados.qmd",
        "evaluacion.qmd",
        "comparacion.qmd",
        "base-datos.qmd",
        "metodologia.qmd",
        "R/04_plots.R",
        "R/07_investment_modules.R",
        "_quarto.yml",
    )
)

expected_sha = "82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974"
source_xlsx = ROOT / "data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
actual_sha = hashlib.sha256(source_xlsx.read_bytes()).hexdigest()

checks = {
    "source_xlsx_unchanged": actual_sha == expected_sha,
    "approved_total_summary_label": "Inversión total de proyectos aprobados" in plots,
    "surveyed_total_scope_note": (
        "Incluye proyectos aprobados y en evaluación con información disponible." in plots
    ),
    "hero_meta_removed_from_index": "hero-meta-grid" not in index,
    "single_card_metric": card_source.count('htmltools::tags$span("Inversión total")') == 1,
    "card_assets_metric_removed": "Inversión en activos computables" not in card_source,
    "card_commitment_metric_removed": (
        "Inversión comprometida en activos computables" not in card_source
    ),
    "assets_metric_preserved_elsewhere": "Inversión en activos computables" in approved,
    "commitment_metric_preserved_elsewhere": (
        "Inversión comprometida en activos computables" in approved
    ),
    "schedule_tabs_present": all(
        marker in modules
        for marker in (
            "Compromiso de inversión de los primeros dos años",
            "Fecha límite para alcanzar la inversión mínima",
            "data-schedule-limit",
            "data-schedule-view",
        )
    ),
    "employment_interactive_module": (
        "make_employment_explorer(" in approved
        and "data-ranked-module" in modules
        and 'value_type = "employment"' in modules
    ),
    "comparison_interactive_module": (
        "make_comparison_explorer(tablas)" in comparison
        and "data-comparison-module" in modules
        and "data-comparison-limit" in modules
    ),
    "derived_dictionary_section_absent": (
        "Variables derivadas del Monitor" not in methodology
        and "Variables derivadas del Monitor" not in modules
    ),
    "public_dictionary_exclusions": all(
        variable in modules
        for variable in (
            "justificacion_preexistencia_boletin_oficial",
            "clasificacion_preexistencia_boletin_oficial",
        )
    ) and "dplyr::filter(!variable %in% excluded)" in modules,
    "utf8_helpers_preserved": all(
        helper in read("R/01_load_data.R") + read("R/02_clean_data.R") + plots
        for helper in ("rigi_as_utf8", "rigi_utf8_data_frame", "rigi_sort_unique_text")
    ),
    "encoding_test_preserved": (ROOT / "tools/qa_encoding.R").is_file(),
    "pending_approval_absent": "Pendiente de aprobación" not in public_sources,
    "author_footer_preserved": "@_LucasOrdoñez" in quarto,
    "shared_javascript_loaded_once": quarto.count("assets/investment_modules.js") == 1,
    "shared_component_initializers": all(
        marker in javascript
        for marker in (
            "initRankedModule",
            "initScheduleModule",
            "initComparisonModule",
        )
    ),
    "workflow_runs_final_ui_qa": "python3 tools/qa_final_ui_refinements.py" in workflow,
}

js_files = sorted((ROOT / "assets").glob("*.js"))
javascript_results = {}
for path in js_files:
    result = subprocess.run(
        ["node", "--check", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    javascript_results[str(path.relative_to(ROOT))] = {
        "ok": result.returncode == 0,
        "stderr": result.stderr.strip(),
    }
    checks[f"javascript_syntax_{path.stem}"] = result.returncode == 0

failed = sorted(name for name, passed in checks.items() if not passed)
report = {
    "checks": checks,
    "xlsx_sha256": actual_sha,
    "javascript": javascript_results,
    "failed": failed,
}
(ROOT / "qa").mkdir(exist_ok=True)
serialized = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
(ROOT / "qa" / "final_ui_source_qa.json").write_text(serialized, encoding="utf-8")
print(serialized, end="")
sys.exit(1 if failed else 0)
