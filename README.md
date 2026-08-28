# Monitor de Proyectos RIGI

**DESIP · IIEP**

El Monitor reúne y sistematiza información pública sobre los proyectos aprobados y en evaluación en el marco del Régimen de Incentivo para Grandes Inversiones (RIGI). La publicación ofrece indicadores, fichas de proyectos y bases descargables para facilitar la consulta, reutilización y análisis de la información.

## Variante visual incluida

**Fichas de proyectos + gráficos institucionales.** Las bases interactivas se
presentan como tarjetas filtrables y ordenables, mientras que los gráficos
utilizan una estética limpia, jerárquica y consistente. La grilla de fichas usa
tres columnas en pantallas amplias, dos en tablet y una en celular.

Sitio web reproducible construido con **R + Quarto + GitHub Pages** a partir de la solapa `Proyectos` del archivo:

```text
RIGI_tracker_data_final_con_proyectos_integrados.xlsx
```

## Cambios de esta versión

- El resumen ejecutivo se presenta como un panel visual con indicadores destacados, barras comparables y rankings calculados desde la base.
- El resumen identifica dinámicamente los tres proyectos aprobados más recientes y los tres proyectos en evaluación con fecha de presentación más reciente.
- Las secciones Aprobados, En evaluación y Base de datos permiten alternar entre Tabla y Fichas sin perder filtros ni ordenamiento.
- La cronología de presentaciones conserva el gráfico interactivo en tablet y computadora; en celular utiliza una línea de tiempo compacta, legible y desplegable con fecha, sector y monto.
- El ranking de principales proyectos aprobados mantiene una grilla estable en celular para evitar superposiciones entre el puesto, el nombre y el monto.
- El Monitor se organiza en seis páginas Quarto: resumen, aprobados, evaluación, comparación, base de datos y metodología.
- La navegación global permanece visible, indica la página activa y se transforma en un menú `Contenido` accesible en pantallas pequeñas.
- Las páginas extensas cuentan con un único índice interno; la portada conserva el resumen y deriva cada tema a su página correspondiente.
- Los filtros de Planes de inversión e Importaciones se ubican en barras independientes por encima de los gráficos; las leyendas Plotly permanecen debajo del área de datos.
- Los controles, fichas, tablas y contenedores de gráficos incorporan un tratamiento mobile-first para 320–430 px, tablet, notebook y escritorio.
- El informe prioriza primero los **proyectos aprobados**.
- Luego muestra los **proyectos en evaluación**.
- Los montos se muestran en **millones de USD**, sin abreviaturas tipo `B`.
- Se incorporan estadísticas y gráficos de **empleo directo e indirecto** para proyectos aprobados.
- Las provincias múltiples separadas por `;` se tratan mediante **asignación en partes iguales** del monto, los activos computables y el empleo entre las provincias involucradas.
- Se agregan descargas en `.xlsx` y `.csv` para:
  - `Base interactiva: aprobados`
  - `Base interactiva: pendientes`
  - `Base completa`
  - `Planes de inversión` (hoja `Datos_long`, siete columnas seleccionadas)
- La sección **Planes de inversión** utiliza `data/RIGI_planes_inversion.xlsx` (hoja `Datos_long`) e incorpora filtros sincronizados por período, sector y subsector, un gráfico anual y otro acumulado.
- En las descargas, las columnas `Monto (mill. USD)`, `Activos Computables (mill. USD)` y `Empleos (directos e indirectos)` se mantienen como numéricas.
- Las bases con información PEELP incorporan el filtro `Clasificación del proyecto`, con las opciones `Todos los proyectos`, `Solo proyectos PEELP` y `Solo proyectos no PEELP`.
- La subsección PEELP utiliza fichas filtrables y expandibles, manteniendo el gráfico comparativo por monto.
- Los indicadores PEELP incluyen la participación de su inversión sobre el monto total de inversión de los proyectos aprobados.
- Los gráficos muestran etiquetas directas con valor y participación, sin
  recuadros blancos ni títulos internos repetidos.
- Se utiliza una paleta semántica: azul para inversión aprobada, naranja para
  pendientes, verde petróleo para empleo y azul petróleo para PEELP.
- Las fichas de proyectos en evaluación muestran fuentes individuales con
  enlaces seguros construidos automáticamente desde el Excel.
- Las descargas conservan una representación trazable `Fuente [URL]` y también
  las columnas originales de fuentes y enlaces.
