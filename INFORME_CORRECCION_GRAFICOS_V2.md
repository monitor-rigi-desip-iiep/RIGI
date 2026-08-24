# Informe de corrección V2 — dependencia Plotly del dashboard RIGI

Fecha: 24 de agosto de 2026

## Resultado

Se corrigió el segundo fallo bloqueante de `rigi_plotly_dependency()`. La versión anterior buscaba `plotly-main` únicamente en el resultado estático de `htmlwidgets::getDependency()` y detenía el render cuando esa lista no lo contenía. La versión V2 obtiene además las dependencias dinámicas de un objeto `plotly::plot_ly()` mínimo, combina ambas listas, las deduplica y recién entonces valida y adjunta Plotly.

El widget mínimo nunca se imprime, no se adjunta y no genera un gráfico oculto. Solo se consulta su campo `$dependencies`.

Este entorno no tiene R, `Rscript`, Quarto ni un navegador ejecutable. Por eso no fue posible regenerar `_site`, inspeccionar las versiones instaladas de los paquetes R ni ejecutar la inicialización real en Chromium. Se ejecutaron todas las validaciones independientes de R/Quarto y se agregó un diagnóstico R obligatorio al workflow para que esas comprobaciones no puedan omitirse en macOS o GitHub Actions.

## Causa exacta del segundo fallo

La implementación V1 hacía lo siguiente:

```r
dependencies <- htmlwidgets::getDependency("plotly", package = "plotly")
```

y exigía inmediatamente que esa lista contuviera una dependencia llamada `plotly-main`.

