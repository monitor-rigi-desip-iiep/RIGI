# Corrección de gráficos vacíos en GitHub Pages

## Causa confirmada

`_quarto.yml` incluía `assets/rigi-after-body.html`, pero `.gitignore` excluía todos los archivos `*.html`. El include existía en el directorio local y por eso un render local anterior podía incorporarlo, pero no estaba versionado. Un checkout limpio de GitHub Actions no recibía ese archivo y el HTML publicado no cargaba `assets/rigi-responsive.js`.

Los scripts de Planes de inversión e Importaciones requieren simultáneamente `window.Plotly` y `window.RigiResponsive`. Al faltar la segunda dependencia, ambos quedaban reintentando en silencio y los seis contenedores permanecían vacíos.

Los bloques `format:` repetidos en las páginas no fueron la causa observada —el HTML local anterior sí contenía el include—, pero se eliminaron porque duplicaban la configuración global y podían volver ambiguo el merge de opciones entre versiones de Quarto.

## Corrección aplicada

- Se reemplazó el include local no versionable por `assets/rigi-head.html`.
- `.gitignore` permite versionar expresamente ese archivo.
- `_quarto.yml` lo carga globalmente mediante `include-in-header`, antes de los módulos interactivos.
- Se eliminaron los bloques `format:` redundantes de las seis páginas.
- Los módulos esperan las dependencias durante un máximo de 10 segundos y emiten un error descriptivo si falta alguna; ya no existe un bucle infinito silencioso.
- La inicialización continúa siendo idempotente mediante `root.dataset.initialized`.
- El workflow ahora reacciona a cambios en páginas, partials, assets, R, datos y descargas; instala las dependencias faltantes y elimina estado generado antes de `quarto render`.

## QA y regresión

- Sintaxis válida en los tres JavaScript.
- YAML válido en `_quarto.yml` y el workflow.
- Include global único, existente y no ignorado por Git.
- Los diez IDs de los módulos y gráficos se generan desde las fuentes R.
- Navegación y enlaces internos sin errores estáticos.
- Regresión de datos idéntica antes y después.

Los resultados detallados están en:

- `qa/github_pages_live_before.json`
- `qa/github_pages_source_qa.json`
- `qa/github_pages_navigation_qa.json`
- `qa/github_pages_baseline_audit.json`
- `qa/github_pages_final_audit.json`

## Limitación del entorno de entrega

El entorno usado para preparar esta corrección no dispone de los ejecutables `Rscript` ni `quarto`, por lo que no se fabricó ni se incluyó un `_site` local nuevo. El workflow corregido está preparado para ejecutar el render limpio en GitHub Actions. La comprobación visual posterior y la captura final requieren publicar este commit y esperar a que concluya el deployment.
