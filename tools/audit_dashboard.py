#!/usr/bin/env python3
"""Auditoría reproducible de datos y descargas del Monitor RIGI.

El script no modifica las bases fuente. Genera un resumen JSON que puede usarse
como línea de base o como control de regresión después de cambios de interfaz.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd


MASTER_FILE = "data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
PLANS_FILE = "data/RIGI_planes_inversion.xlsx"
IMPORTS_FILE = "data/impo_rigi_aduana.csv"


def scalar(value: Any) -> Any:
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return None if np.isnan(value) else float(value)
    if isinstance(value, (pd.Timestamp,)):
        return value.isoformat()
    return value


def empty_mask(series: pd.Series) -> pd.Series:
    values = series.astype("string").str.strip().str.lower()
    return series.isna() | values.isin({"", "na", "n/a", "nan", "s/d", "sd", "no informado"})


def state_masks(data: pd.DataFrame) -> tuple[pd.Series, pd.Series, pd.Series]:
    state = data["Estado administrativo"].astype("string").str.lower()
    approved = state.str.contains("aprob", na=False) & ~state.str.contains(
        "no aprob|rechaz|desest", regex=True, na=False
    )
    pending = (~approved) & state.str.contains(
        "evalu|pend|anal|present|tram|anunci", regex=True, na=False
    )
    rejected = (~approved) & (~pending) & state.str.contains(
        "no aprob|rechaz|desest", regex=True, na=False
    )
    return approved, pending, rejected


def sum_or_none(series: pd.Series) -> float | None:
    numeric = pd.to_numeric(series, errors="coerce")
    if numeric.notna().sum() == 0:
        return None
    return float(numeric.sum(skipna=True))


def normalize_frame(frame: pd.DataFrame) -> pd.DataFrame:
    out = frame.copy()
    out.columns = [str(column).strip() for column in out.columns]
    for column in out.columns:
        if pd.api.types.is_datetime64_any_dtype(out[column]):
            out[column] = out[column].dt.strftime("%Y-%m-%d")
        elif pd.api.types.is_numeric_dtype(out[column]):
            out[column] = pd.to_numeric(out[column], errors="coerce").round(10)
        else:
            out[column] = out[column].astype("string").str.strip()
            if "fecha" in column.casefold():
                parsed = pd.to_datetime(out[column], errors="coerce")
                out[column] = parsed.dt.strftime("%Y-%m-%d")
    return out.replace({pd.NA: None, np.nan: None, "<NA>": None})


def compare_download_pair(root: Path, stem: str) -> dict[str, Any]:
    csv_path = root / "downloads" / f"{stem}.csv"
    xlsx_path = root / "downloads" / f"{stem}.xlsx"
    csv_data = pd.read_csv(csv_path)
    xlsx_data = pd.read_excel(xlsx_path)

    csv_norm = normalize_frame(csv_data)
    xlsx_norm = normalize_frame(xlsx_data)
    same_shape = csv_norm.shape == xlsx_norm.shape
    same_columns = list(csv_norm.columns) == list(xlsx_norm.columns)
    same_values = False
    if same_shape and same_columns:
        same_values = csv_norm.fillna("__NA__").astype(str).equals(
            xlsx_norm.fillna("__NA__").astype(str)
        )

    return {
        "csv_rows": int(csv_data.shape[0]),
        "xlsx_rows": int(xlsx_data.shape[0]),
        "columns": int(csv_data.shape[1]),
        "same_shape": same_shape,
        "same_columns": same_columns,
        "same_values": same_values,
    }


def territorial_check(data: pd.DataFrame, mask: pd.Series) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    subset = data.loc[mask].copy()
    for index, row in subset.iterrows():
        provinces = [
            value.strip()
            for value in str(row["provincia"]).split(";")
            if value.strip() and value.strip().lower() != "nan"
        ] or ["No informado"]
        for province in provinces:
            rows.append(
                {
                    "row": int(index),
                    "province": province,
                    "amount": pd.to_numeric(row["Monto (mill. USD)"], errors="coerce") / len(provinces),
                    "assets": pd.to_numeric(row["Activos Computables (mill. USD)"], errors="coerce") / len(provinces),
                    "employment": pd.to_numeric(row["Empleos (directos e indirectos)"], errors="coerce") / len(provinces),
                }
            )
    expanded = pd.DataFrame(rows)
    return {
        "project_rows": int(len(subset)),
        "territorial_rows": int(len(expanded)),
        "amount_original": sum_or_none(subset["Monto (mill. USD)"]),
        "amount_expanded": sum_or_none(expanded["amount"]) if len(expanded) else None,
        "assets_original": sum_or_none(subset["Activos Computables (mill. USD)"]),
        "assets_expanded": sum_or_none(expanded["assets"]) if len(expanded) else None,
        "employment_original": sum_or_none(subset["Empleos (directos e indirectos)"]),
        "employment_expanded": sum_or_none(expanded["employment"]) if len(expanded) else None,
    }


def audit_master(root: Path) -> dict[str, Any]:
    data = pd.read_excel(root / MASTER_FILE, sheet_name="Proyectos")
    approved, pending, rejected = state_masks(data)

    required = [
        "id_proyecto", "VPU", "empresa", "titular_proyecto", "CUIT", "sector",
        "subsector", "provincia", "Monto (mill. USD)",
        "Activos Computables (mill. USD)", "Empleos (directos e indirectos)",
        "Estado administrativo", "fecha_presentacion", "fecha_adhesion_rigi",
        "fecha_publicacion_bo", "norma_aprobacion", "link_norma", "Fuentes",
    ]
    missing_columns = [column for column in required if column not in data.columns]

    numeric_columns = [
        "Monto (mill. USD)",
        "Monto (mill. USD) - aprobados resolución",
        "Activos Computables (mill. USD)",
        "Empleos (directos e indirectos)",
    ]
    numeric_audit: dict[str, Any] = {}
    for column in numeric_columns:
        parsed = pd.to_numeric(data[column], errors="coerce")
        source_missing = empty_mask(data[column])
        numeric_audit[column] = {
            "missing": int(source_missing.sum()),
            "non_convertible": int((parsed.isna() & ~source_missing).sum()),
            "negative": int((parsed < 0).sum()),
        }

    dates = {}
    for column in ["fecha_presentacion", "fecha_adhesion_rigi", "fecha_publicacion_bo"]:
        dates[column] = pd.to_datetime(data[column], errors="coerce")
    impossible_dates = {
        column: int(((series.dt.year < 2024) | (series.dt.year > 2100)).sum())
        for column, series in dates.items()
    }
    bad_presentation_adhesion = approved & dates["fecha_presentacion"].notna() & dates[
        "fecha_adhesion_rigi"
    ].notna() & (dates["fecha_presentacion"] > dates["fecha_adhesion_rigi"])
    bad_adhesion_publication = approved & dates["fecha_adhesion_rigi"].notna() & dates[
        "fecha_publicacion_bo"
    ].notna() & (dates["fecha_adhesion_rigi"] > dates["fecha_publicacion_bo"])

    cuit_values = data["CUIT"].astype("string").str.strip()
    cuit_present = ~empty_mask(data["CUIT"])
    cuit_valid = cuit_values.str.fullmatch(r"\d{2}-\d{8}-\d", na=False)

    links = data["link_norma"].astype("string").str.strip()
    links_present = ~empty_mask(data["link_norma"])
    valid_link = links.str.match(r"^https?://", na=False)

    amount = pd.to_numeric(data["Monto (mill. USD)"], errors="coerce")
    amount_resolution = pd.to_numeric(
        data["Monto (mill. USD) - aprobados resolución"], errors="coerce"
    )
    differences = data.loc[
        approved & amount.notna() & amount_resolution.notna() & ~np.isclose(amount, amount_resolution),
        ["id_proyecto", "VPU", "Monto (mill. USD)", "Monto (mill. USD) - aprobados resolución"],
    ]

    peelp = data[
        "Proyectos de exportación estratégica de largo plazo (PEELP)"
    ].astype("string").str.lower().isin({"si", "sí"})

    metrics = {
        "projects_total": int(len(data)),
        "projects_approved": int(approved.sum()),
        "projects_pending": int(pending.sum()),
        "projects_rejected": int(rejected.sum()),
        "amount_total_mill_usd": sum_or_none(data["Monto (mill. USD)"]),
        "amount_approved_mill_usd": sum_or_none(data.loc[approved, "Monto (mill. USD)"]),
        "amount_pending_mill_usd": sum_or_none(data.loc[pending, "Monto (mill. USD)"]),
        "amount_rejected_mill_usd": sum_or_none(data.loc[rejected, "Monto (mill. USD)"]),
        "assets_total_mill_usd": sum_or_none(data["Activos Computables (mill. USD)"]),
        "assets_approved_mill_usd": sum_or_none(data.loc[approved, "Activos Computables (mill. USD)"]),
        "employment_approved": sum_or_none(data.loc[approved, "Empleos (directos e indirectos)"]),
        "approved_with_employment": int(data.loc[approved, "Empleos (directos e indirectos)"].notna().sum()),
        "peelp_approved": int((approved & peelp).sum()),
        "peelp_approved_amount_mill_usd": sum_or_none(data.loc[approved & peelp, "Monto (mill. USD)"]),
    }

    return {
        "metrics": metrics,
        "checks": {
            "missing_columns": missing_columns,
            "missing_id": int(empty_mask(data["id_proyecto"]).sum()),
            "duplicate_id": int(data["id_proyecto"].duplicated(keep=False).sum()),
            "duplicate_project_name": int(data["VPU"].astype("string").str.casefold().duplicated(keep=False).sum()),
            "missing_sector": int(empty_mask(data["sector"]).sum()),
            "missing_province": int(empty_mask(data["provincia"]).sum()),
            "invalid_cuit_among_present": int((cuit_present & ~cuit_valid).sum()),
            "missing_cuit": int((~cuit_present).sum()),
            "approved_without_resolution": int((approved & empty_mask(data["norma_aprobacion"])).sum()),
            "approved_without_resolution_link": int((approved & ~links_present).sum()),
            "invalid_resolution_links": int((links_present & ~valid_link).sum()),
            "duplicate_resolution_links": int(links[links_present].duplicated(keep=False).sum()),
            "approved_and_pending_overlap": int((approved & pending).sum()),
            "impossible_dates": impossible_dates,
            "presentation_after_adhesion": int(bad_presentation_adhesion.sum()),
            "adhesion_after_publication": int(bad_adhesion_publication.sum()),
            "numeric": numeric_audit,
            "amount_concept_differences": [
                {column: scalar(value) for column, value in row.items()}
                for row in differences.to_dict(orient="records")
            ],
        },
        "territorial": {
            "total": territorial_check(data, pd.Series(True, index=data.index)),
            "approved": territorial_check(data, approved),
            "pending": territorial_check(data, pending),
        },
    }


def audit_plans(root: Path) -> dict[str, Any]:
    data = pd.read_excel(root / PLANS_FILE, sheet_name="Datos_long")
    sector = data.groupby(["anio", "sector"], dropna=False).agg(
        calculated=("monto_mill_usd", "sum"),
        reference_count=("sector_total_mill_usd", "nunique"),
        reference=("sector_total_mill_usd", "first"),
    ).reset_index()
    annual = data.groupby("anio", dropna=False).agg(
        calculated=("monto_mill_usd", "sum"),
        reference_count=("total_anual_mill_usd", "nunique"),
        reference=("total_anual_mill_usd", "first"),
    ).reset_index()
    return {
        "rows": int(len(data)),
        "years": [int(value) for value in sorted(data["anio"].dropna().unique())],
        "amount_total_mill_usd": sum_or_none(data["monto_mill_usd"]),
        "exact_duplicates": int(data.duplicated().sum()),
        "key_duplicates": int(data.duplicated(["anio", "sector", "subsector"]).sum()),
        "missing_amount": int(pd.to_numeric(data["monto_mill_usd"], errors="coerce").isna().sum()),
        "negative_amount": int((pd.to_numeric(data["monto_mill_usd"], errors="coerce") < 0).sum()),
        "bad_sector_totals": int(
            ((sector["calculated"] - sector["reference"]).abs() > 1e-6).sum()
            + (sector["reference_count"] != 1).sum()
        ),
        "bad_annual_totals": int(
            ((annual["calculated"] - annual["reference"]).abs() > 1e-6).sum()
            + (annual["reference_count"] != 1).sum()
        ),
    }


def audit_imports(root: Path) -> dict[str, Any]:
    data = pd.read_csv(root / IMPORTS_FILE)
    fob = pd.to_numeric(data["fob_dolar"], errors="coerce")
    period = data["anio"] * 100 + data["mes"]
    return {
        "rows": int(len(data)),
        "columns": int(data.shape[1]),
        "fob_is_numeric": bool(pd.api.types.is_numeric_dtype(data["fob_dolar"])),
        "fob_non_convertible": int(fob.isna().sum()),
        "fob_negative": int((fob < 0).sum()),
        "invalid_month": int(((data["mes"] < 1) | (data["mes"] > 12) | data["mes"].isna()).sum()),
        "period_outside_bounds": int(((period < data["primer_periodo"]) | (period > data["ultimo_periodo"])).sum()),
        "exact_duplicates": int(data.duplicated().sum()),
        "fob_total_usd": float(fob.sum()),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = args.root.resolve()

    result = {
        "master": audit_master(root),
        "plans": audit_plans(root),
        "imports": audit_imports(root),
        "downloads": {
            stem: compare_download_pair(root, stem)
            for stem in [
                "base_completa",
                "base_interactiva_aprobados",
                "base_interactiva_pendientes",
                "planes_inversion",
                "importaciones_proyectos",
            ]
        },
    }

    output = json.dumps(result, ensure_ascii=False, indent=2, default=scalar) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output, end="")


if __name__ == "__main__":
    main()
