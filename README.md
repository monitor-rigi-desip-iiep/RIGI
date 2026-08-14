# Monitor de Proyectos RIGI

## Variante visual incluida

**Fichas de proyectos + gráficos institucionales.** Las bases interactivas se
presentan como tarjetas filtrables y ordenables, mientras que los gráficos
utilizan una estética limpia, jerárquica y consistente. La grilla de fichas usa
dos columnas en escritorio y una en pantallas pequeñas.

Sitio web reproducible construido con **R + Quarto + GitHub Pages** a partir de la solapa `Proyectos` del archivo:

```text
RIGI_tracker_data_final_con_proyectos_integrados.xlsx
```

## Cambios de esta versión

- El informe prioriza primero los **proyectos aprobados**.
- Luego muestra los **proyectos pendientes de aprobación / en evaluación**.
- Los montos se muestran en **millones de USD**, sin abreviaturas tipo `B`.
- Se incorporan estadísticas y gráficos de **empleo directo e indirecto** para proyectos aprobados.
- Las provincias múltiples separadas por `;` se tratan mediante **asignación proporcional** de monto, activos computables y empleo para evitar doble conteo territorial.
- Se agregan descargas en `.xlsx` y `.csv` para:
  - `Base interactiva: aprobados`
  - `Base interactiva: pendientes`
  - `Base completa`
- En las descargas, las columnas `Monto (mill. USD)`, `Activos Computables (mill. USD)` y `Empleos (directos e indirectos)` se mantienen como numéricas.
- Las bases con información PEELP incorporan el filtro `Clasificación del proyecto`, con las opciones `Todos los proyectos`, `Solo proyectos PEELP` y `Solo proyectos no PEELP`.
- La subsección PEELP utiliza fichas filtrables y expandibles, manteniendo el gráfico comparativo por monto.
- Los indicadores PEELP incluyen la participación de su inversión sobre el monto total de inversión de los proyectos aprobados.
- Los gráficos muestran etiquetas directas con valor y participación, sin
  recuadros blancos ni títulos internos repetidos.
- Se utiliza una paleta semántica: azul para inversión aprobada, naranja para
  pendientes, verde petróleo para empleo y violeta para PEELP.
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

1. Reemplazar el archivo Excel en `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx`.
2. Verificar que la solapa se siga llamando `Proyectos`.
3. Ejecutar:

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
