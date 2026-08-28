#!/usr/bin/env python3
"""Static QA for the GitHub Pages interactive-module bootstrap."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
MODULE_SCRIPTS = [
    "assets/rigi-responsive.js",
    "assets/investment_modules.js",
    "assets/planes_inversion.js",
    "assets/importaciones.js",
]
REQUIRED_IDS = [
    "planes-inversion-module",
    "planes-inversion-data",
    "planes-annual-chart",
    "planes-cumulative-chart",
    "importaciones-module",
    "importaciones-data",
    "impo-sector-monthly-chart",
    "impo-sector-cumulative-chart",
    "impo-project-monthly-chart",
    "impo-project-cumulative-chart",
]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> int:
    quarto = yaml.safe_load(read("_quarto.yml"))
    workflow_text = read(".github/workflows/render.yml")
    workflow = yaml.safe_load(workflow_text)
    head_include = quarto["format"]["html"].get("include-in-header")
    bootstrap_partial = "_partials/setup-core.qmd"
    bootstrap_text = read(bootstrap_partial)
    plans_js = read("assets/planes_inversion.js")
    imports_js = read("assets/importaciones.js")
    approved_qmd = read("aprobados.qmd")
    plotly_dependency_source = read("R/05_planes_inversion.R")
    ranked_module_source = read("R/07_investment_modules.R")
    ranked_module_javascript = read("assets/investment_modules.js")
    encoding_helpers = read("R/01_load_data.R") + read("R/04_plots.R")
    encoding_test = read("tools/qa_encoding.R")
    modules_source = read("R/05_planes_inversion.R") + read("R/06_importaciones.R")

    git_check = subprocess.run(
        ["git", "ls-files", "--error-unmatch", bootstrap_partial],
        cwd=ROOT,
        check=False,
        capture_output=True,
    )
    bootstrap_tracked = git_check.returncode == 0 or not (ROOT / ".git").exists()

    pages = [ROOT / page for page in quarto["project"]["render"]]
    page_format_overrides = [
        page.name
        for page in pages
        if "\nformat:" in page.read_text(encoding="utf-8").split("---", 2)[1]
    ]

    push_paths = workflow[True]["push"]["paths"]
    packages = workflow["jobs"]["build"]["steps"][3]["with"]["packages"]
    source_script_tags = bootstrap_text.count(
        '<script src="assets/rigi-responsive.js" defer></script>'
    )

    checks = {
        "external_html_include_removed": head_include is None,
        "bootstrap_partial_exists": (ROOT / bootstrap_partial).is_file(),
        "bootstrap_partial_is_tracked": bootstrap_tracked,
        "responsive_script_loaded_once_in_sources": source_script_tags == 1,
        "no_page_format_overrides": not page_format_overrides,
        "project_site_url": quarto["website"]["site-url"].endswith("/RIGI/"),
        "all_module_scripts_are_resources": all(
            script in quarto["project"]["resources"] for script in MODULE_SCRIPTS
        ),
        "all_interactive_ids_are_generated": all(
            identifier in modules_source for identifier in REQUIRED_IDS
        ),
        "plans_wait_is_bounded": all(
            token in plans_js
            for token in ["INIT_MAX_ATTEMPTS", "initializationError", "console.error"]
        ) and "setTimeout(initPlansInvestment" not in plans_js,
        "imports_wait_is_bounded": all(
            token in imports_js
            for token in ["INIT_MAX_ATTEMPTS", "initializationError", "console.error"]
        ) and "setTimeout(initImportaciones" not in imports_js,
        "modules_remain_idempotent": all(
            'root.dataset.initialized === "true"' in source
            and 'root.dataset.initialized = "true"' in source
            for source in [plans_js, imports_js]
        ),
        "plotly_dependency_is_explicit": all(
            token in plotly_dependency_source
            for token in [
                "rigi_plotly_dependency <- function",
                "htmlwidgets::getDependency(",
                'package = "plotly"',
                "plotly::plot_ly(",
                "minimal_widget$dependencies",
                "htmltools::resolveDependencies(",
                "htmltools::attachDependencies(",
                'startsWith(dependency_names, "plotly-main")',
            ]
        ) and "plotly:::plotlyMainBundle" not in plotly_dependency_source,
        "plotly_dependency_called_once_before_modules": (
            approved_qmd.count("rigi_plotly_dependency()") == 1
            and approved_qmd.index("rigi_plotly_dependency()")
            < approved_qmd.index("make_planes_inversion_module(")
        ),
        "visible_accessible_initialization_failure": all(
            'No se pudo cargar el componente gráfico.' in source
            and 'className = "rigi-chart-initialization-error"' in source
            and 'setAttribute("role", "alert")' in source
            for source in [plans_js, imports_js]
        ),
        "ci_trigger_coverage": all(
            path in push_paths
            for path in ["*.qmd", "_partials/**", "assets/**", "R/**", "data/**", "downloads/**"]
        ),
        "ci_dependency_coverage": all(
            package in packages
            for package in [
                "any::jsonlite", "any::htmltools", "any::htmlwidgets",
                "any::plotly", "any::readxl", "any::writexl",
            ]
        ),
        "ci_removes_generated_state": all(
            token in workflow_text
            for token in [
                "rm -rf .quarto _freeze _site",
                "-name '*_cache'",
                "-name '*_files'",
                "quarto render",
            ]
        ),
        "utf8_helpers_are_centralized": all(
            token in encoding_helpers
            for token in [
                "rigi_as_utf8 <- function",
                "rigi_utf8_data_frame <- function",
                "rigi_sort_unique_text <- function",
                'rigi_sort_unique_text(values, "ordenamiento de filtros de proyectos")',
            ]
        ),
        "encoding_regression_test_present": all(
            token in encoding_test
            for token in [
                'Encoding(result) <- "unknown"',
                '"En evaluación"',
                "rigi_filter_values(split_provinces, split = TRUE)",
                "htmltools::renderTags(widget)$html",
            ]
        ),
        "ci_runs_encoding_regression": "Rscript tools/qa_encoding.R" in workflow_text,
        "data_contract_qa_present": (ROOT / "tools/qa_data_contract.py").is_file(),
        "data_contract_self_test_present": (
            ROOT / "tools/test_qa_data_contract.py"
        ).is_file(),
        "ci_runs_data_contract_qa": all(
            token in workflow_text
            for token in [
                "python3 tools/qa_data_contract.py",
                "python3 tools/test_qa_data_contract.py",
            ]
        ),
        "ci_runs_plotly_dependency_diagnostic": all(
            token in workflow_text
            for token in [
                "Rscript tools/diagnose_plotly_dependency.R",
                "quarto --version",
            ]
        ),
        "ci_checks_investment_javascript": (
            "node --check assets/investment_modules.js" in workflow_text
        ),
        "ci_verifies_new_rendered_modules": all(
            token in workflow_text
            for token in [
                "assets/investment_modules.js",
                "rigi-investment-approved-total-investment",
                "rigi-investment-approved-computable-assets",
                "rigi-investment-approved-two-year-commitment",
                "rigi-investment-evaluation-total-investment",
                "rigi-employment-approved-employment",
                "rigi-commitment-schedule",
                "rigi-peelp-share",
                "rigi-peelp-ranking",
                "rigi-comparison-territorial-sectoral",
            ]
        ),
        "ci_runs_peelp_cards_regression": "python3 tools/qa_peelp_cards.py" in workflow_text,
        "ci_runs_plotly_modules_regression": (
            "python3 tools/qa_plotly_modules.py" in workflow_text
        ),
        "ranked_modules_serialize_scalars_safely": all(
            token in ranked_module_source
            for token in [
                ".data$variable == .env$variable_name",
                'null = "null"',
                "share_total_value <-",
                "note_override_value <-",
            ]
        ) and all(
            token in ranked_module_javascript
            for token in [
                'typeof value !== "string"',
                'typeof config.noteOverride === "string"',
            ]
        ),
        "ci_runs_ranked_modules_regression": (
            "python3 tools/qa_ranked_modules.py" in workflow_text
        ),
        "ci_installs_browser_for_runtime_qa": all(
            token in workflow_text
            for token in [
                "python3 -m pip install",
                "python3 -m playwright install --with-deps chromium",
                'RIGI_REQUIRE_BROWSER: "1"',
            ]
        ),
        "ci_plotly_path_matches_generated_dependency": (
            "site_libs/plotly-main-" in workflow_text
            and 'startsWith(dependency_names, "plotly-main")' in plotly_dependency_source
        ),
        "ci_has_required_post_render_smoke_checks": all(
            token in workflow_text
            for token in [
                "test -s _site/aprobados.html",
                "test -s _site/assets/planes_inversion.js",
                "test -s _site/assets/importaciones.js",
                "grep -Fq 'planes-inversion-module' _site/aprobados.html",
                "grep -Fq 'importaciones-module' _site/aprobados.html",
            ]
        ),
        "quarto_cache_and_freeze_disabled": (
            quarto["execute"]["cache"] is False and quarto["execute"]["freeze"] is False
        ),
    }

    javascript = {}
    for script in MODULE_SCRIPTS:
        run = subprocess.run(
            ["node", "--check", str(ROOT / script)],
            check=False,
            capture_output=True,
            text=True,
        )
        javascript[script] = {"ok": run.returncode == 0, "stderr": run.stderr.strip()}
        checks[f"javascript_syntax_{Path(script).stem}"] = run.returncode == 0

    result = {
        "head_include": head_include,
        "bootstrap_partial": bootstrap_partial,
        "page_format_overrides": page_format_overrides,
        "checks": checks,
        "javascript": javascript,
        "failed": sorted(name for name, passed in checks.items() if not passed),
    }
    output = ROOT / "qa" / "github_pages_source_qa.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
