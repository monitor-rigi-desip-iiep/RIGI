# Importaciones por proyecto ---------------------------------------------------
# Este módulo utiliza data/impo_rigi_aduana.csv y genera validaciones,
# descargas y visualizaciones interactivas mensuales compatibles con un sitio
# estático de Quarto/GitHub Pages.

importaciones_path <- file.path("data", "impo_rigi_aduana.csv")

importaciones_required_columns <- c(
  "anio",
  "mes",
  "VPU",
  "fob_dolar",
  "pos_ncm",
  "sector",
  "provincia",
  "nombre_importador",
  "primer_periodo",
  "ultimo_periodo"
)

importaciones_download_columns <- importaciones_required_columns

load_importaciones_rigi <- function(path = importaciones_path) {
  if (!file.exists(path)) {
    stop("No se encontró el archivo de importaciones: ", path, call. = FALSE)
  }

  data <- readr::read_csv(
    path,
    show_col_types = FALSE,
    progress = FALSE,
    trim_ws = FALSE,
    col_types = readr::cols(
      anio = readr::col_integer(),
      mes = readr::col_integer(),
      VPU = readr::col_character(),
      fob_dolar = readr::col_double(),
      pos_ncm = readr::col_character(),
      sector = readr::col_character(),
      provincia = readr::col_character(),
      nombre_importador = readr::col_character(),
      primer_periodo = readr::col_integer(),
      ultimo_periodo = readr::col_integer()
    )
  )

  missing_cols <- setdiff(importaciones_required_columns, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "Faltan columnas requeridas en impo_rigi_aduana.csv: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  data
}

validate_importaciones_rigi <- function(data) {
  errors <- character(0)

  if (nrow(data) == 0) {
    errors <- c(errors, "impo_rigi_aduana.csv no contiene observaciones.")
  }

  if (any(is.na(data$anio))) {
    errors <- c(errors, "La variable anio contiene valores faltantes o inválidos.")
  }
  if (any(is.na(data$mes) | data$mes < 1L | data$mes > 12L)) {
    errors <- c(errors, "La variable mes debe contener enteros entre 1 y 12.")
  }
  if (any(is.na(data$fob_dolar))) {
    errors <- c(errors, "La variable fob_dolar contiene valores faltantes o no numéricos.")
  }
  if (any(data$fob_dolar < 0, na.rm = TRUE)) {
    errors <- c(errors, "La variable fob_dolar contiene valores negativos.")
  }

  vpu_empty <- is.na(data$VPU) | trimws(as.character(data$VPU)) == ""
  sector_empty <- is.na(data$sector) | trimws(as.character(data$sector)) == ""
  if (any(vpu_empty)) {
    errors <- c(errors, "La variable VPU contiene valores vacíos.")
  }
  if (any(sector_empty)) {
    errors <- c(errors, "La variable sector contiene valores vacíos.")
  }

  periodo <- data$anio * 100L + data$mes
  bad_period <-
    is.na(data$primer_periodo) |
    is.na(data$ultimo_periodo) |
    periodo < data$primer_periodo |
    periodo > data$ultimo_periodo

  if (any(bad_period, na.rm = TRUE)) {
    examples <- data |>
      dplyr::mutate(periodo = periodo, bad_period = bad_period) |>
      dplyr::filter(.data$bad_period) |>
      dplyr::slice_head(n = 5) |>
      dplyr::transmute(
        txt = paste0(
          stringr::str_squish(VPU), " / ", periodo,
          " (rango ", primer_periodo, "-", ultimo_periodo, ")"
        )
      ) |>
      dplyr::pull(txt)

    errors <- c(
      errors,
      paste0(
        "Hay observaciones fuera de primer_periodo/ultimo_periodo: ",
        paste(examples, collapse = "; "),
        if (sum(bad_period, na.rm = TRUE) > 5) "; ..." else ""
      )
    )
  }

  duplicate_count <- sum(duplicated(data))
  if (duplicate_count > 0) {
    warning(
      "impo_rigi_aduana.csv contiene ", duplicate_count,
      " filas exactamente duplicadas. Se preservan sin eliminarlas automáticamente.",
      call. = FALSE
    )
  }

  if (length(errors) > 0) {
    stop(
      paste0(
        "Validación de impo_rigi_aduana.csv fallida:\n- ",
        paste(errors, collapse = "\n- ")
      ),
      call. = FALSE
    )
  }

  invisible(list(duplicate_count = duplicate_count))
}

prepare_importaciones_rigi <- function(data) {
  data |>
    dplyr::mutate(
      proyecto = stringr::str_squish(as.character(VPU)),
      sector_display = stringr::str_squish(as.character(sector)),
      fecha_mes = as.Date(sprintf("%04d-%02d-01", anio, mes)),
      periodo_label = sprintf("%04d-%02d", anio, mes),
      fob_mill_usd = as.numeric(fob_dolar) / 1e6
    )
}

create_importaciones_downloads <- function(data, download_dir = "downloads") {
  dir.create(download_dir, recursive = TRUE, showWarnings = FALSE)

  export_data <- data |>
    dplyr::select(dplyr::all_of(importaciones_download_columns))

  csv_path <- file.path(download_dir, "importaciones_proyectos.csv")
  xlsx_path <- file.path(download_dir, "importaciones_proyectos.xlsx")

  readr::write_csv(export_data, csv_path, na = "")
  writexl::write_xlsx(list(Importaciones = export_data), xlsx_path)

  list(csv = csv_path, xlsx = xlsx_path)
}

importaciones_sector_colors <- function(sectors) {
  sectors <- unique(as.character(sectors))
  canonical <- ifelse(sectors == "Energía", "Energía Eléctrica", sectors)
  canonical_colors <- planes_sector_colors(canonical)

  out <- unname(canonical_colors[canonical])
  names(out) <- sectors
  out
}

make_importaciones_checkbox <- function(name, value, label, class_name) {
  htmltools::tags$label(
    class = "impo-check-option",
    htmltools::tags$input(
      type = "checkbox",
      name = name,
      value = value,
      class = class_name,
      checked = "checked"
    ),
    htmltools::tags$span(label)
  )
}

importaciones_project_colors <- function(projects) {
  projects <- sort(unique(as.character(projects)))
  palette <- c(
    "#2563EB", "#7C3AED", "#0F766E", "#F97316", "#BE123C",
    "#0284C7", "#4F46E5", "#15803D", "#C2410C", "#0E7490",
    "#4338CA", "#047857", "#B45309", "#0369A1", "#A21CAF",
    "#1D4ED8", "#0F766E", "#9333EA", "#EA580C", "#475569"
  )

  out <- rep(palette, length.out = length(projects))
  names(out) <- projects
  out
}

build_importaciones_project_metadata <- function(projects, project_data) {
  lookup <- project_data |>
    dplyr::filter(.data$aprobado) |>
    dplyr::mutate(
      project = stringr::str_squish(as.character(.data$proyecto)),
      estado_mini = dplyr::coalesce(
        dplyr::na_if(stringr::str_squish(as.character(.data$estado_simplificado)), ""),
        dplyr::na_if(stringr::str_squish(as.character(.data$estado)), ""),
        "No informado"
      ),
      titular_mini = dplyr::coalesce(
        dplyr::na_if(stringr::str_squish(as.character(.data$titular_proyecto)), ""),
        dplyr::na_if(stringr::str_squish(as.character(.data$empresa)), ""),
        "No informado"
      ),
      empresa_mini = dplyr::coalesce(
        dplyr::na_if(stringr::str_squish(as.character(.data$empresa)), ""),
        "No informado"
      ),
      sector_mini = dplyr::coalesce(
        dplyr::na_if(stringr::str_squish(as.character(.data$sector_simplificado)), ""),
        "No informado"
      ),
      provincia_mini = dplyr::coalesce(
        dplyr::na_if(stringr::str_squish(as.character(.data$provincia_original)), ""),
        "No informado"
      ),
      adhesion_mini = dplyr::if_else(
        is.na(.data$fecha_adhesion_rigi),
        "No informado",
        format(.data$fecha_adhesion_rigi, "%d/%m/%Y")
      ),
      peelp_mini = dplyr::coalesce(
        as.logical(.data$proyecto_exportacion_estrategia_largo_plazo_si),
        FALSE
      )
    ) |>
    dplyr::arrange(.data$row_id) |>
    dplyr::distinct(.data$project, .keep_all = TRUE) |>
    dplyr::select(
      project,
      estado = estado_mini,
      peelp = peelp_mini,
      titular = titular_mini,
      empresa = empresa_mini,
      sector = sector_mini,
      provincia = provincia_mini,
      adhesion = adhesion_mini
    )

  metadata <- tibble::tibble(project = sort(unique(projects))) |>
    dplyr::left_join(lookup, by = "project") |>
    dplyr::mutate(
      estado = dplyr::coalesce(.data$estado, "No informado"),
      peelp = dplyr::coalesce(.data$peelp, FALSE),
      titular = dplyr::coalesce(.data$titular, "No informado"),
      empresa = dplyr::coalesce(.data$empresa, "No informado"),
      sector = dplyr::coalesce(.data$sector, "No informado"),
      provincia = dplyr::coalesce(.data$provincia, "No informado"),
      adhesion = dplyr::coalesce(.data$adhesion, "No informado")
    )

  missing <- metadata |>
    dplyr::filter(.data$estado == "No informado") |>
    dplyr::pull(.data$project)

  if (length(missing) > 0) {
    warning(
      "No se encontró metadata completa de ficha para: ",
      paste(missing, collapse = ", "),
      ". La visualización se conserva con información disponible.",
      call. = FALSE
    )
  }

  metadata
}

make_importaciones_module <- function(data, project_data) {
  validate_importaciones_rigi(data)
  prepared <- prepare_importaciones_rigi(data)

  # El objeto enviado al navegador se agrega previamente a nivel
  # proyecto × sector × mes para no incrustar filas NCM innecesarias.
  data_client <- prepared |>
    dplyr::group_by(fecha_mes, sector = sector_display, proyecto) |>
    dplyr::summarise(
      fob_mill_usd = sum(fob_mill_usd, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(fecha_mes = format(fecha_mes, "%Y-%m-%d")) |>
    dplyr::arrange(fecha_mes, sector, proyecto)

  min_month <- min(prepared$fecha_mes, na.rm = TRUE)
  max_month <- max(prepared$fecha_mes, na.rm = TRUE)
  sectors <- sort(unique(data_client$sector))
  projects <- sort(unique(data_client$proyecto))
  sector_colors <- importaciones_sector_colors(sectors)
  project_colors <- importaciones_project_colors(projects)
  project_metadata <- build_importaciones_project_metadata(projects, project_data)

  data_json <- jsonlite::toJSON(
    data_client,
    dataframe = "rows",
    auto_unbox = TRUE,
    na = "null",
    digits = 15
  )
  colors_json <- jsonlite::toJSON(as.list(sector_colors), auto_unbox = TRUE)
  project_colors_json <- jsonlite::toJSON(as.list(project_colors), auto_unbox = TRUE)
  project_metadata_json <- jsonlite::toJSON(
    project_metadata,
    dataframe = "rows",
    auto_unbox = TRUE,
    na = "null"
  )

  sector_multiselect <- function(prefix, option_class) {
    htmltools::tags$details(
      class = "impo-multiselect",
      id = paste0(prefix, "-details"),
      htmltools::tags$summary(
        id = paste0(prefix, "-summary"),
        "Todos los sectores"
      ),
      htmltools::div(
        class = "impo-multiselect-menu",
        htmltools::tags$label(
          class = "impo-check-option impo-check-all",
          htmltools::tags$input(
            type = "checkbox",
            id = paste0(prefix, "-all"),
            checked = "checked"
          ),
          htmltools::tags$span("Todos")
        ),
        htmltools::div(
          id = paste0(prefix, "-options"),
          lapply(sectors, function(x) {
            make_importaciones_checkbox(
              paste0(prefix, "-sector"),
              x,
              x,
              option_class
            )
          })
        )
      )
    )
  }

  htmltools::tagList(
    htmltools::div(
      id = "importaciones-module",
      class = "impo-module",
      htmltools::tags$script(
        type = "application/json",
        id = "importaciones-data",
        htmltools::HTML(data_json)
      ),
      htmltools::tags$script(
        type = "application/json",
        id = "importaciones-colors",
        htmltools::HTML(colors_json)
      ),
      htmltools::tags$script(
        type = "application/json",
        id = "importaciones-project-colors",
        htmltools::HTML(project_colors_json)
      ),
      htmltools::tags$script(
        type = "application/json",
        id = "importaciones-project-metadata",
        htmltools::HTML(project_metadata_json)
      ),

      # -------------------------------------------------------------------
      # Subsección: importaciones por sector
      # -------------------------------------------------------------------
      htmltools::tags$section(
        class = "impo-subsection impo-subsection--sector",
        htmltools::div(
          class = "impo-subsection__header",
          htmltools::tags$h3(class = "impo-view-title", "Importaciones por sector"),
          htmltools::tags$p(
            class = "impo-view-subtitle",
            "Evolución mensual y acumulada de las importaciones, desagregada por sector."
          ),
          htmltools::tags$p(
            class = "impo-interaction-note",
            "Usá el selector para elegir uno, varios o todos los sectores. También podés tocar las etiquetas de la leyenda debajo de cada gráfico para ocultar o volver a mostrar sectores sin cambiar el filtro."
          )
        ),
        htmltools::div(
          class = "impo-filter-panel impo-filter-panel--sector",
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$label(`for` = "impo-sector-month-start", "Período inicial"),
            htmltools::tags$input(
              type = "month",
              id = "impo-sector-month-start",
              class = "impo-input",
              min = format(min_month, "%Y-%m"),
              max = format(max_month, "%Y-%m"),
              value = format(min_month, "%Y-%m")
            )
          ),
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$label(`for` = "impo-sector-month-end", "Período final"),
            htmltools::tags$input(
              type = "month",
              id = "impo-sector-month-end",
              class = "impo-input",
              min = format(min_month, "%Y-%m"),
              max = format(max_month, "%Y-%m"),
              value = format(max_month, "%Y-%m")
            )
          ),
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$span(class = "impo-filter-label", "Sector"),
            sector_multiselect("impo-sector-filter", "impo-sector-filter-option")
          ),
          htmltools::div(
            class = "impo-filter-group impo-filter-reset",
            htmltools::tags$button(
              type = "button",
              id = "impo-sector-reset",
              class = "impo-reset-button",
              "Limpiar filtros"
            )
          )
        ),
        htmltools::div(
          class = "impo-chart-card",
          htmltools::tags$h4("Importaciones mensuales por sector"),
          htmltools::div(
            class = "rigi-plot-scroll",
            `data-scroll-hint` = "impo-sector-monthly-scroll-hint",
            htmltools::div(
              id = "impo-sector-monthly-chart",
              class = "impo-chart"
            )
          ),
          htmltools::tags$p(
            id = "impo-sector-monthly-scroll-hint",
            class = "rigi-scroll-hint",
            hidden = "hidden",
            "Deslizá el gráfico para ver más períodos →"
          )
        ),
        htmltools::div(
          class = "impo-chart-card",
          htmltools::tags$h4("Importaciones acumuladas por sector"),
          htmltools::div(
            class = "rigi-plot-scroll",
            `data-scroll-hint` = "impo-sector-cumulative-scroll-hint",
            htmltools::div(
              id = "impo-sector-cumulative-chart",
              class = "impo-chart"
            )
          ),
          htmltools::tags$p(
            id = "impo-sector-cumulative-scroll-hint",
            class = "rigi-scroll-hint",
            hidden = "hidden",
            "Deslizá el gráfico para ver más períodos →"
          ),
          htmltools::tags$p(
            class = "impo-chart-note",
            "El acumulado considera las importaciones desde el primer mes disponible en la serie."
          )
        )
      ),

      # -------------------------------------------------------------------
      # Subsección: importaciones por proyecto
      # -------------------------------------------------------------------
      htmltools::tags$section(
        class = "impo-subsection impo-subsection--project",
        htmltools::div(
          class = "impo-subsection__header",
          htmltools::tags$h3(class = "impo-view-title", "Importaciones por proyecto"),
          htmltools::tags$p(
            class = "impo-view-subtitle",
            "Evolución mensual y acumulada de las importaciones, desagregada por proyecto."
          ),
          htmltools::tags$p(
            class = "impo-interaction-note",
            "Seleccioná uno, varios o todos los proyectos con las etiquetas inferiores. Si dejás un único proyecto seleccionado, podés desplegar su ficha resumida."
          )
        ),
        htmltools::div(
          class = "impo-filter-panel impo-filter-panel--project",
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$label(`for` = "impo-project-month-start", "Período inicial"),
            htmltools::tags$input(
              type = "month",
              id = "impo-project-month-start",
              class = "impo-input",
              min = format(min_month, "%Y-%m"),
              max = format(max_month, "%Y-%m"),
              value = format(min_month, "%Y-%m")
            )
          ),
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$label(`for` = "impo-project-month-end", "Período final"),
            htmltools::tags$input(
              type = "month",
              id = "impo-project-month-end",
              class = "impo-input",
              min = format(min_month, "%Y-%m"),
              max = format(max_month, "%Y-%m"),
              value = format(max_month, "%Y-%m")
            )
          ),
          htmltools::div(
            class = "impo-filter-group",
            htmltools::tags$span(class = "impo-filter-label", "Sector de los proyectos"),
            sector_multiselect("impo-project-sector-filter", "impo-project-sector-filter-option")
          ),
          htmltools::div(
            class = "impo-filter-group impo-filter-reset",
            htmltools::tags$button(
              type = "button",
              id = "impo-project-reset",
              class = "impo-reset-button",
              "Limpiar filtros"
            )
          )
        ),
        htmltools::div(
          class = "impo-project-selector",
          htmltools::div(
            class = "impo-project-selector__header",
            htmltools::div(
              htmltools::tags$span(class = "impo-filter-label", "Proyecto"),
              htmltools::tags$p(
                id = "impo-project-selection-status",
                class = "impo-project-selection-status",
                paste0(length(projects), " proyectos seleccionados")
              )
            ),
            htmltools::div(
              class = "impo-project-selector__actions",
              htmltools::tags$button(
                type = "button",
                id = "impo-project-select-all",
                class = "impo-secondary-button",
                "Seleccionar todos"
              ),
              htmltools::tags$button(
                type = "button",
                id = "impo-project-clear",
                class = "impo-secondary-button",
                "Limpiar selección"
              )
            )
          ),
          htmltools::div(
            id = "impo-project-chips",
            class = "impo-project-chips",
            `aria-label` = "Selección de proyectos",
            lapply(projects, function(project) {
              htmltools::tags$button(
                type = "button",
                class = "impo-project-chip is-selected",
                `data-project` = project,
                `aria-pressed` = "true",
                htmltools::tags$span(
                  class = "impo-project-chip__swatch",
                  style = paste0("background-color:", project_colors[[project]], ";")
                ),
                htmltools::tags$span(
                  class = "impo-project-chip__label",
                  project
                )
              )
            })
          ),
          htmltools::tags$p(
            id = "impo-project-chips-scroll-hint",
            class = "rigi-scroll-hint impo-project-chips-scroll-hint",
            hidden = "hidden",
            "Deslizá las etiquetas para ver más proyectos →"
          ),
          htmltools::div(
            class = "impo-project-card-controls",
            htmltools::tags$button(
              type = "button",
              id = "impo-project-card-toggle",
              class = "impo-project-card-button",
              disabled = "disabled",
              "Ver ficha resumida"
            ),
            htmltools::tags$span(
              id = "impo-project-card-help",
              class = "impo-project-card-help",
              "Para consultar la ficha resumida, dejá seleccionado un solo proyecto."
            )
          ),
          htmltools::div(
            id = "impo-project-info",
            class = "impo-project-info",
            hidden = "hidden"
          )
        ),
        htmltools::div(
          class = "impo-chart-card",
          htmltools::tags$h4("Importaciones mensuales por proyecto"),
          htmltools::div(
            class = "rigi-plot-scroll",
            `data-scroll-hint` = "impo-project-monthly-scroll-hint",
            htmltools::div(
              id = "impo-project-monthly-chart",
              class = "impo-chart"
            )
          ),
          htmltools::tags$p(
            id = "impo-project-monthly-scroll-hint",
            class = "rigi-scroll-hint",
            hidden = "hidden",
            "Deslizá el gráfico para ver más períodos →"
          )
        ),
        htmltools::div(
          class = "impo-chart-card",
          htmltools::tags$h4("Importaciones acumuladas por proyecto"),
          htmltools::div(
            class = "rigi-plot-scroll",
            `data-scroll-hint` = "impo-project-cumulative-scroll-hint",
            htmltools::div(
              id = "impo-project-cumulative-chart",
              class = "impo-chart"
            )
          ),
          htmltools::tags$p(
            id = "impo-project-cumulative-scroll-hint",
            class = "rigi-scroll-hint",
            hidden = "hidden",
            "Deslizá el gráfico para ver más períodos →"
          ),
          htmltools::tags$p(
            class = "impo-chart-note",
            "El acumulado considera las importaciones desde el primer mes disponible en la serie."
          )
        )
      ),

      htmltools::div(
        class = "download-box impo-download-box",
        htmltools::strong("Descarga de datos — importaciones:"),
        htmltools::a(
          "Excel",
          href = "downloads/importaciones_proyectos.xlsx",
          download = "importaciones_proyectos.xlsx",
          class = "download-button"
        ),
        htmltools::a(
          "CSV",
          href = "downloads/importaciones_proyectos.csv",
          download = "importaciones_proyectos.csv",
          class = "download-button"
        )
      ),
      htmltools::tags$p(
        class = "impo-open-data",
        htmltools::strong("Datos abiertos. "),
        "La base de importaciones se encuentra disponible para su descarga."
      ),
      htmltools::tags$p(
        class = "impo-method-note",
      ),
      htmltools::tags$p(
        class = "impo-source",
        htmltools::strong("Fuente: "),
        "elaboración propia a partir de datos aduaneros de importaciones."
      )
    ),
    htmltools::tags$script(src = "assets/importaciones.js", defer = "defer")
  )
}
