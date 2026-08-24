# Informe de corrección — `[object Object]` en módulos de inversión y empleo

Fecha: 24 de agosto de 2026

## Resultado

Se corrigieron en las fuentes las dos causas compartidas que afectaban a los módulos de inversión y empleo de `aprobados.html` y `evaluacion.html`:

1. los valores R `NULL` de `noteOverride` y `shareTotal` se serializaban como objetos JSON vacíos (`{}`);
2. `dictionary_value()` confundía su argumento `variable` con la columna homónima dentro del enmascaramiento de datos de `dplyr`, por lo que seleccionaba la primera fila del diccionario (`VPU`).

La corrección se aplicó en el constructor común. No se modificaron datos, QMD de contenido, módulos Plotly, Planes de inversión, Importaciones, PEELP, cronogramas ni fichas.

Este entorno no dispone de R, Quarto ni un navegador ejecutable. Por lo tanto, no fue posible regenerar `_site` ni completar la revisión visual posterior a la corrección. Se preservó fuera del proyecto el HTML recibido para reproducir el fallo y se verificó que la nueva prueba lo rechaza exactamente por las dos causas indicadas.

## Reproducción sobre el `_site` recibido

El ZIP recibido contenía un `_site` generado correctamente mediante Quarto. Sus configuraciones `[data-ranked-data]` mostraban lo siguiente en los cinco módulos afectados:

| Página | Módulo | `title` | `shareTotal` | `noteOverride` |
|---|---|---|---|---|
| aprobados | Inversión total | `VPU` | `{}` | `{}` |
| aprobados | Activos computables | `VPU` | `{}` | `{}` |
| aprobados | Compromiso primeros 2 años | `VPU` | `{}` | `{}` |
| aprobados | Empleo informado | `VPU` | `{}` | `{}` |
| evaluación | Inversión total | `VPU` | `{}` | `{}` |

Las filas de las vistas sí tenían el esquema correcto: `label` era texto, `value` era numérico y `count` era entero. Esto descartó que el problema proviniera de las bases o de las etiquetas de proyectos, sectores y provincias.

La nueva prueba `tools/qa_ranked_modules.py`, ejecutada contra ese HTML recibido, falló deliberadamente con:

```text
failed: rendered_ranked_json_schema
```

y señaló en los cinco módulos `title = VPU`, `shareTotal = {}` y `noteOverride = {}`.

## Causa raíz 1: serialización de valores opcionales

`make_ranked_metric_module()` construía un payload con:

```r
shareTotal = NULL
noteOverride = NULL
```

pero la llamada a `jsonlite::toJSON()` no especificaba el tratamiento de `NULL`. El JSON resultante contenía:

```json
{
  "shareTotal": {},
  "noteOverride": {}
}
```

En JavaScript, un objeto vacío es verdadero. Por eso esta condición se ejecutaba:

```javascript
if (config.noteOverride) {
  note.textContent = config.noteOverride;
}
```

La asignación de un objeto a `textContent` provoca su conversión implícita a:

```text
[object Object]
```

Había además un efecto menos visible. La función anterior hacía `Number(value)` sin validar el tipo y JavaScript evalúa `Number({})` como `0`. En consecuencia, `shareTotal = {}` se interpretaba como un total configurado igual a cero y las participaciones podían mostrarse como no informadas.

## Corrección de la serialización

En `R/07_investment_modules.R`:

- `share_total` se acepta únicamente si es un escalar numérico finito;
- `note_override` se acepta únicamente si es una cadena escalar no vacía;
- cualquier otro valor se normaliza a `NULL`;
- `jsonlite::toJSON()` utiliza ahora `null = "null"`.

El resultado esperado después del nuevo render es:

```json
{
  "shareTotal": null,
  "noteOverride": null
}
```

Los módulos PEELP que proporcionan un `shareTotal` numérico y un `noteOverride` de texto conservan esos valores.

## Causa raíz 2: selección incorrecta del diccionario

La función anterior recibía un argumento llamado `variable` y filtraba mediante:

```r
dplyr::filter(.data$variable == variable)
```

Dentro de `dplyr`, el nombre no cualificado `variable` se resolvía en el contexto de los datos. La comparación terminaba siendo equivalente a comparar la columna consigo misma; todas las filas pasaban el filtro y `slice_head()` seleccionaba la primera, correspondiente a `VPU`.

La función ahora denomina al argumento `variable_name` y utiliza:

```r
.data$variable == .env$variable_name
```

Esto mantiene el diccionario como única fuente de títulos y descripciones, sin hardcodear textos para ocultar el error.

Después del render, los títulos esperados son:

| Módulo | Título esperado |
|---|---|
| Aprobados — inversión total | Inversión total |
| Aprobados — activos computables | Inversión en activos computables |
| Aprobados — compromiso 2 años | Inversión comprometida en activos computables — primeros 2 años |
| Aprobados — empleo | Empleo informado |
| Evaluación — inversión total | Inversión total |

## Fortalecimiento de JavaScript

En `assets/investment_modules.js` se agregó una segunda línea de defensa:

