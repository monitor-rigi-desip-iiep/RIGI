# Informe de actualización integral del Monitor de Proyectos RIGI

## Alcance implementado

Se migró el proyecto al esquema canónico del XLSX `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx`, que se conserva como fuente de verdad. La carga ahora exige las hojas `Proyectos`, `Diccionario` y `Variable_Anterior`, valida encabezados, variables inesperadas, definiciones editoriales e identificadores duplicados, y detiene la ejecución con mensajes explícitos ante desvíos.

La transformación entre la fuente y el modelo interno quedó centralizada en `R/02_clean_data.R`. Los estados se normalizan como `Aprobado`, `En evaluación` y `Rechazado`; las fechas se convierten sin operaciones de zona horaria y los montos permanecen numéricos. Los nombres visibles, unidades y descripciones de los nuevos módulos provienen de `Diccionario`.

## Archivos modificados o incorporados

- `R/01_load_data.R`: contrato de hojas y esquema, carga de `Diccionario` y `Variable_Anterior`, validación de `id_proyecto`.
- `R/02_clean_data.R`: migración canónica, normalización de estados, nuevas variables monetarias y fechas, asignación provincial, limpieza de faltantes y generación de XLSX.
- `R/03_indicators.R`: nuevos totales de inversión y activos computables, indicadores aprobados y PEELP, formato argentino y faltantes como `No informado`.
- `R/04_plots.R`: KPI, resumen, ranking corregido, fichas, tabla, etiquetas editoriales, atribución preservada y nuevo hito normativo.
- `R/07_investment_modules.R` (nuevo): módulos interactivos de inversión, cronogramas y diccionario metodológico.
- `_partials/setup-core.qmd`: carga del diccionario, mapeo, módulo nuevo y regeneración de descargas.
- `aprobados.qmd`: tres módulos de inversión, cronogramas, indicadores PEELP y tabla/fichas ampliadas.
- `evaluacion.qmd`: panorama sin el KPI de activos computables y módulo de inversión total informada.
- `base-datos.qmd`: descarga principal únicamente en XLSX.
- `metodologia.qmd`: diccionario de variables de origen y derivadas generado desde datos.
- `assets/investment_modules.js` (nuevo): pestañas, selector Top 5/10/15/todos, formato `es-AR`, accesibilidad y conservación de estado.
- `styles.css`: grillas y tablas responsive, montos sin cortes, tarjetas compactas, módulos de inversión, cronogramas y diccionario.
- `_quarto.yml`: recurso JavaScript nuevo y atribución visible `@_LucasOrdoñez` preservada.
- `tools/qa_rigi_update.py` (nuevo) y pruebas existentes actualizadas al esquema canónico.
- `downloads/base_interactiva_aprobados.xlsx`, `downloads/base_interactiva_pendientes.xlsx` y `downloads/base_completa.xlsx`: regenerados con hojas `Proyectos` y `Diccionario`.

## Criterios de cálculo y agregación

- **Inversión total:** suma de `inversion_total_mill_usd` para el universo indicado.
- **Inversión en activos computables:** suma de `inversion_activos_computables_mill_usd` para proyectos con dato disponible.
- **Inversión comprometida en activos computables — primeros 2 años:** suma de `inversion_activos_computables_comprometida_2_anios_mill_usd` para proyectos con información.
- Los módulos por proyecto, sector y provincia se ordenan en forma descendente y usan Top 10 por defecto.
- En agregaciones provinciales, cada monto de un proyecto multiprovincial se divide por igual entre sus provincias. Los totales provinciales reconciliaron con el universo original para las tres métricas.
- La barra del cronograma de dos años comienza en `fecha_adhesion_rigi` y finaliza 24 meses después; su longitud representa tiempo, no monto ni ejecución.
- El segundo cronograma usa `fecha_adhesion_rigi` y `fecha_limite_inversion_minima_activos_computables`. No se imputaron fechas.
- El XLSX fuente contiene fórmulas con resultado cacheado igual a cero para el compromiso de dos años cuando ambos componentes anuales están vacíos en proyectos no aprobados. En la interfaz esos casos se tratan como faltantes; las descargas conservan la fuente canónica sin reescribirla.

