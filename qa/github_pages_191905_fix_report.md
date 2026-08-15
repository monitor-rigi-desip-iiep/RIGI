# Corrección definitiva de gráficos vacíos en GitHub Pages

## Causa confirmada

La publicación servía correctamente `assets/rigi-responsive.js` con HTTP 200, pero `aprobados.html` no contenía ninguna etiqueta `<script>` que lo cargara. Como consecuencia, los módulos de Planes e Importaciones terminaban con `data-initialization-error="window.RigiResponsive"` y los seis contenedores de gráficos quedaban vacíos.

En el proyecto adjunto se encontró la explicación exacta:

- `_quarto.yml` declara `include-in-header: assets/rigi-head.html`;
- `assets/rigi-head.html` existe en el directorio local;
- `.gitignore` contiene la regla general `*.html`;
- `git check-ignore` confirmaba que `assets/rigi-head.html` estaba ignorado;
- `git ls-files assets/rigi-head.html` no devolvía ningún resultado.

Por eso el render local funcionaba —el archivo existía en la computadora—, pero un checkout limpio de GitHub Actions nunca recibía el include. El workflow podía terminar con estado `Success` porque no comprobaba que esa dependencia hubiera quedado incorporada al HTML final.

## Correcciones aplicadas

1. Se agregó `!assets/rigi-head.html` a `.gitignore`, de modo que el include pueda versionarse.
2. Se conservó la carga global mediante `include-in-header`, que coloca la dependencia responsive antes de los módulos diferidos.
3. Se amplió la cobertura de activación del workflow para páginas, partials, assets, scripts R, datos y descargas.
4. Se añadieron las dependencias R explícitas `htmlwidgets`, `jsonlite` y `writexl`.
5. El workflow elimina `.quarto`, `_freeze`, `_site` y los cachés de página antes del render.
6. Antes del render, CI comprueba que `assets/rigi-head.html` exista y esté versionado, y valida la sintaxis de los tres JavaScript.
7. Después del render, CI comprueba:
   - la existencia de los tres assets dentro de `_site`;
   - la dependencia Plotly;
   - una única referencia a `rigi-responsive.js`;
   - los diez IDs requeridos por Planes e Importaciones.

Con estas comprobaciones, un artifact que vuelva a perder el include fallará antes de llegar a GitHub Pages.

## QA realizado

- Sintaxis JavaScript: correcta en los tres archivos.
- YAML: válido en `_quarto.yml` y el workflow.
- Include global: único, existente y no ignorado después de la corrección.
- Configuración de página: sin bloques `format:` que sobrescriban el formato global.
- IDs interactivos: presentes en las fuentes R.
- Navegación y anchors: sin errores estáticos.
- Referencias institucionales prohibidas: ninguna.
- Regresión de datos: idéntica antes y después.

## Estado de la publicación

La URL pública seguirá mostrando la versión defectuosa hasta que todos los cambios —incluido el archivo nuevo `assets/rigi-head.html`— se incorporen al commit y finalice el nuevo deployment. El workflow corregido impedirá publicar nuevamente un artifact incompleto.

## Limitación del entorno de entrega

Este entorno no dispone de los ejecutables `Rscript` ni `quarto` y no tiene credenciales para escribir en el repositorio remoto. Por ese motivo, la ejecución real de `quarto render`, la inspección del nuevo artifact y la captura posterior deben completarse mediante el workflow corregido después del próximo `git push`.