Ese supuesto era incorrecto. `htmlwidgets::getDependency()` lee las dependencias estáticas del widget, mientras que Plotly agrega dependencias adicionales al construir el htmlwidget. En particular, la implementación de `plotly::as_widget()` incorpora dinámicamente el polyfill de typed arrays, las bibliotecas de Crosstalk, el CSS del widget y el bundle principal de Plotly.js. El código fuente oficial de Plotly R muestra esa composición dinámica y que `plotly-main` usa `plotly-latest.min.js`: [plotly.R/R/plotly.R](https://github.com/plotly/plotly.R/blob/master/R/plotly.R#L2066-L2238).

Por eso los archivos nuevos sí eran leídos por `aprobados.qmd`, pero el helper abortaba antes de generar HTML:

```text
No se pudo resolver la dependencia local plotly-main desde el paquete R plotly.
```

## Diagnóstico de la instalación

Se agregó `tools/diagnose_plotly_dependency.R`. El script registra:

- versión de R;
- versión de `plotly`;
- versión de `htmlwidgets`;
- versión de `htmltools`;
- contenido resumido de `htmlwidgets::getDependency()`;
- contenido y estructura real de `minimal_widget$dependencies`;
- lista final resuelta y deduplicada;
- nombre, versión y script de `plotly-main`.

En este entorno, la ejecución devolvió:

```text
Rscript: command not found
```

Por lo tanto, no se inventan versiones ni una lista exacta de la instalación del usuario. Lo confirmado por el error reproducido en macOS es que su lista estática no contenía `plotly-main`. De acuerdo con la API real de Plotly R, el objeto mínimo es la fuente estable de las dependencias dinámicas; su contenido exacto se imprimirá al ejecutar el diagnóstico con la versión instalada.

La composición esperable —sujeta a la versión instalada y verificada por el script— incluye:

- `typedarray`;
- dependencias de Crosstalk;
- `plotly-htmlwidgets-css`;
- `plotly-main`, cuyo script es `plotly-latest.min.js`.

## Mecanismo definitivo

`R/05_planes_inversion.R` ahora define dos helpers:

1. `rigi_plotly_dependencies()`:
   - obtiene las dependencias estáticas con `htmlwidgets::getDependency()`;
   - crea un `plotly::plot_ly()` mínimo sin imprimirlo;
   - extrae `minimal_widget$dependencies`;
   - normaliza dependencias individuales y listas;
   - combina estáticas y dinámicas;
   - usa `htmltools::resolveDependencies()` para eliminar duplicados;
   - valida `plotly-main` por nombre o por el script `plotly-latest.min.js`;
   - devuelve la lista completa.
2. `rigi_plotly_dependency()`:
   - adjunta la lista a la etiqueta mínima existente;
   - usa `htmltools::singleton()` para evitar duplicaciones.

No se codificó una versión, una ruta interna o una URL. No se usa CDN, no se copia Plotly.js al proyecto y no se llama a `plotly:::plotlyMainBundle()`.

`aprobados.qmd` continúa llamando `rigi_plotly_dependency()` exactamente una vez, antes de `make_planes_inversion_module()` y antes del módulo de Importaciones.

## Orden de carga y GitHub Pages

La QA posterior al render exige este orden efectivo en `aprobados.html`:

1. `site_libs/plotly-main-*/plotly-latest.min.js`;
2. `assets/rigi-responsive.js`;
3. `assets/planes_inversion.js`;
4. `assets/importaciones.js`.

También exige una única referencia a Plotly y una única referencia a cada script personalizado. Todas las rutas deben ser relativas, sin `file://`, rutas `/Users/...` ni CDN, por lo que son compatibles con la base `/RIGI/` de GitHub Pages.

La ruta relativa exacta de `plotly-main` no puede informarse hasta ejecutar Quarto con la versión instalada. El workflow ahora extrae la ruta real desde el HTML, exige una sola coincidencia y comprueba que `_site/<ruta>` sea un archivo no vacío. El patrón esperado es:

```text
site_libs/plotly-main-<versión-instalada>/plotly-latest.min.js
```

## Pruebas corregidas

Se actualizaron:

- `tools/qa_plotly_modules.py`;
- `tools/qa_github_pages.py`;
- `tools/qa_functional_changes.py`;
- `.github/workflows/render.yml`.

`tools/qa_mobile_layout.py` fue auditado y no contenía la suposición defectuosa sobre `getDependency()`, por lo que no necesitó cambios.

Las pruebas de fuente ya no aceptan el helper V1: exigen extracción desde un widget mínimo, `$dependencies`, `resolveDependencies()`, validación de `plotly-main`, ausencia de versiones/rutas codificadas, ausencia de CDN y ausencia de funciones privadas. La comprobación posterior al render sigue siendo conductual: analiza el HTML, verifica el archivo físico en `site_libs` y abre la página en Chromium.

El workflow también:

- ejecuta `quarto --version` y `Rscript tools/diagnose_plotly_dependency.R` antes del render;
- elimina `.quarto`, `_freeze`, `_site`, `*_cache` y `*_files`;
- comprueba que la referencia a Plotly aparezca una sola vez;
- comprueba que el JavaScript referenciado exista;
- ejecuta `python3 tools/qa_plotly_modules.py` con navegador obligatorio.

## Datos y checksum

No se modificó ningún archivo de datos.

El XLSX principal conserva el SHA-256 solicitado:

```text
82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974
```

### Planes de inversión

- 264 observaciones en `Datos_long`.
- Años 2024–2056; incluye el período predeterminado 2024–2034.
- `monto_mill_usd` numérico.
- Sectores y subsectores informados.
- Contenedores anual y acumulado presentes.

### Importaciones

- 1.932 observaciones en `data/impo_rigi_aduana.csv`.
- `fob_dolar` numérico; la conversión a `fob_mill_usd` permanece en R.
- 10 proyectos y 5 sectores informados.
- Cuatro contenedores —mensual y acumulado, por sector y por proyecto— presentes.

## Archivos modificados respecto de la V1

- `R/05_planes_inversion.R`.
- `tools/diagnose_plotly_dependency.R` — nuevo.
- `tools/qa_plotly_modules.py`.
- `tools/qa_github_pages.py`.
- `tools/qa_functional_changes.py`.
- `.github/workflows/render.yml`.
- archivos JSON de QA regenerados por las pruebas.
- `INFORME_CORRECCION_GRAFICOS_V2.md` — nuevo.

No se modificaron los JavaScript, CSS, QMD de contenido, datos ni descargas de la V1. Se conservaron el mensaje accesible de contingencia y todos los cambios funcionales previos.

No se hizo commit, push ni publicación.

## Pruebas ejecutadas

| Prueba | Resultado |
|---|---|
| SHA-256 del XLSX principal | OK |
| Validación independiente de Planes | OK: 264 filas, montos numéricos, sectores/subsectores completos |
| Validación independiente de Importaciones | OK: 1.932 filas, importes numéricos, proyectos/sectores completos |
| `python3 tools/qa_rigi_update.py` | OK |
| `python3 tools/qa_functional_changes.py` | OK |
| `python3 tools/qa_navigation.py` | OK |
| `python3 tools/qa_mobile_layout.py` | OK |
| `python3 tools/qa_github_pages.py` | OK |
| `python3 tools/qa_final_ui_refinements.py` | OK |
| `python3 tools/qa_peelp_cards.py` | OK |
| `python3 tools/qa_plotly_modules.py --source-only` | OK |
| Sintaxis de todos los JavaScript con `node --check` | OK |
| Compilación de todos los Python de `tools/` | OK |
| `Rscript tools/diagnose_plotly_dependency.R` | No ejecutable: `Rscript` no instalado |
| `Rscript tools/qa_encoding.R` | No ejecutable: `Rscript` no instalado |
| `quarto render` | No ejecutable: `quarto` no instalado |
| `python3 tools/qa_plotly_modules.py` sobre `_site` nuevo | Pendiente del render; falla correctamente si `_site` no existe |
| Revisión en Chromium a seis anchos | Pendiente del render y navegador |

## Estado individual de los seis gráficos

| Gráfico | Fuente, datos, contenedor y lógica | Inicialización real V2 |
|---|---:|---:|
| Planes — anual | OK | Pendiente de render/navegador |
| Planes — acumulado | OK | Pendiente de render/navegador |
| Importaciones por sector — mensual | OK | Pendiente de render/navegador |
| Importaciones por sector — acumulado | OK | Pendiente de render/navegador |
| Importaciones por proyecto — mensual | OK | Pendiente de render/navegador |
| Importaciones por proyecto — acumulado | OK | Pendiente de render/navegador |

## Consola y revisión responsive

La V1 había documentado que ambos módulos agotaban sus reintentos con `initializationError="window.Plotly"`. El segundo fallo V2 ocurría todavía antes, durante knitr, por lo que no había una consola de navegador nueva que inspeccionar.

La QA estática responsive pasó. La revisión real de 1440, 1024, 768, 390, 375 y 320 px permanece codificada en `qa_plotly_modules.py`; exige seis gráficos Plotly con SVG, una sola instancia por contenedor, módulos inicializados, ausencia de `data-initialization-error`, ausencia de mensajes de contingencia, consola limpia y sin scroll horizontal.

## Validación final en macOS

Desde la raíz del proyecto:

```bash
Rscript tools/diagnose_plotly_dependency.R

rm -rf .quarto _freeze _site
find . -maxdepth 1 -type d -name '*_cache' -exec rm -rf {} +
find . -maxdepth 1 -type d -name '*_files' -exec rm -rf {} +
quarto render

Rscript tools/qa_encoding.R
python3 tools/qa_rigi_update.py
python3 tools/qa_functional_changes.py
python3 tools/qa_navigation.py
python3 tools/qa_mobile_layout.py
python3 tools/qa_github_pages.py
python3 tools/qa_final_ui_refinements.py
python3 tools/qa_peelp_cards.py
python3 tools/qa_plotly_modules.py

find assets -name '*.js' -print0 | xargs -0 -n1 node --check
```

Después del render, los comandos siguientes deben devolver una referencia y un archivo real:

```bash
test -s _site/aprobados.html
grep -F 'site_libs/plotly-main-' _site/aprobados.html
find _site/site_libs -path '*plotly-main-*' -type f -name '*.js' -print
```

Para abrir el sitio manualmente:

```bash
quarto preview
```

La validación completa de navegador también puede hacerse obligatoria localmente con:

```bash
RIGI_REQUIRE_BROWSER=1 python3 tools/qa_plotly_modules.py
```
