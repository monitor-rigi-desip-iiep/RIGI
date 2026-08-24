# Informe de corrección — gráficos de Planes de inversión e Importaciones

Fecha: 24 de agosto de 2026

## Resultado

Se corrigió en las fuentes la dependencia que impedía inicializar los gráficos personalizados de:

- Planes de inversión por año.
- Planes de inversión acumulados.
- Importaciones mensuales por sector.
- Importaciones acumuladas por sector.
- Importaciones mensuales por proyecto.
- Importaciones acumuladas por proyecto.

La solución declara explícitamente la biblioteca Plotly provista por el paquete R `plotly`, sin CDN, sin copiar rutas internas versionadas y sin insertar un gráfico ficticio. También se agregó una prueba de regresión que valida el HTML renderizado y, cuando hay navegador disponible, exige la inicialización efectiva de los seis gráficos en seis anchos de pantalla.

Este entorno de trabajo no dispone de R, `Rscript`, Quarto ni un binario de navegador. Por ese motivo no fue posible generar un `_site` nuevo ni ejecutar la revisión visual final. El ZIP entregado contiene las fuentes corregidas, las bases, las descargas, las pruebas y este informe; no incluye el `_site` recibido, porque se eliminó antes de trabajar y no podía regenerarse de manera legítima sin Quarto.

## Causa raíz confirmada

El `_site/aprobados.html` recibido contenía correctamente:

- `assets/rigi-responsive.js`, una vez;
- `assets/planes_inversion.js`, una vez;
- `assets/importaciones.js`, una vez;
- los dos módulos, sus seis contenedores y sus bloques JSON.

Sin embargo, la lista de scripts externos no contenía ninguna ruta `site_libs/plotly-main-*` ni otro recurso que definiera `window.Plotly`.

Ambos módulos comprueban `typeof window.Plotly` antes de inicializarse. Se ejecutó su bootstrap original en un entorno DOM controlado, manteniendo disponible `window.RigiResponsive`. Después de los 100 intentos acotados, los dos módulos terminaron con:

```text
data-initialization-error="window.Plotly"
```

Los errores capturados fueron:

```text
[Monitor RIGI] No se pudo inicializar Planes de inversión. Dependencias faltantes: window.Plotly.
[Monitor RIGI] No se pudo inicializar Importaciones. Dependencias faltantes: window.Plotly.
```

Esto confirma la hipótesis: al reemplazar los antiguos widgets Plotly generados por R por módulos HTML/JavaScript personalizados, desapareció la dependencia automática que antes aportaba `htmlwidgets`. Los módulos conservaron llamadas directas a `window.Plotly`, pero ninguna fuente declaró ya la biblioteca.

## Por qué `quarto render` podía terminar correctamente

Quarto y knitr generan HTML a partir de las fuentes, pero no ejecutan el JavaScript de la página ni comprueban que cada símbolo global utilizado por los módulos exista en el navegador. Los archivos JavaScript eran sintácticamente válidos, los contenedores y los datos estaban presentes y el render estático no tenía motivos para fallar. El error aparecía más tarde, durante la inicialización en el cliente, cuando `window.Plotly` seguía indefinido.

## Corrección implementada

Se agregó `rigi_plotly_dependency()` en `R/05_planes_inversion.R`.

El helper:

1. obtiene programáticamente las dependencias mediante `htmlwidgets::getDependency("plotly", package = "plotly")`;
2. conserva la lista completa devuelta por `htmlwidgets`, sin filtrar dependencias auxiliares;
3. verifica que exista una dependencia cuyo nombre comience con `plotly-main`;
4. adjunta la lista mediante `htmltools::attachDependencies()` a una etiqueta mínima oculta;
5. utiliza `htmltools::singleton()` como protección adicional contra duplicaciones.

La etiqueta no contiene ni fuerza ningún gráfico. Su única función es registrar una dependencia HTML real para que Quarto copie el JavaScript local a `_site/site_libs/`.

`aprobados.qmd` invoca el helper exactamente una vez, inmediatamente antes de `make_planes_inversion_module()`. El orden que la prueba exige en el HTML final es:

1. `site_libs/plotly-main-*/plotly-latest.min.js`;
2. `assets/rigi-responsive.js`;
3. `assets/planes_inversion.js`;
4. `assets/importaciones.js`.

La prueba también exige una sola referencia a Plotly y una sola referencia a cada script personalizado. El recurso continúa siendo relativo y compatible con la ruta `/RIGI/` de GitHub Pages.

No fue posible inspeccionar en R el objeto devuelto por `getDependency()` en este entorno porque `Rscript` no está instalado. El helper valida en tiempo de render la presencia de `plotly-main`, y la nueva prueba posterior al render valida tanto la referencia HTML como la existencia física del JavaScript dentro de `_site/site_libs/`.

## Fortalecimiento de JavaScript

Se conservaron:

- la inicialización idempotente;
- `data-initialized`;
- `data-initialization-error`;
- los 100 reintentos de 100 ms;
- el único temporizador activo por módulo;
- los mensajes técnicos en consola.

Si las dependencias continúan ausentes al finalizar el plazo, cada módulo inserta ahora un mensaje visible y accesible con `role="alert"`:

```text
No se pudo cargar el componente gráfico.
```

Los detalles técnicos permanecen únicamente en la consola y en `data-initialization-error`. Si las dependencias aparecen durante los intentos, el mensaje se elimina antes de inicializar. La prueba DOM del estado de falla confirmó el texto, el rol accesible y el diagnóstico técnico para ambos módulos.

