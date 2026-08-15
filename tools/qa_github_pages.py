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
    modules_source = read("R/05_planes_inversion.R") + read("R/06_importaciones.R")

    bootstrap_tracked = subprocess.run(
        ["git", "ls-files", "--error-unmatch", bootstrap_partial],
        cwd=ROOT,
        check=False,
        capture_output=True,
    ).returncode == 0

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
            for token in ["rm -rf .quarto _freeze _site", "-name '*_cache'", "quarto render"]
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
