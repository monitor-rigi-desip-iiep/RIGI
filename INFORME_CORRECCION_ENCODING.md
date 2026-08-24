# Informe de corrección de codificación — Monitor de Proyectos RIGI

Fecha de preparación: 23/08/2026.

## Resultado

Se corrigió la ruta que provocaba el error `Character encoding must be UTF-8, Latin-1 or bytes` al construir los filtros de proyectos en evaluación. La solución valida y convierte explícitamente los textos a UTF-8 antes de limpiarlos, ordenarlos o serializarlos para la interfaz. El XLSX vigente se preservó sin cambios.

## Causa raíz

`rigi_filter_values()` enviaba directamente a `sort(..., method = "radix")` valores obtenidos con `as.character()`. En macOS, el literal visible `En evaluación` podía conservar bytes UTF-8 con marca de codificación `unknown`. El ordenamiento radix acepta texto no ASCII marcado como UTF-8, Latin-1 o bytes, pero rechazaba esa cadena sin una conversión explícita. Los aprobados no exponían el problema porque `Aprobado` contiene solamente caracteres ASCII.

## Solución implementada

- Se agregó `rigi_as_utf8()`, que:
  - valida explícitamente bytes UTF-8;
  - convierte cadenas declaradas como Latin-1;
  - no depende de la locale del sistema;
  - detiene el proceso con contexto y posiciones si encuentra bytes inválidos;
  - no sustituye caracteres silenciosamente.
- Se agregó `rigi_utf8_data_frame()` para normalizar únicamente columnas de texto y encabezados, sin alterar números ni fechas.
- Se agregó `rigi_sort_unique_text()` como única ruta para ordenar valores textuales únicos con radix.
- `rigi_filter_values()` vuelve a validar después de separar provincias por `;`.
- La normalización se aplica a `Proyectos`, `Diccionario`, `Variable_Anterior`, hojas auxiliares, planes de inversión, importaciones y el modelo interno derivado.
- Los ordenamientos de sectores, subsectores y proyectos en Planes e Importaciones utilizan el helper común.
- Las etiquetas de los módulos de inversión y del diccionario metodológico se validan antes de agruparlas o incorporarlas al HTML.

## Prueba de regresión agregada

Se creó `tools/qa_encoding.R`. La prueba:

- construye deliberadamente texto UTF-8 marcado como `unknown`;
- prueba `En evaluación`, `Petróleo y Gas`, `Minería`, `Neuquén` y `Río Negro`;
- prueba provincias separadas por `;`;
- verifica las columnas de texto de las tres hojas contractuales y del modelo interno;
- construye y serializa las fichas de aprobados, evaluación y base completa;
- comprueba que las etiquetas con tildes se conserven.

## Archivos fuente modificados

- `R/01_load_data.R`
- `R/02_clean_data.R`
- `R/04_plots.R`
- `R/05_planes_inversion.R`
- `R/06_importaciones.R`
- `R/07_investment_modules.R`
- `.github/workflows/render.yml`
- `tools/qa_encoding.R` — nuevo
- `tools/qa_github_pages.py`

También se regeneraron los reportes JSON de QA producidos por las pruebas existentes.

## Refuerzo de GitHub Actions

El workflow ahora:

- valida la sintaxis de `assets/investment_modules.js`;
- ejecuta `Rscript tools/qa_encoding.R` antes del render;
- comprueba que `investment_modules.js` llegue al sitio generado;
- comprueba los tres módulos de inversión de Aprobados, el módulo de Evaluación y los cronogramas;
- comprueba la presencia de `En evaluación` en las páginas renderizadas de Evaluación y Base de datos.

## Controles ejecutados en este entorno

Finalizaron sin fallas:

- `python3 tools/qa_rigi_update.py`
- `python3 tools/qa_functional_changes.py`
- `python3 tools/qa_navigation.py`
- `python3 tools/qa_mobile_layout.py`
- `python3 tools/qa_github_pages.py`
- `node --check` sobre los cuatro archivos JavaScript
- validación UTF-8 de archivos R, QMD, JavaScript, CSS, YAML, Markdown y Python
- control de delimitadores balanceados en todos los scripts R, incluido `tools/qa_encoding.R`
- validación de estructura, tipos, hojas y contenidos de las descargas XLSX

Resultados de datos confirmados desde el XLSX vigente:

- 41 proyectos: 21 aprobados, 19 en evaluación y 1 rechazado.
- Inversión total: USD 186.190 millones en el universo completo; USD 46.708 millones aprobados; USD 139.209 millones en evaluación.
- Inversión en activos computables aprobada: USD 30.440 millones.
- Inversión comprometida en activos computables durante los primeros dos años: USD 11.533,55411515 millones.
- No existen fechas límite anteriores a la adhesión en los proyectos aprobados.
- Las agregaciones provinciales reconcilian con sus universos de origen.

El archivo `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx` conserva el mismo SHA-256 que la versión actualizada recibida: `82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974`.

## Control pendiente en macOS

El entorno utilizado para preparar el parche no dispone de los ejecutables R y Quarto. Por esa razón no se declara ejecutado aquí el render real ni la prueba R. Antes de hacer commit o push, ejecutar desde la raíz del proyecto en la Mac:

```bash
rm -rf .quarto _freeze _site
find . -maxdepth 1 -type d -name '*_cache' -exec rm -rf {} +
Rscript tools/qa_encoding.R
quarto render
quarto preview
```

El resultado se considera validado para publicación únicamente si `tools/qa_encoding.R` termina con `QA de codificación UTF-8: OK`, las seis páginas completan el render y la vista previa no presenta errores de consola ni desbordamiento horizontal.

## Publicación

No se realizó commit, push ni publicación en GitHub. El workflow continúa desplegando el sitio mediante GitHub Pages Actions sobre `main` o `master`.