## Datos verificados

La base principal conserva el checksum requerido:

```text
82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974
```

No se modificó ningún archivo de datos.

### Planes de inversión

- 264 observaciones en `Datos_long`.
- Período: 2024–2056; contiene 2024 y 2034.
- `monto_mill_usd` numérico.
- Sectores y subsectores completos.
- Contenedores `planes-annual-chart` y `planes-cumulative-chart` presentes en las fuentes.

### Importaciones

- 1.932 observaciones en `data/impo_rigi_aduana.csv`.
- Período: enero de 2025 a julio de 2026.
- 10 proyectos y 5 sectores informados.
- `fob_dolar` numérico; la conversión a `fob_mill_usd` se conserva en R.
- Contenedores mensuales y acumulados, por sector y por proyecto, presentes en las fuentes.

## Nueva prueba de regresión

Se creó `tools/qa_plotly_modules.py`.

En modo posterior al render verifica:

1. checksum del XLSX principal;
2. existencia y sintaxis Node de los dos JavaScript;
3. seis contenedores en las fuentes;
4. JSON de Planes e Importaciones no vacío y con campos válidos;
5. declaración explícita de Plotly en R y llamada única en `aprobados.qmd`;
6. una sola referencia `site_libs/plotly-main-*` en `aprobados.html`;
7. existencia física del JavaScript de Plotly en `_site/site_libs/`;
8. orden de carga anterior a los scripts personalizados;
9. ausencia de rutas locales absolutas y enlaces con esquema `file:`;
10. ausencia de IDs duplicados;
11. ausencia de `data-initialization-error` después de la inicialización real;
12. existencia de un único gráfico Plotly, con SVG y dimensiones positivas, dentro de cada uno de los seis contenedores;
13. consola y `pageerror` sin errores;
14. ausencia de scroll horizontal de página;
15. funcionamiento en 1440, 1024, 768, 390, 375 y 320 px.

El workflow instala Playwright/Chromium para esta verificación y establece `RIGI_REQUIRE_BROWSER=1`; por lo tanto, en GitHub Actions la falta de navegador no se convierte en una omisión silenciosa.

## Archivos modificados

- `R/05_planes_inversion.R`.
- `aprobados.qmd`.
- `assets/planes_inversion.js`.
- `assets/importaciones.js`.
- `styles.css`.
- `tools/qa_plotly_modules.py` — nuevo.
- `tools/qa_github_pages.py`.
- `tools/qa_functional_changes.py`.
- `tools/qa_mobile_layout.py`.
- `.github/workflows/render.yml`.
- salidas JSON de QA regeneradas por las pruebas estáticas.
- `INFORME_CORRECCION_GRAFICOS.md` — nuevo.

No se hizo commit, push ni publicación.

## Pruebas ejecutadas

| Prueba | Resultado |
|---|---|
| Confirmación del checksum principal | OK |
| Reproducción del error de dependencia en DOM controlado | OK; falta exclusiva: `window.Plotly` |
| Validación independiente de datos de Planes e Importaciones | OK |
| `python3 tools/qa_plotly_modules.py --source-only` | OK |
| `python3 tools/qa_rigi_update.py` | OK |
| `python3 tools/qa_functional_changes.py` | OK |
| `python3 tools/qa_navigation.py` | OK |
| `python3 tools/qa_mobile_layout.py` | OK |
| `python3 tools/qa_github_pages.py` | OK |
| `python3 tools/qa_final_ui_refinements.py` | OK |
| `python3 tools/qa_peelp_cards.py` | OK |
| `find assets -name '*.js' ... node --check` | OK para todos los JavaScript |
| Compilación de los Python modificados | OK |
| `Rscript tools/qa_encoding.R` | Pendiente: `Rscript` no instalado |
| Render limpio con `quarto render` | Pendiente: Quarto no instalado |
| `tools/qa_plotly_modules.py` completo sobre `_site` nuevo | Pendiente del render |
| Revisión visual real en navegador | Pendiente: no existe binario Chromium/Firefox/WebKit |

## Estado de los seis gráficos

| Gráfico | Fuentes, datos y contenedor | Inicialización real del `_site` nuevo |
|---|---:|---:|
| Planes por año | OK | Pendiente de render/navegador |
| Planes acumulados | OK | Pendiente de render/navegador |
| Importaciones mensuales por sector | OK | Pendiente de render/navegador |
| Importaciones acumuladas por sector | OK | Pendiente de render/navegador |
| Importaciones mensuales por proyecto | OK | Pendiente de render/navegador |
| Importaciones acumuladas por proyecto | OK | Pendiente de render/navegador |

## Revisión responsive

La QA estática de mobile y CSS pasó sin fallas, incluido el mensaje de error accesible. La validación real de los anchos 1440, 1024, 768, 390, 375 y 320 px quedó codificada en `qa_plotly_modules.py` y es obligatoria en GitHub Actions, pero no pudo ejecutarse localmente por falta de navegador.

## Validaciones pendientes para un equipo con R y Quarto

Ejecutar desde la raíz del proyecto:

```bash
rm -rf .quarto _freeze _site
find . -maxdepth 1 -type d -name '*_cache' -exec rm -rf {} +
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

Si se ejecuta fuera de GitHub Actions y se desea hacer obligatoria la prueba de navegador:

```bash
RIGI_REQUIRE_BROWSER=1 python3 tools/qa_plotly_modules.py
```
