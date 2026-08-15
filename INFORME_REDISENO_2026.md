# Informe breve — Rediseño integral del Monitor RIGI

## Resultado

Se reorganizó el Monitor como un producto editorial de datos con la secuencia **entender → explorar → profundizar**, preservando el pipeline R/Quarto, las fuentes, las descargas, las protecciones de Plotly y la publicación en el subdirectorio `/RIGI/` de GitHub Pages.

## Cambios principales

- **Panorama:** nueva portada ejecutiva con hero breve, cinco KPI dinámicos, tres insights calculados, comparación Aprobados/En evaluación y accesos editoriales.
- **Aprobados:** nueva arquitectura `Panorama · Inversión · Ejecución · Empleo · Cronología · Proyectos`.
- **Concentración:** nuevo ranking acumulativo con participación individual, acumulada y atributo PEELP; muestra ocho proyectos y permite desplegar el resto.
- **Planes:** selector `Por año | Acumulado`; una sola vista visible, con los filtros y el reset 2024–2034 preservados.
- **Importaciones:** explorador único `Mensual | Acumulado` × `Sector | Proyecto`, cobertura dinámica y advertencia metodológica.
- **Evaluación:** cuatro KPI útiles, nota sobre activos no disponibles y timeline específico para mobile.
- **Comparar:** tres capítulos — Panorama, Sectores y Territorio — sin visualizaciones redundantes.
- **Datos:** explorador antes de las descargas y catálogo completo de bases CSV/XLSX.
- **Metodología:** documentación ampliada de alcance, estados, fuentes, criterios territoriales, planes, importaciones, empleo, faltantes y limitaciones.
- **Diseño:** sistema visual institucional, colores coherentes por estado/sector, microcopy de interacción, menor uso de cards y responsive específico.

## Regresión de datos

Los archivos `qa/redesign_baseline.json` y `qa/redesign_after.json` son idénticos.

- 40 proyectos: 21 aprobados, 18 en evaluación y 1 rechazado.
- Monto total: USD 135.190 M; aprobado: USD 46.708 M; en evaluación: USD 88.209 M.
- Activos computables aprobados: USD 30.440 M.
- Empleo informado aprobado: 95.158.
- PEELP: 5 proyectos por USD 35.059 M.
- Planes: 264 filas, 2024–2056, USD 46.024 M.
- Importaciones: 1.846 filas y USD 291.382.529,31 FOB.
- Los cinco pares CSV/XLSX coinciden en filas, columnas y valores.

No se modificó ningún dato sustantivo.

## QA ejecutada

- `tools/audit_dashboard.py`
- `tools/qa_functional_changes.py`
- `tools/qa_navigation.py`
- `tools/qa_github_pages.py`
- `tools/qa_mobile_layout.py`
- `tools/qa_redesign.py`
- `node --check` sobre todos los JavaScript de `assets/`
- parseo individual de las seis páginas QMD mediante Pandoc
- control de balance de delimitadores de todos los scripts R
- `git diff --check`

Todos los controles disponibles finalizaron sin fallos.

## Render y publicación

El entorno de preparación no contiene los ejecutables `Rscript` ni `quarto`, por lo que no fue posible producir un `_site` nuevo ni capturas reales en esta máquina. El workflow versionado ejecuta todos los QA estáticos, elimina el estado generado, corre `quarto render`, verifica los módulos interactivos y publica el `_site` recién generado en cada push a `main` o `master`.

La validación visual final de 360, 390, 430, 768, 1024, 1366 y 1440 px debe realizarse sobre el artefacto generado por ese workflow. Esta limitación está declarada expresamente; no se fabricó ni se editó `_site` manualmente.