- Las descargas de proyectos excluyen las columnas internas `Clasificación preexistencia BO` y `Justificación preexistencia BO`.
- La cronología de hitos muestra inicialmente cuatro registros y permite desplegar u ocultar el resto con un control accesible.
- El pie del sitio incorpora la autoría y un enlace al perfil de X de `@_LucasOrdonez`.
- El empleo se organiza en pestañas por proyecto, sector y provincia.
- PEELP incorpora una barra de composición del monto aprobado y un ranking
  específico.
- Los rankings numeran los proyectos y destacan visualmente los tres primeros.
- Los contenedores, márgenes y alturas de los gráficos se adaptan a pantallas
  grandes y pequeñas.
- Los nombres largos de proyectos, sectores o provincias en los gráficos se muestran en hasta dos renglones para mejorar la legibilidad.

## Fuentes y aclaración metodológica

Para los proyectos aprobados, la información administrativa se basa en el
Boletín Oficial y en otras fuentes oficiales disponibles; las empresas fueron
inferidas por Globaris según la metodología utilizada. Para los proyectos en
evaluación, Globaris funciona como fuente base y la información se complementa,
cuando está disponible, con medios periodísticos, comunicaciones empresariales,
fuentes institucionales y otras fuentes públicas identificadas en cada ficha.
Estas fuentes complementarias no equivalen a una validación oficial. Los datos
de empleos directos e indirectos se obtuvieron del Ministerio de Economía.

## Cómo correr localmente

Desde la carpeta del proyecto:

```bash
quarto render
quarto preview
```

## Cómo actualizar el Excel maestro

El archivo `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx` es una
fuente de datos actualizable. Puede incorporar proyectos, cambios de estado,
montos, fechas, empleo, fuentes y correcciones de texto sin modificar hashes ni
archivos de código. Debe conservar el nombre, la ubicación, las hojas
obligatorias (`Proyectos`, `Diccionario` y `Variable_Anterior`) y el contrato de
columnas documentado por el proyecto.

Después de reemplazar o editar el Excel, ejecutar desde la carpeta raíz:

```bash
# Solo la primera vez, si openpyxl no está instalado.
python3 -m pip install "openpyxl>=3.1,<4"

# Contrato de datos y prueba de robustez ante futuras actualizaciones.
python3 tools/qa_data_contract.py
python3 tools/test_qa_data_contract.py

# Controles de R y de la interfaz antes del render.
Rscript tools/qa_encoding.R
Rscript tools/diagnose_plotly_dependency.R
python3 tools/qa_final_ui_refinements.py
python3 tools/qa_peelp_cards.py

# Render limpio; regenera indicadores, fichas, gráficos y descargas.
rm -rf .quarto _freeze _site
find . -maxdepth 1 -type d -name '*_cache' -exec rm -rf {} +
find . -maxdepth 1 -type d -name '*_files' -exec rm -rf {} +
quarto render

# Controles sobre el sitio recién generado.
python3 tools/qa_plotly_modules.py
python3 tools/qa_ranked_modules.py
quarto preview
```

`tools/qa_data_contract.py` comprueba que el XLSX sea legible y conserve hojas,
columnas, identificadores, estados, tipos de datos y reglas mínimas de
consistencia. El SHA-256 se registra únicamente para trazabilidad: su cambio no
detiene el workflow. `tools/test_qa_data_contract.py` demuestra en copias
temporales que una modificación válida de contenido es aceptada y que la
ausencia de una columna obligatoria es rechazada con un mensaje accionable.

El render regenera automáticamente las descargas de aprobados, proyectos en
evaluación y base completa a partir del Excel vigente. Antes de subir, revisar
`git status` y `git diff`. Si todos los controles finalizaron correctamente:

1. Abrir GitHub Desktop.
2. Escribir el mensaje en `Summary`.
3. Seleccionar `Commit to main`.
4. Seleccionar `Push origin`.

No es necesario calcular, copiar ni actualizar manualmente ningún SHA-256.

Para actualizar `data/RIGI_planes_inversion.xlsx`, conservar además la hoja
`Datos_long` y ejecutar la misma secuencia de render y controles.

El sitio publicado debería actualizarse en:

```text
https://monitor-rigi-desip-iiep.github.io/RIGI/
```

- Se incorpora la columna `Proyectos de exportación estratégica de largo plazo (PEELP)` en aprobados, pendientes y base completa.
