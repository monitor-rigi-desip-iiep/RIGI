# Optimización mobile — informe de implementación y QA

## Diagnóstico confirmado

- Los gráficos horizontales conservaban en mobile el margen izquierdo calculado para desktop (hasta 255 px) aun dentro de un lienzo mínimo de 520 px. Esto reducía de manera excesiva el área útil de las barras.
- Importaciones calculaba el rango del eje Y con el máximo de todos los meses seleccionados. En un viewport horizontal que mostraba sólo los primeros períodos, valores posteriores mucho mayores comprimían las barras visibles contra cero.
- La subnavegación mobile era sticky, pero el desplazamiento hacia anchors no reservaba de forma unificada la altura de la navegación global, la local y un margen de lectura.
- El botón “Volver arriba” podía superponerse con las pistas de desplazamiento en pantallas con safe areas.

## Correcciones

- Se limita el margen izquierdo móvil de barras horizontales a un máximo útil de 168 px y se reserva margen derecho para monto y porcentaje. Los nombres continúan envueltos y el texto completo permanece en el tooltip.
- Importaciones utiliza 50 px por período en mobile, muestra seis períodos antes de habilitar scroll y reduce su altura a 390 px.
- Cuando existe overflow horizontal real en mobile, el eje Y de Importaciones se recalcula con los períodos actualmente visibles. La actualización durante el scroll está limitada a un `requestAnimationFrame` y el listener es pasivo e idempotente.
- Se conservan las etiquetas mensuales en dos líneas (`mes` / `año`), todos los datos, filtros y tooltips.
- Se unificaron `scroll-padding-top` y `scroll-margin-top` para la navegación sticky y se agregó soporte para safe areas al control “Volver arriba”.
- El workflow ejecuta la nueva prueba de layout antes del render.

## Regresión de datos

Los archivos `qa/mobile_optimization_baseline.json` y `qa/mobile_optimization_final.json` son idénticos.

- Proyectos: 40 (21 aprobados, 18 en evaluación y 1 rechazado).
- Monto total: USD 135.190 millones.
- Monto aprobado: USD 46.708 millones.
- Monto en evaluación: USD 88.209 millones.
- Activos computables aprobados: USD 30.440 millones.
- Empleo informado aprobado: 95.158.
- Planes de inversión: 264 filas; USD 46.024 millones.
- Importaciones: 1.846 filas; USD 291.382.529,31.
- Todos los pares CSV/XLSX conservan forma, columnas y valores equivalentes.

## Pruebas superadas

- Sintaxis JavaScript de `rigi-responsive.js`, `planes_inversion.js` e `importaciones.js`.
- QA funcional de filtros, defaults de Planes, cronología, dropdown de Importaciones, Hitos, recursos y workflow.
- QA de navegación y anchors.
- QA específica mobile: 19/19 controles aprobados.
- YAML del workflow válido, CSS con delimitadores balanceados y `git diff --check` sin errores.
- QA de GitHub Pages: scripts versionados, carga única del bootstrap responsive, IDs interactivos, inicialización acotada e idempotente y cobertura de CI.

## Limitación del entorno

Este entorno no dispone de R ni del ejecutable de Quarto, por lo que no fue posible ejecutar aquí un render local nuevo ni capturas del HTML modificado. El workflow versionado elimina el estado generado, ejecuta `quarto render`, valida los módulos y publica `_site` en cada push de los archivos afectados.
