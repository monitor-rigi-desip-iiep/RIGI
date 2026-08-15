# Auditoría técnica y rediseño integral — Monitor de Proyectos RIGI

Fecha de auditoría: 15 de agosto de 2026.

## Resultado ejecutivo

Se auditó la base maestra, los planes de inversión, las importaciones, las diez descargas, el pipeline R, la configuración Quarto, los tres módulos JavaScript y la hoja de estilos. El rediseño conserva la arquitectura estática R + Quarto y la identidad pública se limita a **DESIP · IIEP**.

La regresión de datos confirma que los resultados sustantivos anteriores y posteriores coinciden. Se aplicó una única corrección documental: el formato del CUIT de VMOS. Ningún monto, estado, empleo, fecha, ranking o suma territorial fue alterado.

## A. Cambios visuales

- Hero blanco, tipografía azul marino, línea institucional y KPIs planos calculados por R.
- Navegación sticky por secciones con estado activo y `scroll-margin-top`.
- Control móvil nativo `Contenido`, con cierre al seleccionar un enlace y estado `aria-expanded` sincronizado.
- Índice “Explorá el Monitor” de cinco entradas; tarjetas compactas convertidas en filas en mobile.
- Jerarquía numerada para las cinco secciones principales.
- Badge discreto `INTERACTIVO` agregado por JavaScript a módulos Plotly, tablas, fichas y exploradores.
- Paleta semántica coherente: azul para aprobados, naranja para evaluación, gris para rechazados, verde petróleo para empleo y azul petróleo para PEELP.
- Tarjetas, fichas, tablas y descargas con bordes finos, radios moderados y sombras mínimas.
- Cronología con ancho mínimo controlado, scroll horizontal solo si existe overflow y scroll vertical reservado para ese componente.
- Control “volver arriba”, foco visible y respeto de `prefers-reduced-motion`.
- Sin zoom, drag o doble clic de Plotly; se preservan hover/tap, leyendas y filtros.

## B. Cambios técnicos

Archivos modificados respecto del adjunto:

- `_quarto.yml`
- `index.qmd`
- `styles.css`
- `assets/rigi-responsive.js`
- `assets/planes_inversion.js`
- `assets/importaciones.js`
- `R/03_indicators.R`
- `R/04_plots.R`
- `.github/workflows/render.yml`
- `README.md`
- `data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx`
- `downloads/base_completa.csv`
- `downloads/base_completa.xlsx`
- `downloads/base_interactiva_aprobados.csv`
- `downloads/base_interactiva_aprobados.xlsx`

Archivos agregados:

- `tools/audit_dashboard.py`
- `qa/baseline_audit.json`
- `qa/final_audit.json`
- `AUDITORIA_TECNICA.md`

## C. Auditoría de datos

### Base maestra

| Control | Resultado |
|---|---:|
| Proyectos | 40 |
| Aprobados | 21 |
| En evaluación | 18 |
| Rechazados | 1 |
| IDs faltantes / duplicados | 0 / 0 |
| Nombres de proyecto duplicados | 0 |
| Sectores / provincias vacíos | 0 / 0 |
| Montos no convertibles / negativos | 0 / 0 |
| Empleos negativos | 0 |
| Fechas imposibles o fuera de secuencia | 0 |
| Aprobados sin resolución / enlace | 0 / 0 |
| Enlaces de resolución duplicados | 0 |
| Solapamiento aprobado–pendiente | 0 |
| CUIT presentes inválidos, antes / después | 1 / 0 |

Los 19 CUIT faltantes corresponden principalmente a proyectos no aprobados y se preservaron como faltantes; no se imputaron valores.

### Corrección documentada

