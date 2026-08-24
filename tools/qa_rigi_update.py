#!/usr/bin/env python3
"""Control integral reproducible para la migración canónica del Monitor RIGI."""

from __future__ import annotations

import argparse
import json
import math
import re
import subprocess
import unicodedata
from pathlib import Path
from typing import Any

import pandas as pd


REQUIRED_SHEETS = ["Proyectos", "Diccionario", "Variable_Anterior"]
REQUIRED_VARIABLES = [
    "vpu", "descripcion_proyecto", "peelp", "id_proyecto", "empresa",
    "titular_proyecto", "cuit", "sector", "subsector",
    "actividad_subsector_resolucion_mecon", "provincia", "localidad_region",
    "inversion_total_mill_usd", "inversion_total_resolucion_mill_usd",
    "inversion_activos_computables_mill_usd",
    "inversion_activos_computables_comprometida_anio_1_mill_usd",
    "inversion_activos_computables_comprometida_anio_2_mill_usd",
    "inversion_activos_computables_comprometida_2_anios_mill_usd",
    "estado_administrativo", "empleos_directos_indirectos_informados",
    "fecha_limite_inversion_minima_activos_computables", "fecha_presentacion",
    "fecha_adhesion_rigi", "fecha_publicacion_bo", "norma_aprobacion",
    "clasificacion_preexistencia_boletin_oficial",
    "justificacion_preexistencia_boletin_oficial", "link_norma", "fuentes",
    "links_fuentes",
]
EXCLUDED_EXPORTS = [
    "clasificacion_preexistencia_boletin_oficial",
    "justificacion_preexistencia_boletin_oficial",
]
DOWNLOADS = {
    "base_interactiva_aprobados.xlsx": "approved",
    "base_interactiva_pendientes.xlsx": "evaluation",
    "base_completa.xlsx": "all",
}
EXPECTED_LABELS = {
    "inversion_total_mill_usd": "Inversión total",
    "inversion_total_resolucion_mill_usd": "Inversión total según resolución",
    "inversion_activos_computables_mill_usd": "Inversión en activos computables",
    "inversion_activos_computables_comprometida_2_anios_mill_usd":
        "Inversión comprometida en activos computables — primeros 2 años",
    "empleos_directos_indirectos_informados": "Empleo informado",
    "fecha_limite_inversion_minima_activos_computables":
        "Fecha límite para alcanzar la inversión mínima",
    "fecha_adhesion_rigi": "Fecha de adhesión al RIGI",
}


def normalize(value: Any) -> str:
    text = unicodedata.normalize("NFD", str(value or "").strip().lower())
    return "".join(char for char in text if unicodedata.category(char) != "Mn")


def state_masks(data: pd.DataFrame) -> tuple[pd.Series, pd.Series, pd.Series]:
    state = data["estado_administrativo"].map(normalize)
    approved = state.str.contains("aprob", na=False) & ~state.str.contains(
        r"no aprob|rechaz|desest", regex=True, na=False
    )
    evaluation = (~approved) & state.str.contains(
        r"evalu|pend|anal|present|tram|anunci", regex=True, na=False
    )
    rejected = (~approved) & state.str.contains(
        r"no aprob|rechaz|desest", regex=True, na=False
    )
    return approved, evaluation, rejected


def numeric_sum(series: pd.Series) -> float | None:
    values = pd.to_numeric(series, errors="coerce")
    return None if values.notna().sum() == 0 else float(values.sum(skipna=True))


def nearly_equal(left: float | None, right: float | None, tolerance: float = 1e-7) -> bool:
    if left is None or right is None:
        return left is right
    return math.isclose(left, right, rel_tol=tolerance, abs_tol=tolerance)


def json_default(value: Any) -> Any:
    if hasattr(value, "item"):
        return value.item()
    if isinstance(value, (pd.Timestamp,)):
        return value.isoformat()
    raise TypeError(f"No se puede serializar {type(value).__name__}")


def territorial_sum(data: pd.DataFrame, column: str) -> float | None:
    total = 0.0
    informed = 0
    for _, row in data.iterrows():
        value = pd.to_numeric(pd.Series([row[column]]), errors="coerce").iloc[0]
        if pd.isna(value):
            continue
        provinces = [item.strip() for item in str(row["provincia"]).split(";") if item.strip()]
        provinces = provinces or ["No informado"]
        total += sum(float(value) / len(provinces) for _ in provinces)
        informed += 1
    return total if informed else None


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


