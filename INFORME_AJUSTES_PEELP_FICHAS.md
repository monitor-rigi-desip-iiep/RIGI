# Informe de ajustes PEELP y fichas

## Estado de la entrega

Los cambios de fuente y las pruebas estáticas quedaron implementados. La entrega final permanece **pendiente de render y revisión visual**, porque el entorno de ejecución disponible no contiene los binarios `R`, `Rscript`, `quarto` ni un navegador headless. La copia recibida tampoco contiene un directorio `_site` que corresponda a esta versión.

Por esa razón no se generó el archivo final `rigi-dashboard-peelp-fichas.zip`: hacerlo sin un `quarto render` exitoso incumpliría el criterio de aceptación expresamente solicitado.

## Fuente de datos

- Archivo: `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx`.
- SHA-256 verificado antes y después de los cambios: `82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974`.
- Hojas verificadas: `Proyectos`, `Diccionario` y `Variable_Anterior`.
- Registros no vacíos: 41.
- Proyectos aprobados: 21.
- Proyectos PEELP aprobados: 5.

## Cambios implementados

### Participación PEELP

- Se reemplazó el gráfico circular Plotly por dos barras horizontales accesibles: `PEELP` y `No PEELP`.
- Cada barra usa como escala el monto total informado de proyectos aprobados.
- Se muestran monto y participación con notación argentina.
- Las filas admiten foco de teclado y exponen categoría, monto, participación y universo mediante texto accesible.
- Se eliminó la función circular anterior para impedir regresiones.

### Ranking PEELP

- Se sustituyó el Plotly anterior por el componente de ranking reutilizado de los módulos de inversión.
- Se mantiene el universo de proyectos aprobados PEELP y la variable `inversion_total_mill_usd`.
- Orden descendente por monto.
- Participación calculada sobre el monto total informado de todos los proyectos aprobados.
- Selector `5 / 10 / 15 / Todos`, con 5 por defecto.
- No se agregaron pestañas vacías de sector o provincia.

### Fichas de proyectos

- El encabezado conserva una sola métrica monetaria: `Inversión total`.
- Dentro de `Ver detalles` se muestran, en este orden:
  1. Inversión total.
  2. Inversión en activos computables.
  3. Inversión comprometida en activos computables — primeros 2 años.
- Los faltantes se muestran como `No informado`; el cero informado no se trata como faltante.
- El cambio se aplica al generador compartido de fichas, por lo que alcanza Aprobados, Evaluación, PEELP y Base completa sin duplicar implementaciones.

## Archivos modificados

- `R/04_plots.R`
- `R/07_investment_modules.R`
- `aprobados.qmd`
- `assets/investment_modules.js`
- `styles.css`
- `.github/workflows/render.yml`
- `tools/qa_final_ui_refinements.py`
- `tools/qa_github_pages.py`
- `tools/qa_peelp_cards.py` (nuevo)
- `INFORME_AJUSTES_PEELP_FICHAS.md` (nuevo)

## Validaciones ejecutadas con resultado satisfactorio

- `python3 tools/qa_peelp_cards.py`
- `python3 tools/qa_final_ui_refinements.py`
- `python3 tools/qa_rigi_update.py`
- `python3 tools/qa_functional_changes.py`
- `python3 tools/qa_navigation.py`
- `python3 tools/qa_mobile_layout.py`
- `python3 tools/qa_github_pages.py`
- `node --check` sobre todos los archivos JavaScript de `assets/`.

Resultados principales:

- Monto aprobado informado: USD 46.708 millones.
- Monto PEELP informado: USD 35.059 millones.
- Monto no PEELP informado: USD 11.649 millones.
- Reconciliación PEELP + No PEELP: exacta.
- Suma de participaciones: 100 %.
- Pruebas estáticas fallidas: 0.
- Sintaxis JavaScript inválida: 0 archivos.

Los reportes detallados se encuentran en `qa/`, especialmente:

- `qa/peelp_cards_source_qa.json`
- `qa/final_ui_source_qa.json`
- `qa/integral_update_qa.json`
- `qa/github_pages_source_qa.json`

## Validaciones pendientes por falta de runtime

No fue posible ejecutar en este entorno:

```bash
Rscript tools/qa_encoding.R
quarto render
```

Tampoco fue posible efectuar la revisión real del HTML regenerado, la consola del navegador ni las capturas en 1440, 1024, 768, 390, 375 y 320 px.

Para cerrar la entrega se requiere un entorno con R, las dependencias del proyecto y Quarto. Allí deben ejecutarse el test de codificación, el render limpio, las pruebas Python nuevamente y la revisión visual. Solamente después corresponde incluir `_site` y generar `rigi-dashboard-peelp-fichas.zip`.