| Proyecto | Variable | Valor anterior | Valor nuevo | Fuente | Motivo |
|---|---|---|---|---|---|
| Vaca Muerta Oleoducto Sur (VMOS) | CUIT | `30-718713354` | `30-71871335-4` | [Resolución 302/2025, Boletín Oficial](https://www.boletinoficial.gob.ar/detalleAviso/primera/322830/20250321) | La resolución identifica expresamente a VMOS S.A. con el CUIT corregido. |

### Variables monetarias

Se preservaron como conceptos diferentes `Monto (mill. USD)` y `Monto (mill. USD) - aprobados resolución`. Existen once diferencias entre ambas variables; no se modificaron porque representan conceptos de fuente distintos y el código utiliza el monto general para los indicadores del Monitor.

### Distribución territorial

La función `expand_provincias()` mantiene la asignación en partes iguales para proyectos multiprovinciales. La reconstrucción posterior coincide exactamente con los originales:

| Universo | Proyectos | Filas territoriales | Monto (mill. USD) | Activos (mill. USD) | Empleo |
|---|---:|---:|---:|---:|---:|
| Total | 40 | 51 | 135.190 | 30.440 | 95.158 |
| Aprobados | 21 | 25 | 46.708 | 30.440 | 95.158 |
| En evaluación | 18 | 25 | 88.209 | s/d | s/d |

### Planes de inversión

- 264 filas; años 2024–2056; total 46.024 millones de USD.
- Cero duplicados exactos o de clave año–sector–subsector.
- Cero montos faltantes, no convertibles o negativos.
- La suma de subsectores coincide con cada total sectorial.
- La suma de sectores coincide con cada total anual.

### Importaciones

- 1.846 filas y 10 columnas.
- `fob_dolar` es numérico; cero valores no convertibles o negativos.
- Cero meses inválidos y cero períodos fuera de `primer_periodo`–`ultimo_periodo`.
- Cero duplicados exactos.
- FOB total auditado: USD 291.382.529,31.

### Descargas

Cada pareja CSV/XLSX coincide en filas, columnas, nombres y valores:

| Base | Filas | Columnas | CSV = XLSX |
|---|---:|---:|---:|
| Base completa | 40 | 26 | Sí |
| Aprobados | 21 | 26 | Sí |
| En evaluación | 18 | 26 | Sí |
| Planes de inversión | 264 | 7 | Sí |
| Importaciones | 1.846 | 10 | Sí |

## D. Verificación de fuentes

- Se abrió el enlace de norma de los 21 proyectos aprobados y se contrastaron resolución y VPU contra el Boletín Oficial. No se encontraron links cruzados ni resoluciones asignadas a otro proyecto.
- Se contrastó la estructura de planes con el [sitio oficial del RIGI](https://www.argentina.gob.ar/economia/rigi). Los contadores del HTML público se cargan dinámicamente y aparecen como cero en una lectura sin JavaScript; por eso no se usaron como cifras de control.
- Para el proyecto Mariana, clasificado como rechazado, se encontró respaldo público del anuncio pero no una resolución de rechazo publicada en el Boletín Oficial. Se mantuvo el estado y se deja esta limitación explícita; no hubo evidencia primaria suficiente para cambiarlo.

## E. Regresión y QA

- Auditoría reproducible antes y después: `qa/baseline_audit.json` y `qa/final_audit.json`.
- Los 14 indicadores principales coinciden exactamente antes y después.
- JavaScript: sintaxis válida en los tres archivos con `node --check`.
- Quarto/Markdown: `index.qmd` parsea correctamente con Pandoc; todos los anchors de navegación tienen destino.
- YAML: `_quarto.yml` válido y TOC lateral desactivado para evitar navegación redundante.
- R: balance estructural de los siete scripts sin delimitadores abiertos; se auditó manualmente el flujo de objetos y cálculos.
- CSS: llaves balanceadas, breakpoints consolidados y cierre de cascada para preservar el sistema institucional sobre reglas heredadas.
- Referencias públicas prohibidas: no quedan menciones a las instituciones excluidas en fuentes, configuración, README ni HTML generado existente.
- Matriz responsive cubierta por reglas: 320, 360, 375, 390, 412, 430, 768, 820, 1024, 1280, 1366, 1440, 1536 y 1920 px, incluidas reglas de landscape.

## F. Limitaciones pendientes

El entorno de ejecución entregado no contiene los binarios `R`, `Rscript` ni `quarto`, ni un navegador ejecutable. Por esa razón no fue posible ejecutar localmente el pipeline R/Quarto, regenerar `_site` ni producir capturas visuales reales de cada viewport. No se editó `_site` manualmente.

El proyecto conserva su workflow de GitHub Pages, ahora sensible también a cambios en `assets/**` y `downloads/**`; al hacer push, ese workflow instala R y Quarto, ejecuta `quarto render` y publica `_site`. El primer render de CI debe considerarse el control final pendiente de entorno.

## Declaración de integridad

**Los resultados anteriores y posteriores al rediseño coinciden, salvo la corrección documentada del formato del CUIT de VMOS. No se modificó ningún otro dato sustantivo.**
