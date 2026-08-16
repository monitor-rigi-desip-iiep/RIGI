# Control de calidad móvil · versión 9

## Cambios verificados

- El ranking **Principales aprobados por monto** usa áreas de grilla explícitas para el puesto, el contenido y el monto. La disposición se mantiene en dos columnas incluso por debajo de 390 px.
- La cronología Plotly se conserva para tablet y computadora.
- En pantallas de hasta 719 px, la cronología se reemplaza por una lista vertical compacta con fecha de presentación, proyecto, sector y monto.
- La vista móvil presenta seis proyectos recientes y permite desplegar los proyectos anteriores sin cargar una gráfica alta y angosta.
- La insignia `INTERACTIVO` del gráfico de escritorio se oculta en celular para evitar una indicación incorrecta.

## Controles ejecutados

- `tools/qa_v5_requirements.py`: 32 controles aprobados.
- `tools/qa_functional_changes.py`: 25 controles aprobados.
- `tools/qa_mobile_layout.py`: 22 controles aprobados.
- `tools/qa_navigation.py`: 7 controles aprobados.
- Validación sintáctica de `assets/rigi-responsive.js`, `assets/importaciones.js` y `assets/planes_inversion.js`: aprobada.
- Balance de llaves CSS y delimitadores R: aprobado.

Los resultados reproducibles están guardados en los archivos JSON de la carpeta `qa/`.
