#!/usr/bin/env python3
"""Regression QA for the custom Plotly modules on aprobados.html.

The default mode validates the rendered site and, when Playwright is available,
opens it in a real browser at the supported responsive widths.  ``--source-only``
is useful before rendering, but it intentionally does not replace the complete
post-render check used by CI.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import threading
from collections import Counter
from functools import partial
from html.parser import HTMLParser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "_site"
PAGE = SITE / "aprobados.html"
MAIN_XLSX = ROOT / "data" / "RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
EXPECTED_XLSX_SHA256 = "82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974"

MODULE_SCRIPTS = [
    ROOT / "assets" / "planes_inversion.js",
    ROOT / "assets" / "importaciones.js",
]
GRAPH_IDS = [
    "planes-annual-chart",
    "planes-cumulative-chart",
    "impo-sector-monthly-chart",
    "impo-sector-cumulative-chart",
    "impo-project-monthly-chart",
    "impo-project-cumulative-chart",
]
MODULE_IDS = ["planes-inversion-module", "importaciones-module"]
DATA_IDS = ["planes-inversion-data", "importaciones-data"]
REQUIRED_SOURCE_IDS = MODULE_IDS + DATA_IDS + GRAPH_IDS
VIEWPORTS = [1440, 1024, 768, 390, 375, 320]
BANNED_LOCAL_PATH = "/" + "Users/" + "lucasordonez/"
BANNED_FILE_SCHEME = "file" + "://"


class AprobadosParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: list[str] = []
        self.script_sources: list[str] = []
        self.json_payloads: dict[str, list[str]] = {}
        self._json_id: str | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        element_id = values.get("id")
        if element_id:
            self.ids.append(element_id)
        if tag.lower() != "script":
            return
        source = values.get("src")
        if source:
            self.script_sources.append(source)
        if element_id in DATA_IDS and values.get("type") == "application/json":
            self._json_id = element_id
            self.json_payloads[element_id] = []

    def handle_data(self, data: str) -> None:
        if self._json_id is not None:
            self.json_payloads[self._json_id].append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "script":
            self._json_id = None


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *args: object) -> None:
        return


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_texts() -> dict[str, str]:
    suffixes = {".R", ".qmd", ".yml", ".yaml", ".js", ".css", ".py"}
    out: dict[str, str] = {}
    for path in ROOT.rglob("*"):
        if path.is_file() and path.suffix in suffixes and "_site" not in path.parts:
            out[str(path.relative_to(ROOT))] = path.read_text(encoding="utf-8")
    return out


def validate_plans(rows: Any) -> tuple[bool, dict[str, Any]]:
    if not isinstance(rows, list) or not rows:
        return False, {"rows": 0, "years": []}
    years: list[int] = []
    valid = True
    for row in rows:
        try:
            year = int(row["anio"])
            amount = float(row["monto_mill_usd"])
            sector = str(row["sector"]).strip()
            subsector = str(row["subsector"]).strip()
        except (KeyError, TypeError, ValueError):
            valid = False
            continue
        years.append(year)
        valid = valid and amount >= 0 and bool(sector) and bool(subsector)
    observed = sorted(set(years))
    expected_period = 2024 in observed and 2034 in observed
    return valid and expected_period, {"rows": len(rows), "years": observed}


def validate_imports(rows: Any) -> tuple[bool, dict[str, Any]]:
    if not isinstance(rows, list) or not rows:
        return False, {"rows": 0, "projects": 0, "sectors": 0}
    projects: set[str] = set()
    sectors: set[str] = set()
    valid = True
    for row in rows:
        try:
            amount = float(row["fob_mill_usd"])
            project = str(row["proyecto"]).strip()
            sector = str(row["sector"]).strip()
        except (KeyError, TypeError, ValueError):
            valid = False
            continue
        projects.add(project)
        sectors.add(sector)
        valid = valid and amount >= 0 and bool(project) and bool(sector)
    return valid, {"rows": len(rows), "projects": len(projects), "sectors": len(sectors)}


def browser_qa() -> dict[str, Any]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as error:
        return {"available": False, "reason": f"Playwright no disponible: {error}"}

    server = ThreadingHTTPServer(
        ("127.0.0.1", 0),
        partial(QuietHandler, directory=str(SITE)),
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/aprobados.html"
    results: list[dict[str, Any]] = []

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            for width in VIEWPORTS:
                console_errors: list[str] = []
                page_errors: list[str] = []
                page = browser.new_page(viewport={"width": width, "height": 1000})
                page.on(
                    "console",
                    lambda message, output=console_errors: (
                        output.append(message.text) if message.type == "error" else None
                    ),
                )
                page.on("pageerror", lambda error, output=page_errors: output.append(str(error)))
                page.goto(url, wait_until="networkidle")
                page.wait_for_function(
                    """
                    () => {
                      const ids = %s;
                      return typeof window.Plotly !== "undefined" &&
                        document.querySelector("#planes-inversion-module")?.dataset.initialized === "true" &&
                        document.querySelector("#importaciones-module")?.dataset.initialized === "true" &&
                        ids.every((id) => {
                          const node = document.getElementById(id);
                          return node && (node.matches(".js-plotly-plot") || node.querySelector(".js-plotly-plot"));
                        });
                    }
                    """ % json.dumps(GRAPH_IDS),
                    timeout=30000,
                )

                if width == 1440:
                    page.locator("#plans-reset").click()
                    page.locator("#impo-sector-reset").click()
                    page.locator("#impo-project-reset").click()
                    page.wait_for_timeout(250)

                state = page.evaluate(
                    """
                    (graphIds) => {
                      const boxes = Object.fromEntries(graphIds.map((id) => {
                        const node = document.getElementById(id);
                        const box = node?.getBoundingClientRect();
                        return [id, {
                          plots: node ? Number(node.matches(".js-plotly-plot")) + node.querySelectorAll(".js-plotly-plot").length : 0,
                          svg: node?.querySelectorAll("svg").length || 0,
                          width: box?.width || 0,
                          height: box?.height || 0
                        }];
                      }));
                      return {
                        plotly: typeof window.Plotly !== "undefined",
                        plansInitialized: document.getElementById("planes-inversion-module")?.dataset.initialized || null,
                        importsInitialized: document.getElementById("importaciones-module")?.dataset.initialized || null,
                        plansError: document.getElementById("planes-inversion-module")?.dataset.initializationError || null,
                        importsError: document.getElementById("importaciones-module")?.dataset.initializationError || null,
                        visibleErrorMessages: document.querySelectorAll(".rigi-chart-initialization-error").length,
                        pageHorizontalOverflow: document.documentElement.scrollWidth - window.innerWidth,
                        graphs: boxes
                      };
                    }
                    """,
                    GRAPH_IDS,
                )
                graphs_ok = all(
                    graph["plots"] == 1
                    and graph["svg"] > 0
                    and graph["width"] > 0
                    and graph["height"] > 0
                    for graph in state["graphs"].values()
                )
                ok = all(
                    [
                        state["plotly"],
                        state["plansInitialized"] == "true",
                        state["importsInitialized"] == "true",
                        state["plansError"] is None,
                        state["importsError"] is None,
                        state["visibleErrorMessages"] == 0,
                        state["pageHorizontalOverflow"] <= 2,
                        graphs_ok,
                        not console_errors,
                        not page_errors,
                    ]
                )
                results.append(
                    {
                        "width": width,
                        "ok": ok,
                        "state": state,
                        "console_errors": console_errors,
                        "page_errors": page_errors,
                    }
                )
                page.close()
            browser.close()
    except Exception as error:  # browser availability differs across local systems
        return {"available": False, "reason": f"No se pudo ejecutar Chromium: {error}"}
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    return {
        "available": True,
        "url": url,
        "viewports": results,
        "ok": all(result["ok"] for result in results),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()

    checks: dict[str, bool] = {}
    details: dict[str, Any] = {}
    checks["main_xlsx_exists"] = MAIN_XLSX.is_file()
    actual_checksum = sha256(MAIN_XLSX) if MAIN_XLSX.is_file() else None
    checks["main_xlsx_checksum"] = actual_checksum == EXPECTED_XLSX_SHA256
    details["main_xlsx_sha256"] = actual_checksum

    javascript: dict[str, Any] = {}
    for path in MODULE_SCRIPTS:
        key = str(path.relative_to(ROOT))
        checks[f"exists_{path.stem}"] = path.is_file()
        run = subprocess.run(
            ["node", "--check", str(path)],
            check=False,
            capture_output=True,
            text=True,
        ) if path.is_file() else None
        javascript[key] = {
            "ok": bool(run and run.returncode == 0),
            "stderr": run.stderr.strip() if run else "archivo ausente",
        }
        checks[f"syntax_{path.stem}"] = javascript[key]["ok"]

    plans_r = (ROOT / "R" / "05_planes_inversion.R").read_text(encoding="utf-8")
    plotly_helper_r = plans_r.split("planes_inversion_path <-", 1)[0]
    diagnostic_r_path = ROOT / "tools" / "diagnose_plotly_dependency.R"
    diagnostic_r = (
        diagnostic_r_path.read_text(encoding="utf-8")
        if diagnostic_r_path.is_file()
        else ""
    )
    imports_r = (ROOT / "R" / "06_importaciones.R").read_text(encoding="utf-8")
    approved_qmd = (ROOT / "aprobados.qmd").read_text(encoding="utf-8")
    combined_modules = plans_r + imports_r
    checks["six_graph_containers_in_sources"] = all(
        identifier in combined_modules for identifier in GRAPH_IDS
    )
    checks["all_module_ids_in_sources"] = all(
        identifier in combined_modules for identifier in REQUIRED_SOURCE_IDS
    )
    checks["explicit_plotly_dependency_in_source"] = all(
        token in plotly_helper_r
        for token in [
            "rigi_plotly_dependency <- function",
            "htmlwidgets::getDependency(",
            'package = "plotly"',
            "htmltools::attachDependencies(",
        ]
    )
    checks["dynamic_plotly_dependencies_extracted"] = all(
        token in plotly_helper_r
        for token in [
            "plotly::plot_ly(",
            "minimal_widget$dependencies",
            "dynamic_dependencies",
        ]
    )
    checks["plotly_dependencies_are_resolved"] = (
        "htmltools::resolveDependencies(" in plotly_helper_r
    )
    checks["plotly_main_is_behaviorally_validated"] = all(
        token in plotly_helper_r
        for token in [
            'startsWith(dependency_names, "plotly-main")',
            'plotly-latest\\\\.min\\\\.js$',
            "has_plotly_main",
        ]
    )
    checks["plotly_dependency_has_no_private_or_manual_bundle"] = all(
        token not in plotly_helper_r
        for token in [
            "plotly:::plotlyMainBundle",
            "htmltools::htmlDependency(",
            "cdnjs",
            "cdn.plot.ly",
            "https://",
            "http://",
        ]
    )
    checks["plotly_version_and_path_are_not_hardcoded"] = not re.search(
        r"plotly-main-\d|version\s*=",
        plotly_helper_r,
    )
    checks["r_dependency_diagnostic_present"] = all(
        token in diagnostic_r
        for token in [
            "summarize_dependencies <- function",
            "minimal_widget$dependencies",
            "rigi_plotly_dependencies()",
            'utils::packageVersion("plotly")',
            'utils::packageVersion("htmlwidgets")',
            'utils::packageVersion("htmltools")',
        ]
    )
    checks["dependency_called_before_plans_module"] = (
        approved_qmd.count("rigi_plotly_dependency()") == 1
        and approved_qmd.index("rigi_plotly_dependency()")
        < approved_qmd.index("make_planes_inversion_module(")
    )
    checks["accessible_failure_message"] = all(
        'No se pudo cargar el componente gráfico.' in path.read_text(encoding="utf-8")
        and 'className = "rigi-chart-initialization-error"' in path.read_text(encoding="utf-8")
        and 'setAttribute("role", "alert")' in path.read_text(encoding="utf-8")
        for path in MODULE_SCRIPTS
    )
    checks["bounded_retry_and_idempotence"] = all(
        "INIT_MAX_ATTEMPTS" in path.read_text(encoding="utf-8")
        and 'root.dataset.initialized === "true"' in path.read_text(encoding="utf-8")
        and 'root.dataset.initialized = "true"' in path.read_text(encoding="utf-8")
        for path in MODULE_SCRIPTS
    )

    texts = source_texts()
    checks["no_absolute_local_paths_in_sources"] = not any(
        BANNED_LOCAL_PATH in text for text in texts.values()
    )
    checks["no_file_urls_in_sources"] = not any(
        BANNED_FILE_SCHEME in text for text in texts.values()
    )

    browser: dict[str, Any] = {"available": False, "reason": "source-only"}
    if not args.source_only:
        checks["rendered_aprobados_exists"] = PAGE.is_file() and PAGE.stat().st_size > 0
        if PAGE.is_file():
            html = PAGE.read_text(encoding="utf-8")
            html_parser = AprobadosParser()
            html_parser.feed(html)
            duplicate_ids = sorted(
                identifier
                for identifier, count in Counter(html_parser.ids).items()
                if count > 1
            )
            plotly_sources = [
                source
                for source in html_parser.script_sources
                if "site_libs/plotly-main-" in source
            ]
            checks["plotly_loaded_once_in_html"] = len(plotly_sources) == 1
            details["plotly_sources"] = plotly_sources

            plotly_files: list[str] = []
            for source in plotly_sources:
                source_path = unquote(urlsplit(source).path)
                if source_path.startswith("/"):
                    continue
                candidate = SITE / source_path
                if candidate.is_file() and candidate.stat().st_size > 0:
                    plotly_files.append(str(candidate.relative_to(SITE)))
            checks["plotly_javascript_exists_in_site_libs"] = len(plotly_files) == 1
            details["plotly_files"] = plotly_files

            try:
                plotly_index = html_parser.script_sources.index(plotly_sources[0])
                plans_index = html_parser.script_sources.index("assets/planes_inversion.js")
                imports_index = html_parser.script_sources.index("assets/importaciones.js")
                responsive_index = html_parser.script_sources.index("assets/rigi-responsive.js")
                correct_order = plotly_index < responsive_index < plans_index < imports_index
            except (IndexError, ValueError):
                correct_order = False
            checks["plotly_loads_before_custom_modules"] = correct_order
            checks["custom_module_scripts_not_duplicated"] = all(
                html_parser.script_sources.count(source) == 1
                for source in [
                    "assets/rigi-responsive.js",
                    "assets/planes_inversion.js",
                    "assets/importaciones.js",
                ]
            )
            checks["no_duplicate_ids_in_aprobados"] = not duplicate_ids
            details["duplicate_ids"] = duplicate_ids
            checks["no_absolute_local_paths_in_html"] = BANNED_LOCAL_PATH not in html
            checks["no_file_urls_in_html"] = BANNED_FILE_SCHEME not in html
            checks["all_required_ids_rendered"] = all(
                identifier in html_parser.ids for identifier in REQUIRED_SOURCE_IDS
            )

            parsed_data: dict[str, Any] = {}
            for identifier in DATA_IDS:
                try:
                    parsed_data[identifier] = json.loads(
                        "".join(html_parser.json_payloads.get(identifier, []))
                    )
                except json.JSONDecodeError:
                    parsed_data[identifier] = None
            plans_ok, plans_detail = validate_plans(parsed_data.get("planes-inversion-data"))
            imports_ok, imports_detail = validate_imports(parsed_data.get("importaciones-data"))
            checks["plans_json_nonempty_and_valid"] = plans_ok
            checks["imports_json_nonempty_and_valid"] = imports_ok
            details["plans_data"] = plans_detail
            details["imports_data"] = imports_detail

            browser = browser_qa()
            browser_required = (
                os.environ.get("RIGI_REQUIRE_BROWSER") == "1"
                or os.environ.get("CI", "").lower() == "true"
            )
            checks["browser_runtime_initialization"] = (
                browser.get("ok", False) if browser.get("available") else not browser_required
            )
        else:
            for name in [
                "plotly_loaded_once_in_html",
                "plotly_javascript_exists_in_site_libs",
                "plotly_loads_before_custom_modules",
                "custom_module_scripts_not_duplicated",
                "no_duplicate_ids_in_aprobados",
                "no_absolute_local_paths_in_html",
                "no_file_urls_in_html",
                "all_required_ids_rendered",
                "plans_json_nonempty_and_valid",
                "imports_json_nonempty_and_valid",
                "browser_runtime_initialization",
            ]:
                checks[name] = False

    failed = sorted(name for name, passed in checks.items() if not passed)
    result = {
        "mode": "source-only" if args.source_only else "rendered",
        "checks": checks,
        "details": details,
        "javascript": javascript,
        "browser": browser,
        "failed": failed,
    }
    output_name = "plotly_modules_source_qa.json" if args.source_only else "plotly_modules_qa.json"
    output = ROOT / "qa" / output_name
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
