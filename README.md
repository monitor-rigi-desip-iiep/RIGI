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
- La cronología de presentaciones ocupa el ancho disponible y adapta márgenes, altura y desplazamiento vertical a celular, tablet y computadora.
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

## Cómo actualizar el informe

1. Reemplazar el archivo Excel en `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx` cuando se actualice la base de proyectos.
2. Reemplazar `data/RIGI_planes_inversion.xlsx` cuando se actualicen los planes de inversión y verificar que conserve la hoja `Datos_long`.
3. Verificar que la base principal conserve la solapa `Proyectos`.
4. Ejecutar:

```bash
quarto render
quarto preview
```

4. Si está correcto, subir cambios con GitHub Desktop:
   - escribir un mensaje en `Summary`;
   - tocar `Commit to main`;
   - tocar `Push origin`.

El sitio publicado debería actualizarse en:

```text
https://monitor-rigi-desip-iiep.github.io/RIGI/
```

- Se incorpora la columna `Proyectos de exportación estratégica de largo plazo (PEELP)` en aprobados, pendientes y base completa.
