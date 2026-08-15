#!/usr/bin/env python3
"""Static regression checks for the 2026 editorial redesign."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


quarto = read("_quarto.yml")
home = read("index.qmd")
approved = read("aprobados.qmd")
evaluation = read("evaluacion.qmd")
comparison = read("comparacion.qmd")
data_page = read("base-datos.qmd")
methodology = read("metodologia.qmd")
plots = read("R/04_plots.R")
plans_r = read("R/05_planes_inversion.R")
imports_r = read("R/06_importaciones.R")
responsive = read("assets/rigi-responsive.js")
css = read("styles.css")


checks = {
    "global_nav_editorial_labels": all(
        token in quarto
        for token in ["text: Panorama", "text: Comparar", "text: Datos"]
    ),
    "home_executive_sequence": all(
        token in home
        for token in [
            "RIGI en una mirada",
            "Qué muestran los datos",
            "Aprobados vs. en evaluación",
            "Explorá el Monitor",
            "make_home_kpis",
            "make_home_insights",
            "make_home_status_comparison",
        ]
    ),
    "home_values_are_dynamic": "`r indicadores$fecha_actualizacion_fmt`" in home
    and "21 proyectos" not in home
    and "46.708" not in home,
    "approved_chapters": all(
        f"## {title}" in approved
        for title in ["Panorama", "Inversión", "Ejecución", "Empleo", "Cronología", "Proyectos"]
    ),
    "approved_peelp_integrated": "make_investment_concentration" in approved
    and "## PEELP" not in approved
    and "Proyectos de exportación estratégica de largo plazo (PEELP)" not in approved,
    "plans_single_view_explorer": all(
        token in plans_r
        for token in ["plans-view-switch", "data-plans-view", "plans-chart-panel"]
    ),
    "imports_single_view_explorer": all(
        token in imports_r
        for token in [
            "impo-view-switch",
            "impo-breakdown-switch",
            "data-impo-view",
            "data-impo-breakdown",
            "impo-coverage",
        ]
    ),
    "evaluation_mobile_timeline": "timeline-desktop" in evaluation
    and "timeline-mobile" in evaluation
    and "make_mobile_pending_timeline" in plots,
    "comparison_simplified": all(
        f"## {title}" in comparison for title in ["Panorama", "Sectores", "Territorio"]
    )
    and "Composición del universo" not in comparison,
    "data_explorer_precedes_downloads": data_page.find("## Explorar proyectos")
    < data_page.find("## Descargar datos")
    and "make_download_catalog" in data_page,
    "download_catalog_complete": all(
        stem in plots
        for stem in [
            "base_completa",
            "base_interactiva_aprobados",
            "base_interactiva_pendientes",
            "planes_inversion",
            "importaciones_proyectos",
        ]
    ),
    "methodology_coverage_and_limits": all(
        heading in methodology
        for heading in [
            "## Alcance",
            "## Estados administrativos",
            "## Fuentes",
            "## Variables monetarias",
            "## Distribución territorial",
            "## Planes de inversión",
            "## Importaciones",
            "### Cobertura",
            "### Limitaciones",
            "## Datos faltantes",
        ]
    ),
    "interaction_microcopy_replaces_badge": "interaction-cue" in responsive
    and "INTERACTIVO" not in responsive,
    "responsive_breakpoints": all(
        token in css
        for token in [
            "@media (max-width: 1199px)",
            "@media (max-width: 767px)",
            "@media (max-width: 359px)",
        ]
    ),
    "mobile_plot_protections_preserved": all(
        token in responsive
        for token in ["fixedrange", "dragmode", "rigi-plot-scroll"]
    ),
}

failed = [name for name, ok in checks.items() if not ok]
result = {"checks": checks, "failed": failed}
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(1 if failed else 0)
