# Revisión responsive

## Control de fuente completado

- Los módulos de ranking, cronograma y comparación usan grillas fluidas y puntos de quiebre en 900, 640, 360 px.
- Las fichas apilan la métrica de Inversión total en celular.
- Los montos usan `white-space: nowrap` y los nombres usan corte por palabra.
- Los tracks se mantienen dentro del ancho del contenedor.
- Pestañas, selectores y filas tienen estados de foco y atributos accesibles.
- `tools/qa_mobile_layout.py` y `tools/qa_final_ui_refinements.py` finalizaron sin fallas.

## Control visual pendiente

No se generaron capturas nuevas porque el entorno de ejecución no contiene R ni Quarto y no fue posible regenerar `_site`. Antes de la entrega final se deben revisar las seis páginas a 1440, 1024, 768, 390, 375 y 320 px, comprobar la consola y guardar las capturas representativas en esta carpeta.
