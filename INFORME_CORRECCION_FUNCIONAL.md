# Informe de corrección funcional del Monitor RIGI

Fecha de intervención: 15/08/2026

## Resultado

Se corrigieron en las fuentes del proyecto los siete puntos solicitados:

- Planes de inversión inicia y se restablece en 2024–2034, con una selección segura basada en los años disponibles.
- La cronología de presentaciones ya no genera montos visibles junto a los proyectos; conserva monto, tamaño de burbuja y demás datos en el tooltip.
- La publicación de GitHub Pages quedó configurada para reconstruir el sitio sin reutilizar estados generados obsoletos.
- La subnavegación interna se reforzó como sticky y el selector móvil informa la subsección activa.
- El hero conserva solamente `DESIP · IIEP` y ya no muestra `PUBLICACIÓN ESTADÍSTICA`.
- Importaciones por proyecto utiliza un desplegable multiselección con buscador, contador, seleccionar todos, limpiar selección y filtro por sector.
- Hitos del RIGI utiliza una lista documental compacta basada en `details`/`summary`; todos los hitos comienzan cerrados y pueden mantenerse varios abiertos simultáneamente.

## Causa de los gráficos ausentes en GitHub Pages

El workflow sólo observaba un conjunto incompleto de archivos. Los cambios en páginas temáticas, `_partials/`, `assets/` y `downloads/` podían subirse sin disparar un nuevo despliegue. Además, `_freeze/` y los directorios `*_cache/` estaban versionados, mientras Quarto tenía `freeze: auto` y caché activada. Esa combinación permitía que CI reutilizara resultados anteriores y publicara páginas sin los módulos interactivos actualizados.

La corrección comprende:

- disparadores para todas las páginas raíz `*.qmd`, `_partials/**`, `assets/**`, `R/**`, `data/**` y `downloads/**`;
- dependencias explícitas `htmlwidgets`, `writexl` y `jsonlite`, además de las ya instaladas;
- eliminación del estado generado antes de renderizar en CI;
- `cache: false` y `freeze: false` para que cada despliegue reconstruya los objetos R y JSON embebidos;
- exclusión de `_freeze/` y `*_cache/` del repositorio;
- conservación de los tres scripts dentro de `project.resources` y uso de rutas relativas compatibles con `/RIGI/`.

## Regresión de datos

Los archivos `qa/functional_baseline_audit.json` y `qa/functional_final_audit.json` son idénticos. No se modificó ningún dato sustantivo.

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
| Empleo aprobado informado | 95.158 | 95.158 |
| Proyectos PEELP aprobados | 5 | 5 |
| Planes de inversión (mill. USD) | 46.024 | 46.024 |
| Importaciones FOB (USD) | 291.382.529,31 | 291.382.529,31 |

La expansión territorial reconstruye exactamente monto, activos y empleo. Los cinco pares CSV/XLSX mantienen forma, columnas y valores equivalentes.

## Pruebas ejecutadas

- Auditoría de datos y descargas antes y después: aprobada, sin diferencias.
- Sintaxis de `assets/rigi-responsive.js`, `assets/planes_inversion.js` y `assets/importaciones.js` mediante `node --check`: aprobada.
- Estructura delimitada de los siete scripts R: aprobada.
- Parseo Pandoc de las seis páginas QMD: aprobado.
- Enlaces y anchors internos, páginas de navbar, HTML crudo accidental y referencias institucionales prohibidas: aprobado.
- IDs de Planes e Importaciones requeridos en las fuentes: aprobados.
- Configuración, disparadores, dependencias y recursos del workflow: aprobados.
- `git diff --check`: aprobado.

Los resultados detallados se guardaron en:

- `qa/functional_source_qa.json`;
- `qa/navigation_source_qa.json`;
- `qa/functional_baseline_audit.json`;
- `qa/functional_final_audit.json`.

## Archivos modificados

- `.github/workflows/render.yml`
- `.gitignore`
- `_quarto.yml`
- `index.qmd`
- `aprobados.qmd`
- `evaluacion.qmd`
- `R/04_plots.R`
- `R/05_planes_inversion.R`
- `R/06_importaciones.R`
- `assets/planes_inversion.js`
- `assets/importaciones.js`
- `assets/rigi-responsive.js`
- `styles.css`
- `tools/qa_functional_changes.py`
- archivos de evidencia bajo `qa/`

## Limitaciones del entorno de validación

El entorno de trabajo no contiene los ejecutables `Rscript` ni `quarto`, ni un navegador instalado. Por ese motivo no fue posible ejecutar localmente el render R/Quarto final ni producir capturas nuevas y confiables de los breakpoints solicitados. No se editaron ni se presentaron como finales los HTML existentes en `_site/`.

El workflow corregido ejecuta un render limpio real al hacer `git push`. La validación visual final en 320, 360, 390, 430, 768, 820, 1024, 1280, 1366, 1440 y 1920 px queda pendiente de ese render en GitHub Actions o de un entorno que tenga R, Quarto y navegador disponibles.