def inspect_download(path: Path, expected_columns: list[str], expected_rows: int) -> dict[str, Any]:
    sheets = pd.ExcelFile(path).sheet_names
    projects = pd.read_excel(path, sheet_name="Proyectos")
    dictionary = pd.read_excel(path, sheet_name="Diccionario")
    dictionary_variable_column = "Variable"
    numeric_columns = [column for column in expected_columns if column.startswith("inversion_")]
    date_columns = [column for column in expected_columns if column.startswith("fecha_")]
    return {
        "sheets": sheets,
        "rows": int(len(projects)),
        "columns": list(projects.columns),
        "dictionary_variables": dictionary[dictionary_variable_column].astype(str).tolist(),
        "numeric_columns_parse": all(
            pd.to_numeric(projects[column], errors="coerce").notna().sum()
            == projects[column].notna().sum()
            for column in numeric_columns
        ),
        "date_columns_parse": all(
            pd.to_datetime(projects[column], errors="coerce").notna().sum()
            == projects[column].notna().sum()
            for column in date_columns
        ),
        "ok": sheets == ["Proyectos", "Diccionario"]
        and len(projects) == expected_rows
        and list(projects.columns) == expected_columns
        and dictionary[dictionary_variable_column].astype(str).tolist() == expected_columns,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", default="qa/integral_update_qa.json")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    source = root / "data" / "RIGI_tracker_data_final_con_proyectos_integrados.xlsx"

    workbook = pd.ExcelFile(source)
    projects = pd.read_excel(source, sheet_name="Proyectos")
    dictionary = pd.read_excel(source, sheet_name="Diccionario")
    mapping = pd.read_excel(source, sheet_name="Variable_Anterior")
    approved, evaluation, rejected = state_masks(projects)
    expected_export_columns = [
        column for column in list(projects.columns) if column not in EXCLUDED_EXPORTS
    ]

    dictionary_index = dictionary.set_index("Variable")
    label_mismatches = {
        variable: {
            "expected": expected,
            "actual": dictionary_index.at[variable, "Nombre visible"]
            if variable in dictionary_index.index else None,
        }
        for variable, expected in EXPECTED_LABELS.items()
        if variable not in dictionary_index.index
        or dictionary_index.at[variable, "Nombre visible"] != expected
    }

    year1 = pd.to_numeric(
        projects["inversion_activos_computables_comprometida_anio_1_mill_usd"],
        errors="coerce",
    )
    year2 = pd.to_numeric(
        projects["inversion_activos_computables_comprometida_anio_2_mill_usd"],
        errors="coerce",
    )
    two_year = pd.to_numeric(
        projects["inversion_activos_computables_comprometida_2_anios_mill_usd"],
        errors="coerce",
    )
    comparable = year1.notna() & year2.notna() & two_year.notna()
    commitment_differences = projects.loc[
        comparable & ~((year1 + year2 - two_year).abs() <= 1e-7), "id_proyecto"
    ].astype(str).tolist()

    territorial = {}
    for universe_name, mask in {
        "all": pd.Series(True, index=projects.index),
        "approved": approved,
        "evaluation": evaluation,
    }.items():
        subset = projects.loc[mask]
        territorial[universe_name] = {}
        for column in [
            "inversion_total_mill_usd",
            "inversion_activos_computables_mill_usd",
            "inversion_activos_computables_comprometida_2_anios_mill_usd",
        ]:
            original = numeric_sum(subset[column])
            allocated = territorial_sum(subset, column)
            territorial[universe_name][column] = {
                "original": original,
                "allocated": allocated,
                "reconciles": nearly_equal(original, allocated),
            }

    expected_rows = {
        "approved": int(approved.sum()),
        "evaluation": int(evaluation.sum()),
        "all": int(len(projects)),
    }
    downloads = {
        file_name: inspect_download(
            root / "downloads" / file_name,
            expected_export_columns,
            expected_rows[universe],
        )
        for file_name, universe in DOWNLOADS.items()
    }

    adhesion = pd.to_datetime(projects["fecha_adhesion_rigi"], errors="coerce")
    deadline = pd.to_datetime(
        projects["fecha_limite_inversion_minima_activos_computables"], errors="coerce"
    )
    approved_dates = approved & adhesion.notna() & deadline.notna()

    source_files = [
        *sorted((root / "R").glob("*.R")),
        *sorted(root.glob("*.qmd")),
        *sorted((root / "_partials").glob("*.qmd")),
        *sorted((root / "assets").glob("*.js")),
    ]
    public_source = "\n".join(path.read_text(encoding="utf-8") for path in source_files)
    r_sources = [path for path in source_files if path.suffix == ".R"]
    js_results = {}
    for path in sorted((root / "assets").glob("*.js")):
        process = subprocess.run(
            ["node", "--check", str(path)], check=False, capture_output=True, text=True
        )
        js_results[str(path.relative_to(root))] = {
            "ok": process.returncode == 0,
            "stderr": process.stderr.strip(),
        }

    checks = {
        "required_sheets": workbook.sheet_names == REQUIRED_SHEETS,
        "canonical_schema_exact": list(projects.columns) == REQUIRED_VARIABLES,
        "dictionary_contract_complete": set(REQUIRED_VARIABLES).issubset(
            set(dictionary["Variable"].astype(str))
        ),
        "mapping_contract_complete": set(REQUIRED_VARIABLES).issubset(
            set(mapping["Variable recomendada"].astype(str))
        ),
        "dictionary_labels_exact": not label_mismatches,
        "id_project_present": projects["id_proyecto"].notna().all(),
        "id_project_unique": not projects["id_proyecto"].duplicated().any(),
        "states_exhaustive": int(approved.sum() + evaluation.sum() + rejected.sum()) == len(projects),
        "state_counts_21_19_1": (int(approved.sum()), int(evaluation.sum()), int(rejected.sum()))
        == (21, 19, 1),
        "commitment_components_match_total": not commitment_differences,
        "territorial_totals_reconcile": all(
            item["reconciles"]
            for universe in territorial.values()
            for item in universe.values()
        ),
        "download_workbooks_valid": all(item["ok"] for item in downloads.values()),
        "download_numbers_are_numeric": all(
            item["numeric_columns_parse"] for item in downloads.values()
        ),
        "download_dates_are_dates": all(item["date_columns_parse"] for item in downloads.values()),
        "no_main_database_csv": not any(
            (root / "downloads" / name).exists()
            for name in [
                "base_interactiva_aprobados.csv",
                "base_interactiva_pendientes.csv",
                "base_completa.csv",
            ]
        ),
        "no_visible_pending_approval": "Pendiente de aprobación" not in public_source,
        "approved_investment_modules": all(
            token in (root / "aprobados.qmd").read_text(encoding="utf-8")
            for token in [
                'value_col = "inversion_total_mill_usd"',
                'value_col = "inversion_activos_computables_mill_usd"',
                'value_col = "inversion_activos_computables_comprometida_2_anios_mill_usd"',
                "make_commitment_schedule_module(proyectos)",
            ]
        ),
        "evaluation_module": 'value_col = "inversion_total_mill_usd"'
        in (root / "evaluacion.qmd").read_text(encoding="utf-8"),
        "methodology_dictionary_generated": "make_data_dictionary(diccionario)"
        in (root / "metodologia.qmd").read_text(encoding="utf-8"),
        "official_2026_milestone": all(
            token in (root / "R/04_plots.R").read_text(encoding="utf-8")
            for token in ["Decreto 748/2026", "2026-08-18", "345955/20260818"]
        ),
        "summary_ranking_title": "Principales proyectos aprobados por monto" in public_source,
        "author_attribution": "@_LucasOrdoñez"
        in (root / "_quarto.yml").read_text(encoding="utf-8"),
        "plans_argentine_separators": 'separators: ",."'
        in (root / "assets/planes_inversion.js").read_text(encoding="utf-8"),
        "css_balanced": (root / "styles.css").read_text(encoding="utf-8").count("{")
        == (root / "styles.css").read_text(encoding="utf-8").count("}"),
        "r_delimiters_balanced": all(
            delimiters_balanced(path.read_text(encoding="utf-8")) for path in r_sources
        ),
        "javascript_syntax": all(item["ok"] for item in js_results.values()),
        "no_deadline_before_adhesion": int((approved_dates & (deadline < adhesion)).sum()) == 0,
    }

    metrics = {
        "projects": {
            "total": int(len(projects)),
            "approved": int(approved.sum()),
            "evaluation": int(evaluation.sum()),
            "rejected": int(rejected.sum()),
        },
        "investment_mill_usd": {
            column: {
                "all": numeric_sum(projects[column]),
                "approved": numeric_sum(projects.loc[approved, column]),
                "evaluation": numeric_sum(projects.loc[evaluation, column]),
            }
            for column in [
                "inversion_total_mill_usd",
                "inversion_activos_computables_mill_usd",
                "inversion_activos_computables_comprometida_2_anios_mill_usd",
            ]
        },
        "schedules": {
            "approved_missing_adhesion": int((approved & adhesion.isna()).sum()),
            "approved_missing_deadline_or_adhesion": int(
                (approved & (adhesion.isna() | deadline.isna())).sum()
            ),
            "deadline_before_adhesion": int((approved_dates & (deadline < adhesion)).sum()),
        },
    }

    result = {
        "checks": checks,
        "metrics": metrics,
        "territorial": territorial,
        "commitment_differences": commitment_differences,
        "dictionary_label_mismatches": label_mismatches,
        "downloads": downloads,
        "javascript": js_results,
        "failed": sorted(name for name, passed in checks.items() if not passed),
    }
    output = root / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, default=json_default) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(result, ensure_ascii=False, indent=2, default=json_default))
    return 1 if result["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
