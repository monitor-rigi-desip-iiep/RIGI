# Diagnóstico definitivo de los gráficos vacíos

## Dos causas simultáneas

### 1. El include seguía sin estar versionado

El ZIP montado contiene `assets/rigi-head.html`, pero el archivo continúa alcanzado por la regla `*.html` de `.gitignore` y no aparece en `git ls-files`. `_quarto.yml` intentaba leer ese archivo mediante `include-in-header`, por lo que el render local funcionaba y el checkout limpio de GitHub Actions no podía reproducirlo.

La publicación confirmó que `aprobados.html` tenía los scripts de Planes e Importaciones, pero ninguna etiqueta para `rigi-responsive.js`. Los seis contenedores personalizados permanecían vacíos.

### 2. El último push no activó un nuevo render

El commit `8d22646 actualizacion nueva` incorporó únicamente:

- archivos XLSX dentro de `downloads/`;
- informes dentro de `qa/`;
- una modificación en `tools/qa_github_pages.py`.

El workflow anterior sólo observaba `index.qmd`, `presentation.qmd`, `_quarto.yml`, `styles.css`, `R/**`, `data/**`, `DESCRIPTION` y el propio workflow. Por lo tanto, los cambios del último commit no pertenecían a ninguna ruta observada y no obligaron a reconstruir GitHub Pages.

## Solución aplicada

Se eliminó por completo la dependencia del archivo HTML ignorado:

- `_quarto.yml` ya no utiliza `include-in-header`;
- la etiqueta de carga se encuentra directamente en `_partials/setup-core.qmd`;
- ese partial ya estaba versionado y es incluido por las seis páginas del sitio;
- no es necesario modificar `.gitignore` ni incorporar un archivo HTML nuevo.

La etiqueta incorporada es:

```html
<script src="assets/rigi-responsive.js" defer></script>
```

También se corrigió el workflow para:

- observar todas las páginas, partials, assets, scripts R, datos y descargas;
- instalar las dependencias R faltantes;
- eliminar cachés y `_site` antes del render;
- validar la sintaxis de los JavaScript;
- comprobar que el partial que carga la dependencia esté versionado;
- verificar después del render que Plotly, los tres scripts y los diez IDs interactivos estén presentes;
- rechazar el artifact si `rigi-responsive.js` no aparece exactamente una vez.

## Resultado esperado del próximo push

El commit modifica tanto `_partials/setup-core.qmd` como `.github/workflows/render.yml`. El propio cambio del workflow garantiza que GitHub Actions se active. Si Quarto no incorpora la etiqueta o falta algún asset, el job fallará antes de publicar, en lugar de terminar con `Success` y dejar gráficos vacíos.

## QA

- YAML válido.
- Tres JavaScript con sintaxis válida.
- Bootstrap responsive dentro de un archivo versionado.
- Ausencia de includes HTML externos.
- Navegación y anchors sin errores.
- Diez IDs interactivos presentes.
- Regresión de datos idéntica antes y después.

## Limitación

El entorno de preparación no contiene `Rscript` ni `quarto` y no posee credenciales para escribir en el repositorio remoto. El render real y la verificación visual posterior se ejecutarán mediante el workflow corregido cuando se publique el commit incluido en esta entrega.
