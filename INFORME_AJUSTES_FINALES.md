# Informe de ajustes visuales finales

## Estado de validación

La implementación fuente está completa y superó todos los controles estáticos y de datos disponibles en el entorno. La validación final permanece **pendiente** porque este entorno no dispone de los ejecutables `Rscript` ni `quarto`; por lo tanto todavía no fue posible ejecutar `tools/qa_encoding.R`, regenerar `_site` ni hacer la revisión visual sobre el sitio renderizado. En cumplimiento del criterio de entrega, no debe considerarse una versión final hasta completar esos pasos.

El XLSX vigente se mantuvo sin modificaciones. SHA-256 comprobado:

`82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974`

## Archivos modificados

- `index.qmd`: eliminación del bloque redundante `hero-meta-grid`.
- `aprobados.qmd`: sustitución de los gráficos de Empleo por el módulo interactivo compartido.
- `comparacion.qmd`: nuevos componentes para Panorama, comparación sectorial/territorial y composición administrativa.
- `metodologia.qmd`: texto del diccionario simplificado, sin variables derivadas.
- `R/04_plots.R`: etiquetas del Resumen y fichas con una única métrica monetaria.
- `R/07_investment_modules.R`: componentes compartidos para inversión, empleo, cronogramas y comparación; diccionario público simplificado.
- `assets/investment_modules.js`: controladores accesibles y formateadores compartidos para los nuevos módulos.
- `styles.css`: estilos responsive de fichas, cronogramas, empleo y comparación.
- `.github/workflows/render.yml`: controles de los nuevos módulos y ejecución del QA final.
- `tools/qa_final_ui_refinements.py`: regresión específica de los ajustes finales.
- `tools/qa_github_pages.py`: validación actualizada de los identificadores renderizados.

## Cambios implementados

### Resumen

- Primer KPI renombrado a **Inversión total de proyectos aprobados**.
- Segundo KPI conserva **Inversión total relevada** y aclara que incluye aprobados y en evaluación con información disponible.
- Eliminado el bloque redundante del encabezado sin dejar una segunda columna vacía.

### Fichas

- Encabezado y panel de detalles muestran una única métrica monetaria: **Inversión total**.
- Las métricas de activos computables y compromiso a dos años se conservan en indicadores, gráficos, tablas, descargas y cálculos.
- Diseño responsive restaurado con apilado del monto en anchos angostos.

### Cronogramas

- Un único módulo con pestañas para compromiso de los primeros dos años y fecha límite.
- Selector 5 / 10 / 15 / Todos, con 10 por defecto y estado compartido entre pestañas.
- Barras finas cuya longitud representa tiempo; monto y fechas visibles; fecha límite marcada con un punto.
- Los registros con fechas faltantes o intervalos inválidos se contabilizan y reportan sin fabricar datos.

### Empleo

- Módulo con vistas Por proyecto / Por sector / Por provincia.
- Selector de cantidad, ranking descendente, participación y formato argentino sin `USD`.
- Reparto provincial en partes iguales, conservando fracciones cuando corresponde.

### Comparación

- Panorama con barras horizontales sobre una escala común.
- Módulo sectorial/territorial con series diferenciadas para Aprobados y En evaluación.
- Participaciones calculadas dentro del total informado del estado respectivo.
- Composición administrativa con Aprobado, En evaluación y Rechazado.

### Diccionario

- Eliminado el apartado **Variables derivadas del Monitor**.
- Excluidas de la visualización pública las variables de clasificación y justificación de preexistencia.
- Las columnas continúan presentes en el XLSX fuente y en la validación del esquema canónico.

## Controles ejecutados

Finalizaron correctamente:

- `python3 tools/qa_rigi_update.py`
- `python3 tools/qa_functional_changes.py`
- `python3 tools/qa_navigation.py`
- `python3 tools/qa_mobile_layout.py`
- `python3 tools/qa_github_pages.py`
- `python3 tools/qa_final_ui_refinements.py`
- `node --check` para todos los archivos JavaScript de `assets/`
- verificación UTF-8 de los archivos fuente
- comprobación del checksum del XLSX

Los controles de datos confirmaron 41 proyectos: 21 aprobados, 19 en evaluación y 1 rechazado. También confirmaron unicidad, esquema, tipos en descargas y reconciliación territorial.

## Controles pendientes por falta de runtime

No pudieron ejecutarse en este entorno:

- `Rscript tools/qa_encoding.R` — `Rscript: command not found`.
- parseo real de todos los scripts con R.
- `quarto render` — `quarto: command not found`.
- revisión de consola sobre `_site` regenerado.
- capturas y validación visual efectiva en 1440, 1024, 768, 390, 375 y 320 px.

El código incluye reglas responsive específicas para esos componentes y los controles estáticos no detectaron desbordamiento global, pero eso no reemplaza la revisión visual del render.

## Comandos requeridos para cerrar la validación

Desde la raíz del proyecto, en un equipo con R, dependencias y Quarto instalados:

```bash
Rscript tools/qa_encoding.R
python3 tools/qa_rigi_update.py
python3 tools/qa_functional_changes.py
python3 tools/qa_navigation.py
python3 tools/qa_mobile_layout.py
python3 tools/qa_github_pages.py
python3 tools/qa_final_ui_refinements.py
rm -rf .quarto _freeze _site
find . -maxdepth 1 -type d -name '*_cache' -exec rm -rf {} +
quarto render
```

Solamente después de que todos finalicen correctamente corresponde revisar visualmente `_site` y generar `rigi-dashboard-ajustes-finales.zip`.
