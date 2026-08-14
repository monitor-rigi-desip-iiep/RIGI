# Planes de inversión ---------------------------------------------------------
# Este módulo utiliza exclusivamente la hoja Datos_long del archivo fuente
# data/RIGI_planes_inversion.xlsx. Genera validaciones, descargas y un módulo
# interactivo compatible con un sitio estático de Quarto/GitHub Pages.

planes_inversion_path <- file.path("data", "RIGI_planes_inversion.xlsx")
planes_inversion_sheet <- "Datos_long"

planes_required_columns <- c(
  "anio",
  "sector_key",
  "sector",
  "subsector",
  "monto_mill_usd",
  "sector_total_mill_usd",
  "total_anual_mill_usd",
  "fuente",
  "fecha_extraccion",
  "sector_presente_fuente",
  "subsector_presente_fuente"
)

planes_download_columns <- c(
  "anio",
  "sector",
  "subsector",
  "monto_mill_usd",
  "sector_total_mill_usd",
  "total_anual_mill_usd",
  "fuente"
)

load_planes_inversion <- function(path = planes_inversion_path) {
  if (!file.exists(path)) {
    stop("No se encontró el archivo de planes de inversión: ", path, call. = FALSE)
  }

  hojas <- readxl::excel_sheets(path)
  if (!planes_inversion_sheet %in% hojas) {
    stop(
      "El archivo de planes de inversión no contiene la hoja '",
      planes_inversion_sheet,
      "'.",
      call. = FALSE
    )
  }

  data <- readxl::read_excel(path, sheet = planes_inversion_sheet) |>
    janitor::clean_names()

  missing_cols <- setdiff(planes_required_columns, names(data))
  if (length(missing_cols) > 0) {
    stop(
      "Faltan columnas requeridas en Datos_long: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  data |>
    dplyr::mutate(
      anio = as.integer(anio),
      sector_key = stringr::str_squish(as.character(sector_key)),
      sector = stringr::str_squish(as.character(sector)),
      subsector = stringr::str_squish(as.character(subsector)),
      monto_mill_usd = as.numeric(monto_mill_usd),
      sector_total_mill_usd = as.numeric(sector_total_mill_usd),
      total_anual_mill_usd = as.numeric(total_anual_mill_usd),
      fuente = stringr::str_squish(as.character(fuente))
    )
}

validate_planes_inversion <- function(data, tolerance = 1e-6) {
  errors <- character(0)

  if (nrow(data) == 0) {
    errors <- c(errors, "La hoja Datos_long no contiene observaciones.")
  }

  if (any(is.na(data$anio))) {
    errors <- c(errors, "La variable anio contiene valores faltantes o inválidos.")
  }
  if (any(is.na(data$sector) | data$sector == "")) {
    errors <- c(errors, "La variable sector contiene valores vacíos.")
  }
  if (any(is.na(data$subsector) | data$subsector == "")) {
    errors <- c(errors, "La variable subsector contiene valores vacíos.")
  }
  if (any(is.na(data$monto_mill_usd))) {
    errors <- c(errors, "La variable monto_mill_usd contiene valores no numéricos o faltantes.")
  }
  if (any(data$monto_mill_usd < 0, na.rm = TRUE)) {
    errors <- c(errors, "La variable monto_mill_usd contiene valores negativos.")
  }
  if (any(is.na(data$fuente) | data$fuente == "")) {
    errors <- c(errors, "La variable fuente contiene valores vacíos.")
  }
  if (any(duplicated(data))) {
    errors <- c(errors, "Datos_long contiene filas exactamente duplicadas.")
  }

  sector_check <- data |>
    dplyr::group_by(anio, sector) |>
    dplyr::summarise(
      monto_calculado = sum(monto_mill_usd, na.rm = TRUE),
      n_totales = dplyr::n_distinct(sector_total_mill_usd),
      monto_referencia = dplyr::first(sector_total_mill_usd),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      diferencia = abs(monto_calculado - monto_referencia)
    )

  bad_sector <- sector_check |>
    dplyr::filter(n_totales != 1L | is.na(monto_referencia) | diferencia > tolerance)

  if (nrow(bad_sector) > 0) {
    examples <- bad_sector |>
      dplyr::slice_head(n = 5) |>
      dplyr::transmute(txt = paste0(anio, " / ", sector)) |>
      dplyr::pull(txt)
    errors <- c(
      errors,
      paste0(
        "La suma de monto_mill_usd no coincide con sector_total_mill_usd en: ",
        paste(examples, collapse = "; "),
        if (nrow(bad_sector) > 5) "; ..." else ""
      )
    )
  }

  annual_check <- data |>
    dplyr::group_by(anio) |>
    dplyr::summarise(
      monto_calculado = sum(monto_mill_usd, na.rm = TRUE),
      n_totales = dplyr::n_distinct(total_anual_mill_usd),
      monto_referencia = dplyr::first(total_anual_mill_usd),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      diferencia = abs(monto_calculado - monto_referencia)
    )

  bad_annual <- annual_check |>
    dplyr::filter(n_totales != 1L | is.na(monto_referencia) | diferencia > tolerance)

  if (nrow(bad_annual) > 0) {
    examples <- bad_annual |>
      dplyr::slice_head(n = 5) |>
      dplyr::pull(anio)
    errors <- c(
      errors,
      paste0(
        "La suma anual de monto_mill_usd no coincide con total_anual_mill_usd en: ",
        paste(examples, collapse = ", "),
        if (nrow(bad_annual) > 5) ", ..." else ""
      )
    )
  }

  if (length(errors) > 0) {
    stop(
      paste0(
        "Validación de RIGI_planes_inversion.xlsx fallida:\n- ",
        paste(errors, collapse = "\n- ")
      ),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

create_planes_inversion_downloads <- function(data, download_dir = "downloads") {
  dir.create(download_dir, recursive = TRUE, showWarnings = FALSE)

  export_data <- data |>
    dplyr::select(dplyr::all_of(planes_download_columns)) |>
    dplyr::arrange(anio, sector, subsector)

  csv_path <- file.path(download_dir, "planes_inversion.csv")
  xlsx_path <- file.path(download_dir, "planes_inversion.xlsx")

  readr::write_csv(export_data, csv_path, na = "")
  writexl::write_xlsx(list(Datos_long = export_data), xlsx_path)

  list(csv = csv_path, xlsx = xlsx_path)
}

planes_sector_colors <- function(sectors) {
  preferred <- c(
    "Energía Eléctrica" = "#F97316",
    "Petróleo y Gas" = "#0F766E",
    "Minería" = "#7C3AED",
    "Siderurgia" = "#BE123C",
    "Infraestructura" = "#2563EB"
  )

  fallback <- c(
    "#1D4ED8", "#EA580C", "#0D9488", "#6D28D9", "#64748B",
    "#0284C7", "#C2410C", "#15803D", "#9333EA", "#334155"
  )

  sectors <- unique(as.character(sectors))
  out <- setNames(rep(NA_character_, length(sectors)), sectors)

  fallback_i <- 1L
  for (sector in sectors) {
    if (sector %in% names(preferred)) {
      out[[sector]] <- preferred[[sector]]
    } else {
      out[[sector]] <- fallback[[fallback_i]]
      fallback_i <- if (fallback_i >= length(fallback)) 1L else fallback_i + 1L
    }
  }

  out
}

make_planes_checkbox <- function(name, value, label, class_name) {
  htmltools::tags$label(
    class = "plans-check-option",
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

make_planes_inversion_module <- function(data) {
  validate_planes_inversion(data)

  data_client <- data |>
    dplyr::select(anio, sector, subsector, monto_mill_usd) |>
    dplyr::arrange(anio, sector, subsector)

  years <- seq(min(data_client$anio, na.rm = TRUE), max(data_client$anio, na.rm = TRUE))
  sectors <- sort(unique(data_client$sector))
  subsectors <- sort(unique(data_client$subsector))
  sector_colors <- planes_sector_colors(sectors)

  data_json <- jsonlite::toJSON(
    data_client,
    dataframe = "rows",
    auto_unbox = TRUE,
    na = "null",
    digits = 15
  )
  colors_json <- jsonlite::toJSON(as.list(sector_colors), auto_unbox = TRUE)

  htmltools::tagList(
    htmltools::div(
      id = "planes-inversion-module",
      class = "plans-module",
      htmltools::tags$script(
        type = "application/json",
        id = "planes-inversion-data",
        htmltools::HTML(data_json)
      ),
      htmltools::tags$script(
        type = "application/json",
        id = "planes-inversion-colors",
        htmltools::HTML(colors_json)
      ),

      htmltools::div(
        class = "plans-filter-panel",
        htmltools::div(
          class = "plans-filter-group plans-year-filter",
          htmltools::tags$label(`for` = "planes-year-start", "Año inicial"),
          htmltools::tags$select(
            id = "planes-year-start",
            class = "plans-select",
            lapply(years, function(y) {
              attrs <- list(value = y)
              if (y == min(years)) attrs$selected <- "selected"
              do.call(htmltools::tags$option, c(list(as.character(y)), attrs))
            })
          )
        ),
        htmltools::div(
          class = "plans-filter-group plans-year-filter",
          htmltools::tags$label(`for` = "planes-year-end", "Año final"),
          htmltools::tags$select(
            id = "planes-year-end",
            class = "plans-select",
            lapply(years, function(y) {
              attrs <- list(value = y)
              if (y == max(years)) attrs$selected <- "selected"
              do.call(htmltools::tags$option, c(list(as.character(y)), attrs))
            })
          )
        ),
        htmltools::div(
          class = "plans-filter-group",
          htmltools::tags$span(class = "plans-filter-label", "Sector"),
          htmltools::tags$details(
            class = "plans-multiselect",
            id = "plans-sector-details",
            htmltools::tags$summary(id = "plans-sector-summary", "Todos los sectores"),
            htmltools::div(
              class = "plans-multiselect-menu",
              htmltools::tags$label(
                class = "plans-check-option plans-check-all",
                htmltools::tags$input(
                  type = "checkbox",
                  id = "plans-sector-all",
                  checked = "checked"
                ),
                htmltools::tags$span("Todos")
              ),
              htmltools::div(
                id = "plans-sector-options",
                lapply(sectors, function(x) {
                  make_planes_checkbox("planes-sector", x, x, "plans-sector-option")
                })
              )
            )
          )
        ),
        htmltools::div(
          class = "plans-filter-group",
          htmltools::tags$span(class = "plans-filter-label", "Subsector"),
          htmltools::tags$details(
            class = "plans-multiselect",
            id = "plans-subsector-details",
            htmltools::tags$summary(id = "plans-subsector-summary", "Todos los subsectores"),
            htmltools::div(
              class = "plans-multiselect-menu",
              htmltools::tags$label(
                class = "plans-check-option plans-check-all",
                htmltools::tags$input(
                  type = "checkbox",
                  id = "plans-subsector-all",
                  checked = "checked"
                ),
                htmltools::tags$span("Todos")
              ),
              htmltools::div(
                id = "plans-subsector-options",
                lapply(subsectors, function(x) {
                  make_planes_checkbox("planes-subsector", x, x, "plans-subsector-option")
                })
              )
            )
          )
        ),
        htmltools::div(
          class = "plans-filter-group plans-filter-reset",
          htmltools::tags$button(
            type = "button",
            id = "plans-reset",
            class = "plans-reset-button",
            "Limpiar filtros"
          )
        )
      ),

      htmltools::div(
        class = "plans-chart-card",
        htmltools::tags$h3("Planes de inversión por año"),
        htmltools::div(
          class = "rigi-plot-scroll",
          `data-scroll-hint` = "planes-annual-scroll-hint",
          htmltools::div(
            id = "planes-annual-chart",
            class = "plans-chart"
          )
        ),
        htmltools::tags$p(
          id = "planes-annual-scroll-hint",
          class = "rigi-scroll-hint",
          hidden = "hidden",
          "Deslizá el gráfico para ver más años →"
        )
      ),

      htmltools::div(
        class = "plans-chart-card",
        htmltools::tags$h3("Planes de inversión acumulados"),
        htmltools::div(
          class = "rigi-plot-scroll",
          `data-scroll-hint` = "planes-cumulative-scroll-hint",
          htmltools::div(
            id = "planes-cumulative-chart",
            class = "plans-chart"
          )
        ),
        htmltools::tags$p(
          id = "planes-cumulative-scroll-hint",
          class = "rigi-scroll-hint",
          hidden = "hidden",
          "Deslizá el gráfico para ver más años →"
        ),
        htmltools::tags$p(
          class = "plans-chart-note",
          "El acumulado considera los montos desde el primer año disponible en la serie."
        )
      ),

      htmltools::div(
        class = "download-box plans-download-box",
        htmltools::strong("Descarga de datos — planes de inversión:"),
        htmltools::a(
          "Excel",
          href = "downloads/planes_inversion.xlsx",
          download = "planes_inversion.xlsx",
          class = "download-button"
        ),
        htmltools::a(
          "CSV",
          href = "downloads/planes_inversion.csv",
          download = "planes_inversion.csv",
          class = "download-button"
        )
      ),
      htmltools::tags$p(
        class = "plans-open-data",
        htmltools::strong("Datos abiertos. "),
        "La base de planes de inversión se encuentra disponible para su descarga en formatos XLSX y CSV."
      ),
      htmltools::tags$p(
        class = "plans-source",
        htmltools::strong("Fuente: "),
        htmltools::a(
          "sitio oficial del RIGI",
          href = "https://www.argentina.gob.ar/economia/rigi",
          target = "_blank",
          rel = "noopener noreferrer"
        ),
        "."
      )
    ),
    htmltools::tags$script(src = "assets/planes_inversion.js", defer = "defer")
  )
}
