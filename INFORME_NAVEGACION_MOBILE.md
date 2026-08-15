# Informe de corrección de navegación y mobile

Fecha de trabajo: 15/08/2026

## Resultado implementado

El Monitor quedó reorganizado en seis páginas Quarto temáticas, con navegación global persistente y una subnavegación única en las páginas extensas. La portada conserva el título, la descripción institucional breve, la fecha dinámica de actualización, los KPI, el resumen ejecutivo, el índice visual y el bloque completo “Sobre el Monitor”.

## Causa del HTML visible

La barra anterior estaba escrita como HTML crudo dentro de `index.qmd`, pero sus enlaces tenían cuatro espacios de indentación dentro del bloque `<nav>`. Pandoc interpretó esas líneas como un bloque de código Markdown y Quarto generó `<pre><code>&lt;a href=…`, por lo que las etiquetas aparecieron impresas en lugar de convertirse en enlaces.

La corrección elimina ese bloque frágil. La navegación global se define en `_quarto.yml` mediante el componente nativo de Quarto. Las subnavegaciones usan enlaces Markdown dentro de fenced divs válidos. La auditoría estática con Pandoc confirma que ninguna página contiene anchors HTML dentro de bloques de código.

## Arquitectura

| Página | Contenido |
|---|---|
| `index.qmd` | Portada breve, KPI, resumen, índice y “Sobre el Monitor” |
| `aprobados.qmd` | Panorama, inversión, planes, importaciones, empleo, PEELP, hitos y fichas |
| `evaluacion.qmd` | Panorama, inversión, cronología y fichas |
| `comparacion.qmd` | Comparación general, sectorial, provincial y por estado |
| `base-datos.qmd` | Descargas, buscador y base completa |
| `metodologia.qmd` | Alcance, fuentes, variables monetarias y distribución territorial |

La navegación principal permanece en el encabezado. Quarto identifica la página activa. En pantallas pequeñas se presenta el control `Contenido` del menú global. Las páginas extensas generan un único control `En esta sección`, que actualiza `aria-expanded`, se cierra al elegir un anchor y responde a `Escape`.

## Gráficos y controles

- Planes de inversión: explicación, barra de período/sector/subsector/restablecimiento y gráficos quedaron en ese orden; el botón se denomina `Restablecer filtros`.
- Importaciones: cada vista mantiene su explicación y toolbar antes del gráfico; los chips de proyectos permanecen fuera del canvas.
- Las leyendas de sector se ubican debajo del gráfico, con mayor margen inferior y etiquetas largas divididas en hasta dos líneas.
- En mobile los filtros pasan a una columna, los menús tienen altura máxima y scroll propio, y se cierran al seleccionar, tocar fuera o presionar `Escape`.
- Los gráficos conservan `responsive: true`, `scrollZoom: false`, `doubleClick: false`, `dragmode: false` y ejes con `fixedrange: true`.
- Los indicadores de desplazamiento sólo se muestran cuando el contenedor tiene overflow real.

## Accesibilidad y responsive

Se incorporaron foco visible, estados activos con texto/subrayado, targets mínimos de 44 px, `aria-label`, `aria-controls`, sincronización de `aria-expanded`, cierre con `Escape`, cierre de estados transitorios al volver con el historial y compatibilidad con `prefers-reduced-motion`.

El sistema CSS contempla específicamente mobile pequeño (hasta 374 px), mobile (hasta 640 px), tablet/notebook (hasta 992/1200 px) y escritorio. La matriz objetivo auditada en las reglas fuente fue: 320×568, 360×800, 390×844, 430×932, 768×1024, 820×1180, 1024×768, 1280×720, 1366×768, 1440×900 y 1920×1080, además de portrait/landscape.

## Regresión de datos

No se modificó ningún archivo dentro de `data/` ni ningún valor sustantivo. La auditoría reproducible anterior y posterior coincide exactamente.

| Indicador | Antes | Después |
|---|---:|---:|
| Proyectos totales | 40 | 40 |
| Aprobados | 21 | 21 |
| En evaluación | 18 | 18 |
| Rechazados | 1 | 1 |
| Monto total (mill. USD) | 135.190 | 135.190 |
| Monto aprobado (mill. USD) | 46.708 | 46.708 |
| Monto en evaluación (mill. USD) | 88.209 | 88.209 |
| Activos computables (mill. USD) | 30.440 | 30.440 |
| Empleo informado aprobado | 95.158 | 95.158 |
| Proyectos PEELP aprobados | 5 | 5 |
| Planes de inversión (filas) | 264 | 264 |
| Importaciones (filas) | 1.846 | 1.846 |

La expansión territorial reconstruye los montos, activos y empleo originales, tanto para el total como para aprobados y en evaluación. Las cinco parejas CSV/XLSX conservan las mismas filas, columnas y valores.

## Pruebas ejecutadas

- Auditoría de datos y descargas antes/después: aprobada, sin diferencias.
- Links y anchors de las seis páginas: aprobados, sin destinos faltantes.
- HTML crudo/anchors interpretados como código por Pandoc: no detectados.
- Referencias públicas a UBA/CONICET: no detectadas.
- Sintaxis JavaScript de los tres archivos: aprobada con `node --check`.
- Sintaxis de scripts Python de QA: aprobada.
- Balance estructural del CSS: aprobado.
- Contratos Plotly de interacción táctil: aprobados por inspección estática.

Archivos de evidencia: `qa/navigation_baseline_audit.json`, `qa/navigation_final_audit.json`, `qa/navigation_source_qa.json`, `qa/quarto-render.log` y `qa/r-parse.log`.

## Limitación pendiente

El contenedor recibido no incluye los ejecutables `R`, `Rscript` ni `quarto`. Por ello no fue posible ejecutar en este entorno el render real, el pipeline R ni generar capturas auténticas del HTML final. Se intentó `quarto render` y el resultado quedó registrado en `qa/quarto-render.log`; no se editó `_site` manualmente.

El workflow de GitHub Pages permanece configurado para instalar R y Quarto, renderizar las seis páginas y publicar `_site`. También se actualizó para reaccionar ante cambios en cualquier `*.qmd`, `_partials/**`, `assets/**` y `downloads/**`. El primer render de CI es la validación visual y funcional final pendiente de un entorno con R/Quarto.

## Archivos modificados o agregados

- `_quarto.yml`
- `index.qmd`
- `aprobados.qmd`
- `evaluacion.qmd`
- `comparacion.qmd`
- `base-datos.qmd`
- `metodologia.qmd`
- `_partials/setup-core.qmd`
- `_partials/setup-approved.qmd`
- `styles.css`
- `assets/rigi-responsive.js`
- `assets/rigi-after-body.html`
- `assets/planes_inversion.js`
- `assets/importaciones.js`
- `R/05_planes_inversion.R`
- `R/06_importaciones.R`
- `.github/workflows/render.yml`
- `README.md`
- `tools/qa_navigation.py`
- `qa/navigation_baseline_audit.json`
- `qa/navigation_final_audit.json`
- `qa/navigation_source_qa.json`
- `qa/quarto-render.log`
- `qa/r-parse.log`
