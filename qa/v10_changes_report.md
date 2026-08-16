# Verificación de cambios v10

## Cambios incorporados

1. La cronología de **Hitos del RIGI** muestra inicialmente los primeros cuatro registros. Un control nativo y accesible permite desplegar los hitos restantes y volver a ocultarlos.
2. El pie del sitio incorpora `Por @_LucasOrdonez` con enlace a `https://x.com/_LucasOrdonez`.
3. Las descargas de proyectos aprobados, proyectos en evaluación y base completa ya no incluyen las columnas internas:
   - `Clasificación preexistencia BO`
   - `Justificación preexistencia BO`

## Verificaciones ejecutadas

- QA funcional automatizada: **36 controles aprobados, 0 fallas**.
- Sintaxis de los tres archivos JavaScript: correcta.
- Balance de delimitadores R y llaves CSS: correcto.
- Archivos XLSX reabiertos con `@oai/artifact-tool`: correctos.
- Revisión visual de los tres XLSX: correcta.
- Archivos CSV reabiertos con el lector estándar: correctos.
- Todos los XLSX y CSV objetivo tienen 24 columnas y terminan en `Links fuentes (original)`.

| Descarga | Filas con encabezado | Columnas | XLSX | CSV |
|---|---:|---:|:---:|:---:|
| Aprobados | 22 | 24 | OK | OK |
| En evaluación | 19 | 24 | OK | OK |
| Base completa | 41 | 24 | OK | OK |

## Regeneración automática

El cambio también se realizó en `make_download_table()` dentro de `R/02_clean_data.R`. Por lo tanto, cada ejecución futura de `quarto render` regenerará los seis archivos sin las dos columnas internas.

## Entorno de validación

El contenedor de revisión no incluye R ni Quarto, por lo que el render integral no pudo ejecutarse localmente. El repositorio conserva el flujo de GitHub Actions que renderiza y publica el sitio al integrar los cambios en `main`.