- `finiteNumber()` acepta solo números finitos o cadenas numéricas no vacías;
- rechaza objetos, arrays, booleanos, `null`, `undefined` y cadenas vacías;
- `noteOverride` solo se utiliza cuando es una cadena no vacía;
- ante un valor inválido, la nota se calcula según la vista activa;
- ante un `shareTotal` inválido, se utiliza la suma calculada de la vista.

No se agregó una sustitución superficial de `[object Object]` ni se expone `JSON.stringify()` al público.

## Prueba de regresión agregada

Se creó `tools/qa_ranked_modules.py`.

En modo de fuentes verifica:

- checksum del XLSX principal;
- existencia y sintaxis del JavaScript;
- claves de los cinco módulos;
- lookup inequívoco del diccionario;
- serialización explícita de `null`;
- normalización de campos opcionales;
- rechazo de coerciones de objetos en JavaScript;
- validación tipada de `noteOverride`;
- ausencia de un reemplazo cosmético de `[object Object]`;
- incorporación de la prueba al workflow.

Después del render verifica además:

- presencia de `aprobados.html` y `evaluacion.html`;
- JSON válido de los cinco módulos;
- tipos de todos los campos y filas;
- títulos y descripciones correspondientes a cada métrica;
- `shareTotal` numérico o `null`, nunca objeto;
- `noteOverride` texto o `null`, nunca objeto;
- ausencia de IDs duplicados;
- ausencia de `[object Object]` en el HTML.

Con Playwright/Chromium recorre las tres vistas y los cuatro límites de cada módulo en 1440, 1024, 768, 390, 375 y 320 px. Comprueba texto visible, `title`, `aria-label`, porcentajes, cantidad y unicidad de filas, inicialización, consola y desbordamiento horizontal.

El workflow ejecuta la nueva prueba después de `qa_plotly_modules.py`, manteniendo el navegador obligatorio en CI.

## Archivos modificados

- `R/07_investment_modules.R`.
- `assets/investment_modules.js`.
- `tools/qa_ranked_modules.py` — nuevo.
- `tools/qa_functional_changes.py`.
- `tools/qa_github_pages.py`.
- `.github/workflows/render.yml`.
- salidas JSON de QA regeneradas.
- `INFORME_CORRECCION_OBJECT_OBJECT.md` — nuevo.

No se hizo commit, push ni publicación.

## Datos verificados

No se modificó ningún archivo de datos.

El XLSX principal conserva el SHA-256 requerido:

```text
82d3d74fe58f6b747269bd72058397bd369ee4810b765e1d18bbf438e28cc974
```

Los JSON recibidos contenían filas válidas y no vacías en las vistas por proyecto, sector y provincia de los cinco módulos.

## Pruebas ejecutadas

| Prueba | Resultado |
|---|---|
| Reproducción estructural sobre el HTML recibido | OK: detectó los cinco pares `{}` y los cinco títulos `VPU` |
| `python3 tools/qa_ranked_modules.py --source-only` | OK |
| `python3 tools/qa_plotly_modules.py --source-only` | OK |
| `python3 tools/qa_rigi_update.py` | OK |
| `python3 tools/qa_functional_changes.py` | OK |
| `python3 tools/qa_navigation.py` | OK |
| `python3 tools/qa_mobile_layout.py` | OK |
| `python3 tools/qa_github_pages.py` | OK |
| `python3 tools/qa_final_ui_refinements.py` | OK |
| `python3 tools/qa_peelp_cards.py` | OK |
| Todos los JavaScript mediante `node --check` | OK |
| Compilación de los Python de `tools/` | OK |
| `Rscript tools/qa_encoding.R` | No ejecutable: `Rscript` no instalado |
| `quarto render` | No ejecutable: Quarto no instalado |
| QA completa sobre el nuevo `_site` | Pendiente del render |
| Revisión visual y responsive en navegador | Pendiente del render y Chromium |

## Estado individual de los módulos

| Módulo | Error reproducido en HTML recibido | Corrección en fuentes | Validación posterior al render |
|---|---:|---:|---:|
| Aprobados — inversión total | Sí | Aplicada | Pendiente |
| Aprobados — activos computables | Sí | Aplicada | Pendiente |
| Aprobados — compromiso 2 años | Sí | Aplicada | Pendiente |
| Aprobados — empleo informado | Sí | Aplicada | Pendiente |
| Evaluación — inversión total | Sí | Aplicada | Pendiente |

## Validaciones pendientes

El sitio anterior publicado no pudo abrirse desde el navegador de este entorno. La comparación visual con esas páginas queda pendiente, aunque los títulos y descripciones esperados se obtuvieron del diccionario vigente del propio XLSX.

Desde la raíz del proyecto, ejecutar:

```bash
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
python3 tools/qa_ranked_modules.py

find assets -name '*.js' -print0 | xargs -0 -n1 node --check
```

La prueba de navegador puede hacerse obligatoria localmente mediante:

```bash
RIGI_REQUIRE_BROWSER=1 python3 tools/qa_ranked_modules.py
```
