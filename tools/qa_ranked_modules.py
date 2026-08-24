#!/usr/bin/env python3
"""Regression QA for ranked investment and employment modules.

The default mode validates the rendered pages and, when Playwright is
available, exercises every view and row limit at the supported widths.
``--source-only`` keeps the source checks available before a Quarto render.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import threading
from collections import Counter
from functools import partial
from html.parser import HTMLParser
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "_site"
MAIN_XLSX = ROOT / "data" / "RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
EXPECTED_XLSX_SHA256 = "82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974"
R_SOURCE = ROOT / "R" / "07_investment_modules.R"
JS_SOURCE = ROOT / "assets" / "investment_modules.js"
WORKFLOW = ROOT / ".github" / "workflows" / "render.yml"
VIEWPORTS = [1440, 1024, 768, 390, 375, 320]
FORBIDDEN_TEXT_RE = re.compile(r"\[object\s+object\]", re.IGNORECASE)

PAGE_MODULES = {
    "aprobados.html": [
        "rigi-investment-approved-total-investment",
        "rigi-investment-approved-computable-assets",
        "rigi-investment-approved-two-year-commitment",
        "rigi-employment-approved-employment",
    ],
    "evaluacion.html": [
        "rigi-investment-evaluation-total-investment",
    ],
}

EXPECTED_TITLES = {
    "rigi-investment-approved-total-investment": "Inversión total",
    "rigi-investment-approved-computable-assets": "Inversión en activos computables",
    "rigi-investment-approved-two-year-commitment": (
        "Inversión comprometida en activos computables — primeros 2 años"
    ),
    "rigi-employment-approved-employment": "Empleo informado",
    "rigi-investment-evaluation-total-investment": "Inversión total",
}


class RankedPageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: List[str] = []
        self.configs: Dict[str, Any] = {}
        self._active_module: Optional[str] = None
        self._json_module: Optional[str] = None
        self._json_buffer: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]) -> None:
        values = dict(attrs)
        element_id = values.get("id")
        if element_id:
            self.ids.append(element_id)
        if tag.lower() == "section" and element_id in EXPECTED_TITLES:
            self._active_module = element_id
        if (
            tag.lower() == "script"
            and self._active_module
            and "data-ranked-data" in values
        ):
            self._json_module = self._active_module
            self._json_buffer = []

    def handle_data(self, data: str) -> None:
        if self._json_module:
            self._json_buffer.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() == "script" and self._json_module:
            raw = "".join(self._json_buffer)
            try:
                self.configs[self._json_module] = json.loads(raw)
            except json.JSONDecodeError as error:
                self.configs[self._json_module] = {"__json_error__": str(error)}
            self._json_module = None
            self._json_buffer = []
        if tag.lower() == "section" and self._active_module:
            self._active_module = None


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *args: object) -> None:
        return


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


def validate_config(module_id: str, config: Any) -> Tuple[bool, Dict[str, Any]]:
    detail: Dict[str, Any] = {"module_id": module_id}
    if not isinstance(config, dict) or "__json_error__" in config:
        detail["reason"] = "JSON ausente o inválido"
        return False, detail

    scalar_strings = [
        "title", "description", "universe", "color",
        "valueType", "defaultLimit", "defaultView",
    ]
    scalar_types_ok = all(
        isinstance(config.get(key), str) and bool(config[key].strip())
        for key in scalar_strings
    )
    share_total = config.get("shareTotal")
    note_override = config.get("noteOverride")
    optional_types_ok = (
        (share_total is None or is_number(share_total))
        and (
            note_override is None
            or (isinstance(note_override, str) and bool(note_override.strip()))
        )
    )
    expected_title = EXPECTED_TITLES[module_id]
    metadata_ok = (
        config.get("title") == expected_title
        and config.get("title") != "VPU"
        and "Vehículo de Proyecto Único" not in str(config.get("description", ""))
    )

    views = config.get("views")
    views_ok = isinstance(views, dict) and all(
        view in views and isinstance(views[view], list)
        for view in ["project", "sector", "province"]
    )
    row_errors: List[Dict[str, Any]] = []
    totals: Dict[str, float] = {}
    if views_ok:
        for view_name in ["project", "sector", "province"]:
            total = 0.0
            for index, row in enumerate(views[view_name]):
                row_ok = (
                    isinstance(row, dict)
                    and isinstance(row.get("label"), str)
                    and bool(row["label"].strip())
                    and is_number(row.get("value"))
                    and isinstance(row.get("count"), int)
                    and not isinstance(row.get("count"), bool)
                )
                if not row_ok:
                    row_errors.append({"view": view_name, "index": index, "row": row})
                elif row["value"] >= 0:
                    total += float(row["value"])
            totals[view_name] = total
    rows_ok = views_ok and not row_errors and all(total > 0 for total in totals.values())

    detail.update(
        {
            "title": config.get("title"),
            "description": config.get("description"),
            "shareTotal": share_total,
            "noteOverride": note_override,
            "scalar_types_ok": scalar_types_ok,
            "optional_types_ok": optional_types_ok,
            "metadata_ok": metadata_ok,
            "views_ok": views_ok,
            "row_errors": row_errors[:5],
            "totals": totals,
        }
    )
    return all([scalar_types_ok, optional_types_ok, metadata_ok, views_ok, rows_ok]), detail


def browser_qa() -> Dict[str, Any]:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError as error:
        return {"available": False, "reason": "Playwright no disponible: {}".format(error)}

    server = ThreadingHTTPServer(
        ("127.0.0.1", 0),
        partial(QuietHandler, directory=str(SITE)),
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    results: List[Dict[str, Any]] = []

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            for page_name, module_ids in PAGE_MODULES.items():
                url = "http://127.0.0.1:{}/{}".format(server.server_port, page_name)
                for width in VIEWPORTS:
                    console_errors: List[str] = []
                    page_errors: List[str] = []
                    page = browser.new_page(viewport={"width": width, "height": 1000})
                    page.on(
                        "console",
                        lambda message, output=console_errors: (
                            output.append(message.text) if message.type == "error" else None
                        ),
                    )
                    page.on(
                        "pageerror",
                        lambda error, output=page_errors: output.append(str(error)),
                    )
                    page.goto(url, wait_until="networkidle")
                    page.wait_for_function(
                        """
                        (ids) => ids.every((id) =>
                          document.getElementById(id)?.dataset.rankedReady === "true"
                        )
                        """,
                        module_ids,
                        timeout=30000,
                    )
                    state = page.evaluate(
                        r"""
                        (ids) => {
                          const forbidden = /\[object\s+object\]/i;
                          const states = [];
                          ids.forEach((id) => {
                            const root = document.getElementById(id);
                            const source = root?.querySelector("[data-ranked-data]");
                            const config = source ? JSON.parse(source.textContent) : null;
                            const buttons = Array.from(root?.querySelectorAll("[data-ranked-view]") || []);
                            const limit = root?.querySelector("[data-ranked-limit]");
                            const chart = root?.querySelector("[data-ranked-chart]");
                            const moduleStates = [];
                            buttons.forEach((button) => {
                              button.click();
                              const view = button.dataset.rankedView;
                              Array.from(limit.options).forEach((option) => {
                                limit.value = option.value;
                                limit.dispatchEvent(new Event("change", { bubbles: true }));
                                const rows = Array.from(chart.querySelectorAll(".rigi-investment-row"));
                                const expected = option.value === "all"
                                  ? config.views[view].length
                                  : Math.min(Number(option.value), config.views[view].length);
                                const renderedLabels = rows.map((row) =>
                                  row.querySelector(".rigi-investment-row__label")?.textContent || ""
                                );
                                const renderedValues = rows.map((row) =>
                                  row.querySelector(".rigi-investment-row__value")?.textContent || ""
                                );
                                const attributes = rows.flatMap((row) => [
                                  row.getAttribute("title") || "",
                                  row.getAttribute("aria-label") || ""
                                ]);
                                moduleStates.push({
                                  view,
                                  limit: option.value,
                                  rows: rows.length,
                                  expected,
                                  uniqueLabels: new Set(renderedLabels).size === renderedLabels.length,
                                  percentagesVisible: renderedValues.every((value) =>
                                    value.includes("%") && !value.includes("No informado")
                                  ),
                                  forbiddenVisible: forbidden.test(
                                    renderedLabels.concat(renderedValues, attributes).join(" ")
                                  )
                                });
                              });
                            });
                            const allAttributes = Array.from(root?.querySelectorAll("[title], [aria-label]") || [])
                              .flatMap((node) => [
                                node.getAttribute("title") || "",
                                node.getAttribute("aria-label") || ""
                              ]).join(" ");
                            states.push({
                              id,
                              initialized: root?.dataset.rankedReady || null,
                              title: config?.title || null,
                              noteOverride: config?.noteOverride,
                              shareTotal: config?.shareTotal,
                              forbiddenInModule: forbidden.test((root?.innerText || "") + " " + allAttributes),
                              stateChecks: moduleStates
                            });
                          });
                          return {
                            modules: states,
                            pageForbidden: forbidden.test(document.body.innerText),
                            pageHorizontalOverflow: document.documentElement.scrollWidth - window.innerWidth
                          };
                        }
                        """,
                        module_ids,
                    )
                    states_ok = all(
                        module["initialized"] == "true"
                        and module["title"] == EXPECTED_TITLES[module["id"]]
                        and module["noteOverride"] is None
                        and module["shareTotal"] is None
                        and not module["forbiddenInModule"]
                        and all(
                            item["rows"] == item["expected"]
                            and item["uniqueLabels"]
                            and item["percentagesVisible"]
                            and not item["forbiddenVisible"]
                            for item in module["stateChecks"]
                        )
                        for module in state["modules"]
                    )
                    ok = all(
                        [
                            states_ok,
                            not state["pageForbidden"],
                            state["pageHorizontalOverflow"] <= 2,
                            not console_errors,
                            not page_errors,
                        ]
                    )
                    results.append(
                        {
                            "page": page_name,
                            "width": width,
                            "ok": ok,
                            "state": state,
                            "console_errors": console_errors,
                            "page_errors": page_errors,
                        }
                    )
                    page.close()
            browser.close()
    except Exception as error:
        return {"available": False, "reason": "No se pudo ejecutar Chromium: {}".format(error)}
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)

    return {
        "available": True,
        "results": results,
        "ok": all(result["ok"] for result in results),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-only", action="store_true")
    args = parser.parse_args()

    checks: Dict[str, bool] = {}
    details: Dict[str, Any] = {}
    r_source = R_SOURCE.read_text(encoding="utf-8") if R_SOURCE.is_file() else ""
    js_source = JS_SOURCE.read_text(encoding="utf-8") if JS_SOURCE.is_file() else ""
    workflow = WORKFLOW.read_text(encoding="utf-8") if WORKFLOW.is_file() else ""
    approved = (ROOT / "aprobados.qmd").read_text(encoding="utf-8")
    evaluation = (ROOT / "evaluacion.qmd").read_text(encoding="utf-8")

    actual_checksum = sha256(MAIN_XLSX) if MAIN_XLSX.is_file() else None
    checks["main_xlsx_checksum"] = actual_checksum == EXPECTED_XLSX_SHA256
    details["main_xlsx_sha256"] = actual_checksum
    checks["ranked_sources_exist"] = R_SOURCE.is_file() and JS_SOURCE.is_file()

    try:
        node = subprocess.run(
            ["node", "--check", str(JS_SOURCE)],
            check=False,
            capture_output=True,
            text=True,
        )
        checks["investment_javascript_syntax"] = node.returncode == 0
        details["node_stderr"] = node.stderr.strip()
    except FileNotFoundError:
        checks["investment_javascript_syntax"] = False
        details["node_stderr"] = "node no está instalado o no está en PATH"

    checks["five_module_keys_present"] = all(
        key in approved + evaluation
        for key in [
            "approved-total-investment",
            "approved-computable-assets",
            "approved-two-year-commitment",
            "approved-employment",
            "evaluation-total-investment",
        ]
    )
    checks["dictionary_lookup_is_unambiguous"] = all(
        token in r_source
        for token in [
            "dictionary_value <- function(dictionary, variable_name",
            ".data$variable == .env$variable_name",
        ]
    )
    checks["json_null_is_explicit"] = 'null = "null"' in r_source
    checks["optional_payload_values_are_normalized"] = all(
        token in r_source
        for token in ["share_total_value <-", "note_override_value <-"]
    )
    checks["javascript_rejects_object_number_coercion"] = all(
        token in js_source
        for token in [
            'typeof value === "number"',
            'typeof value !== "string"',
            "const normalized = value.trim()",
        ]
    )
    checks["javascript_validates_note_override"] = all(
        token in js_source
        for token in [
            'typeof config.noteOverride === "string"',
            "config.noteOverride.trim()",
            "if (noteOverride)",
        ]
    )
    checks["no_superficial_object_object_replacement"] = not re.search(
        r"\.replace\(\s*['\"]\\?\[object\s+Object\\?\]",
        js_source,
        re.IGNORECASE,
    )
    checks["workflow_runs_ranked_modules_qa"] = (
        "python3 tools/qa_ranked_modules.py" in workflow
    )

    browser: Dict[str, Any] = {"available": False, "reason": "source-only"}
    rendered_details: Dict[str, Any] = {}
    if not args.source_only:
        all_configs_ok = True
        all_ids_unique = True
        all_pages_clean = True
        for page_name, module_ids in PAGE_MODULES.items():
            page_path = SITE / page_name
            page_ok = page_path.is_file() and page_path.stat().st_size > 0
            checks["rendered_{}_exists".format(page_path.stem)] = page_ok
            if not page_ok:
                all_configs_ok = False
                all_ids_unique = False
                all_pages_clean = False
                continue
            html = page_path.read_text(encoding="utf-8")
            parser_instance = RankedPageParser()
            parser_instance.feed(html)
            duplicate_ids = sorted(
                identifier
                for identifier, count in Counter(parser_instance.ids).items()
                if count > 1
            )
            all_ids_unique = all_ids_unique and not duplicate_ids
            all_pages_clean = all_pages_clean and not FORBIDDEN_TEXT_RE.search(html)
            page_details: Dict[str, Any] = {"duplicate_ids": duplicate_ids, "modules": {}}
            for module_id in module_ids:
                config_ok, config_detail = validate_config(
                    module_id,
                    parser_instance.configs.get(module_id),
                )
                all_configs_ok = all_configs_ok and config_ok
                page_details["modules"][module_id] = config_detail
            rendered_details[page_name] = page_details
        checks["rendered_ranked_json_schema"] = all_configs_ok
        checks["rendered_pages_have_no_duplicate_ids"] = all_ids_unique
        checks["rendered_html_has_no_object_object"] = all_pages_clean

        browser = browser_qa()
        browser_required = (
            os.environ.get("RIGI_REQUIRE_BROWSER") == "1"
            or os.environ.get("CI", "").lower() == "true"
        )
        checks["browser_ranked_modules_regression"] = (
            bool(browser.get("ok")) if browser.get("available") else not browser_required
        )

    details["rendered"] = rendered_details
    failed = sorted(name for name, passed in checks.items() if not passed)
    result = {
        "mode": "source-only" if args.source_only else "rendered",
        "checks": checks,
        "details": details,
        "browser": browser,
        "failed": failed,
    }
    output_name = "ranked_modules_source_qa.json" if args.source_only else "ranked_modules_qa.json"
    output = ROOT / "qa" / output_name
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