## Resultados de datos

- Proyectos: **41** en total; **21 aprobados**, **19 en evaluación** y **1 rechazado**.
- Inversión total: **USD 186.190 millones** en el universo completo; **USD 46.708 millones** en aprobados; **USD 139.209 millones** en evaluación.
- Inversión en activos computables: **USD 30.440 millones**, informada en los 21 proyectos aprobados y no informada en los 19 proyectos en evaluación.
- Inversión comprometida en activos computables — primeros 2 años: **USD 11.533,6 millones** para aprobados.
- Proyectos PEELP aprobados: **5**; los cinco tienen información para las tres métricas de inversión.
- Cronogramas: los 21 aprobados tienen fecha de adhesión y fecha límite; no se detectaron fechas límite anteriores a la adhesión.
- Diferencias entre año 1 + año 2 y el total de dos años cuando ambos componentes están informados: **0 casos**.
- Se detectó un proyecto en evaluación con `fecha_presentacion` consignada como `No informado`; se mantiene como faltante.

## Descargas

Las tres bases principales se regeneraron desde el XLSX vigente. Cada archivo contiene:

1. `Proyectos`, con 28 variables canónicas y tipos de Excel preservados.
2. `Diccionario`, filtrado a las mismas 28 variables y en el mismo orden.

Se excluyeron `clasificacion_preexistencia_boletin_oficial` y `justificacion_preexistencia_boletin_oficial`. Se eliminaron los tres CSV de la base principal. Se conservaron `planes_inversion.csv` e `importaciones_proyectos.csv`, porque pertenecen a módulos distintos.

## Pruebas ejecutadas

Todas las pruebas ejecutables disponibles finalizaron sin fallas:

- `python tools/qa_rigi_update.py --root .`
- `python tools/qa_v5_requirements.py --root .`
- `python tools/audit_dashboard.py --root . --output qa/final_audit.json`
- `python tools/qa_functional_changes.py`
- `python tools/qa_mobile_layout.py --root . --output qa/mobile_optimization_source_qa.json`
- `python tools/qa_github_pages.py`
- `python tools/qa_navigation.py --root . --output qa/navigation_source_qa.json`
- `node --check` para los cuatro scripts JavaScript.
- Compilación de sintaxis de todos los scripts Python.
- Control estático de delimitadores de todos los scripts R.
- Inspección visual de las hojas exportadas y búsqueda de errores `#REF!`, `#DIV/0!`, `#VALUE!`, `#NAME?` y `#N/A`: sin errores remanentes.

Los resultados reproducibles se encuentran en `qa/integral_update_qa.json`, `qa/final_audit.json` y los demás archivos `*_source_qa.json`. Las vistas de control de los XLSX están en `qa/xlsx_previews/`.

## Responsive y accesibilidad

Se revisaron las reglas fuente para 1440, 1024, 768, 390, 375 y 320 px. Los componentes usan grillas fluidas y puntos de quiebre en 1100, 900, 719, 640 y 390 px; el overflow de tablas, diccionario y cronogramas queda contenido dentro del componente. Los nombres no usan corte letra por letra, los montos usan `white-space: nowrap`, los controles incluyen foco visible y las pestañas admiten flechas izquierda/derecha. Los módulos conservan el selector de cantidad al cambiar de vista.

## Limitación de render en este entorno

La imagen de ejecución proporcionada no incluye los binarios `R`, `Rscript` ni `quarto`, y tampoco incluye un navegador headless instalado. Por ese motivo no fue posible ejecutar `quarto render`, abrir el sitio regenerado ni producir capturas visuales reales del build en este entorno. Para evitar una entrega engañosa, el `_site` antiguo no se incluye en el ZIP final como si estuviera actualizado. El código fuente, las descargas y las pruebas estáticas quedaron listos para que el pipeline existente ejecute un render limpio en un entorno con R y Quarto.

Comando de reproducción pendiente en un entorno compatible:

```bash
rm -rf .quarto _freeze _site
quarto render
```

Después de ese render debe completarse la inspección visual final y la revisión de consola en los seis anchos indicados antes de publicar.
