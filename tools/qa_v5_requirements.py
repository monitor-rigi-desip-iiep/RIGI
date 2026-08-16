#!/usr/bin/env python3
"""QA reproducible de los cambios visuales y funcionales de la versión 5."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "data" / "RIGI_tracker_data_final_con_proyectos_integrados.xlsx"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def state_masks(data: pd.DataFrame) -> tuple[pd.Series, pd.Series, pd.Series]:
    state = data["Estado administrativo"].astype("string").str.strip().str.lower()
    approved = state.str.contains("aprob", na=False) & ~state.str.contains(
        "no aprob|rechaz|desest", regex=True, na=False
    )
    pending = (~approved) & state.str.contains(
        "evalu|pend|anal|present|tram|anunci", regex=True, na=False
    )
    rejected = (~approved) & state.str.contains(
        "no aprob|rechaz|desest", regex=True, na=False
    )
    return approved, pending, rejected


def operational_approval_date(data: pd.DataFrame) -> pd.Series:
    result = pd.Series(pd.NaT, index=data.index, dtype="datetime64[ns]")
    for column in ["fecha_aprobacion", "fecha_publicacion_bo", "fecha_adhesion_rigi"]:
        if column in data.columns:
            result = result.fillna(pd.to_datetime(data[column], errors="coerce"))
    return result


def project_records(frame: pd.DataFrame, date_column: str) -> list[dict[str, Any]]:
    return [
        {
            "proyecto": str(row["VPU"]),
            "sector": str(row["sector"]),
            "monto_mill_usd": float(row["Monto (mill. USD)"]),
            "fecha": row[date_column].strftime("%Y-%m-%d"),
        }
        for _, row in frame.iterrows()
    ]


def delimiters_balanced(text: str) -> bool:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack: list[str] = []
    quote: str | None = None
    escaped = False
    comment = False

    for character in text:
        if comment:
            if character == "\n":
                comment = False
            continue
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character == "#":
            comment = True
        elif character in {'"', "'", "`"}:
            quote = character
        elif character in "([{":
            stack.append(character)
        elif character in ")]}":
            if not stack or stack.pop() != pairs[character]:
                return False
    return not stack and quote is None


def main() -> int:
    indicators = read("R/03_indicators.R")
    plots = read("R/04_plots.R")
    styles = read("styles.css")
    index = read("index.qmd")
    approved_page = read("aprobados.qmd")
    pending_page = read("evaluacion.qmd")
    database_page = read("base-datos.qmd")
    imports_js = read("assets/importaciones.js")
    plans_js = read("assets/planes_inversion.js")

    data = pd.read_excel(MASTER, sheet_name="Proyectos")
    approved, pending, rejected = state_masks(data)
    amounts = pd.to_numeric(data["Monto (mill. USD)"], errors="coerce")

    amount_total = float(amounts.sum(skipna=True))
    amount_approved = float(amounts[approved].sum(skipna=True))
    amount_pending = float(amounts[pending].sum(skipna=True))
    approved_share = amount_approved / amount_total if amount_total else None

    approved_data = data.loc[approved].copy()
    approved_data["_amount"] = amounts[approved]
    pending_data = data.loc[pending].copy()
    pending_data["_amount"] = amounts[pending]
    approved_data["_approval_date"] = operational_approval_date(data)[approved]
    pending_data["_presentation_date"] = pd.to_datetime(
        pending_data["fecha_presentacion"], errors="coerce"
    )

    top_three = approved_data.sort_values(
        ["_amount", "VPU"], ascending=[False, True]
    ).head(3)
    latest_approved = approved_data.dropna(subset=["_approval_date"]).sort_values(
        ["_approval_date", "VPU"], ascending=[False, True]
    ).head(3)
    latest_pending = pending_data.dropna(subset=["_presentation_date"]).sort_values(
        ["_presentation_date", "VPU"], ascending=[False, True]
    ).head(3)

    sector_totals = approved_data.groupby("sector", dropna=False)["_amount"].sum()
    top_sector = str(sector_totals.sort_values(ascending=False).index[0])

    province_rows: list[dict[str, Any]] = []
    for _, row in approved_data.iterrows():
        provinces = [
            value.strip()
            for value in str(row["provincia"]).split(";")
            if value.strip() and value.strip().lower() != "nan"
        ] or ["No informado"]
        allocated = float(row["_amount"]) / len(provinces)
        province_rows.extend({"province": province, "amount": allocated} for province in provinces)
    province_frame = pd.DataFrame(province_rows)
    province_totals = province_frame.groupby("province")["amount"].sum().sort_values(ascending=False)
    top_province = str(province_totals.index[0])
    territorial_total = float(province_frame["amount"].sum())

    expected_top = [
        "Proyecto de Licuefacción de Gas Natural (FLNG - Southern Energy)",
        "Vicuña",
        "Proyecto Rincón de Aranda (RDA)",
    ]

    checks = {
        "summary_uses_visual_dashboard": "make_summary_dashboard(indicadores, tablas)" in index
        and "summary-box" not in index,
        "summary_has_four_attention_metrics": all(
            token in plots
            for token in [
                "summary-metrics-grid",
                "Monto de proyectos aprobados",
                "Sector líder entre aprobados",
                "Provincia líder entre aprobados",
                "Proyectos relevados",
            ]
        ),
        "summary_has_amount_bars": "summary_amount_bar(\"Aprobados\"" in plots
        and "summary_amount_bar(\"En evaluación\"" in plots,
        "summary_latest_are_date_sorted": all(
            token in indicators
            for token in [
                "ultimos_aprobados",
                "dplyr::desc(fecha_aprobacion)",
                "ultimos_pendientes",
                "dplyr::desc(fecha_presentacion)",
            ]
        ),
        "explorer_has_table_and_cards": all(
            token in plots
            for token in [
                'role = "tablist"',
                '`data-view-target` = "table"',
                '`data-view-target` = "cards"',
                '`data-project-row` = "true"',
                '`data-project-card` = "true"',
                "updateItems(cards, grid)",
                "updateItems(rows, tableBody)",
            ]
        ),
        "all_requested_pages_use_explorer": all(
            "make_rigi_project_cards(" in page
            for page in [approved_page, pending_page, database_page]
        ),
        "view_switch_is_keyboard_accessible": "ArrowRight" in plots
        and "ArrowLeft" in plots
        and "aria-selected" in plots,
        "responsive_card_grid_3_2_1": all(
            token in styles
            for token in [
                "@media (min-width: 1280px)",
                "grid-template-columns: repeat(3, minmax(0, 1fr))",
                "@media (min-width: 720px) and (max-width: 1279px)",
                "@media (max-width: 719px)",
            ]
        ),
        "responsive_table_is_contained": ".rigi-project-table-scroll" in styles
        and "overflow-x: auto" in styles
        and "max-width: 100%" in styles,
        "timeline_has_fluid_width": "mobile_min_width = 0" in plots
        and ".rigi-timeline-chart .js-plotly-plot" in styles
        and "width: 100% !important" in styles,
        "timeline_has_touch_help": "Tocá o pasá el cursor" in pending_page,
        "currency_notation_is_consistent": "US$" not in plots
        and "US$" not in imports_js
        and "US$" not in plans_js,
        "css_braces_balanced": styles.count("{") == styles.count("}"),
        "r_delimiters_balanced": delimiters_balanced(indicators) and delimiters_balanced(plots),
        "project_counts_match_base": (len(data), int(approved.sum()), int(pending.sum()), int(rejected.sum()))
        == (40, 21, 18, 1),
        "approved_share_rounds_to_34_5": approved_share is not None
        and round(approved_share * 100, 1) == 34.5,
        "approved_amount_matches_base": amount_approved == 46708.0,
        "pending_amount_matches_base": amount_pending == 88209.0,
        "top_sector_matches_base": top_sector == "Petróleo y Gas",
        "top_province_matches_equal_allocation": top_province == "Río Negro",
        "territorial_allocation_reconciles": abs(territorial_total - amount_approved) < 1e-8,
        "top_three_projects_match_request": top_three["VPU"].tolist() == expected_top,
        "latest_lists_have_three_valid_dates": len(latest_approved) == 3
        and len(latest_pending) == 3,
    }

    javascript: dict[str, dict[str, Any]] = {}
    for relative in [
        "assets/rigi-responsive.js",
        "assets/planes_inversion.js",
        "assets/importaciones.js",
    ]:
        process = subprocess.run(
            ["node", "--check", str(ROOT / relative)],
            check=False,
            capture_output=True,
            text=True,
        )
        javascript[relative] = {
            "ok": process.returncode == 0,
            "stderr": process.stderr.strip(),
        }
        checks[f"javascript_syntax_{Path(relative).stem}"] = process.returncode == 0

    result = {
        "checks": checks,
        "metrics": {
            "projects_total": len(data),
            "projects_approved": int(approved.sum()),
            "projects_pending": int(pending.sum()),
            "projects_rejected": int(rejected.sum()),
            "amount_total_mill_usd": amount_total,
            "amount_approved_mill_usd": amount_approved,
            "amount_pending_mill_usd": amount_pending,
            "approved_share_pct": round(approved_share * 100, 4) if approved_share else None,
            "approved_bar_relative_pct": round(amount_approved / amount_pending * 100, 4)
            if amount_pending
            else None,
            "top_sector": top_sector,
            "top_province_equal_allocation": top_province,
        },
        "top_three_approved": [
            {
                "proyecto": str(row["VPU"]),
                "sector": str(row["sector"]),
                "monto_mill_usd": float(row["_amount"]),
            }
            for _, row in top_three.iterrows()
        ],
        "latest_approved": project_records(
            latest_approved.rename(columns={"_approval_date": "_date"}), "_date"
        ),
        "latest_pending": project_records(
            latest_pending.rename(columns={"_presentation_date": "_date"}), "_date"
        ),
        "javascript": javascript,
        "failed": sorted(name for name, ok in checks.items() if not ok),
    }

    output = ROOT / "qa" / "v5_requirements_qa.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
