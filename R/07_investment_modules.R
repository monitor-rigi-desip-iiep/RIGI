# Módulos de inversión, cronogramas y diccionario ----------------------------

dictionary_value <- function(dictionary, variable, column, fallback = NA_character_) {
  row <- dictionary |>
    dplyr::filter(.data$variable == variable) |>
    dplyr::slice_head(n = 1)
  if (nrow(row) == 0 || !column %in% names(row) || is.na(row[[column]][[1]])) {
    return(fallback)
  }
  as.character(row[[column]][[1]])
}

investment_view_data <- function(data, data_prov, value_col, value_col_prov) {
  project <- data |>
    dplyr::transmute(
      label = dplyr::coalesce(proyecto, "No informado"),
      value = as.numeric(.data[[value_col]]),
      count = 1L
    ) |>
    dplyr::filter(!is.na(value), is.finite(value)) |>
    dplyr::arrange(dplyr::desc(value), label)

  sector <- data |>
    dplyr::filter(!is.na(.data[[value_col]]), is.finite(.data[[value_col]])) |>
    dplyr::group_by(label = dplyr::coalesce(sector_simplificado, "No informado")) |>
    dplyr::summarise(
      value = sum_or_na(.data[[value_col]]),
      count = dplyr::n_distinct(row_id),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(value), label)

  province <- data_prov |>
    dplyr::filter(!is.na(.data[[value_col_prov]]), is.finite(.data[[value_col_prov]])) |>
    dplyr::group_by(label = dplyr::coalesce(provincia_simplificada, "No informado")) |>
    dplyr::summarise(
      value = sum_or_na(.data[[value_col_prov]]),
      count = dplyr::n_distinct(row_id),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(value), label)

  list(project = project, sector = sector, province = province)
}

make_investment_explorer <- function(
  data,
  data_prov,
  dictionary,
  value_col,
  value_col_prov,
  widget_key,
  color,
  universe_label
) {
  if (!value_col %in% names(data) || !value_col_prov %in% names(data_prov)) {
    return(empty_plot_message("La variable requerida no está disponible en la base."))
  }

  views <- investment_view_data(data, data_prov, value_col, value_col_prov)
  title <- dictionary_value(dictionary, value_col, "nombre_visible", value_col)
  description <- dictionary_value(
    dictionary,
    value_col,
    "descripcion_breve",
    "Monto informado para los proyectos del universo seleccionado."
  )
  unit <- dictionary_value(dictionary, value_col, "unidad", "Millones de USD")
  widget_id <- paste0("rigi-investment-", gsub("[^A-Za-z0-9_-]+", "-", widget_key))

  payload <- list(
    title = title,
    description = description,
    unit = unit,
    universe = universe_label,
    color = color,
    views = lapply(views, function(view) {
      lapply(seq_len(nrow(view)), function(index) {
        list(
          label = as.character(view$label[[index]]),
          value = as.numeric(view$value[[index]]),
          count = as.integer(view$count[[index]])
        )
      })
    })
  )

  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 16)

  htmltools::tags$section(
    id = widget_id,
    class = "rigi-investment-module",
    `data-investment-module` = "true",
    `aria-label` = paste0(title, " — ", universe_label),
    htmltools::tags$div(
      class = "rigi-investment-module__header",
      htmltools::tags$p(class = "rigi-investment-module__description", description),
      htmltools::tags$label(
        class = "rigi-investment-module__limit",
        `for` = paste0(widget_id, "-limit"),
        htmltools::tags$span("Cantidad a mostrar"),
        htmltools::tags$select(
          id = paste0(widget_id, "-limit"),
          `data-investment-limit` = "true",
          htmltools::tags$option(value = "5", "5"),
          htmltools::tags$option(value = "10", selected = TRUE, "10"),
          htmltools::tags$option(value = "15", "15"),
          htmltools::tags$option(value = "all", "Todos")
        )
      )
    ),
    htmltools::tags$div(
      class = "rigi-investment-module__tabs",
      role = "tablist",
      `aria-label` = paste0("Desagregación de ", tolower(title)),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "true",
        `data-investment-view` = "project", "Por proyecto"
      ),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
        `data-investment-view` = "sector", "Por sector"
      ),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
        `data-investment-view` = "province", "Por provincia"
      )
    ),
    htmltools::tags$p(class = "rigi-investment-module__view-note", `data-investment-note` = "true"),
    htmltools::tags$div(
      class = "rigi-investment-module__chart",
      `data-investment-chart` = "true",
      role = "region",
      `aria-live` = "polite"
    ),
    htmltools::tags$script(
      type = "application/json",
      `data-investment-data` = "true",
      htmltools::HTML(json)
    )
  )
}

schedule_tooltip <- function(data, type) {
  if (type == "commitment") {
    paste0(
      data$proyecto,
      "<br>Fecha de adhesión: ", fmt_date(data$start),
      "<br>Fin del horizonte de 24 meses: ", fmt_date(data$end),
      "<br>Inversión comprometida en activos computables — primeros 2 años: ",
      fmt_currency_mill(data$amount, accuracy = 0.1)
    )
  } else {
    paste0(
      data$proyecto,
      "<br>Fecha de adhesión: ", fmt_date(data$start),
      "<br>Fecha límite: ", fmt_date(data$end),
      "<br>Inversión en activos computables: ",
      fmt_currency_mill(data$amount, accuracy = 0.1)
    )
  }
}

build_schedule_plot <- function(data, type = c("commitment", "deadline")) {
  type <- match.arg(type)
  approved <- data |>
    dplyr::filter(aprobado)

  if (type == "commitment") {
    eligible <- approved |>
      dplyr::filter(!is.na(fecha_adhesion_rigi)) |>
      dplyr::transmute(
        proyecto,
        start = as.Date(fecha_adhesion_rigi),
        end = as.Date(lubridate::add_with_rollback(fecha_adhesion_rigi, lubridate::years(2))),
        amount = compromiso_activos_2_anios_usd_mill
      )
    excluded_missing <- nrow(approved) - nrow(eligible)
    invalid_count <- 0L
    color <- "#2563EB"
    axis_title <- "Horizonte de 24 meses desde la adhesión"
  } else {
    complete <- approved |>
      dplyr::filter(
        !is.na(fecha_adhesion_rigi),
        !is.na(fecha_limite_inversion_minima_activos_computables)
      ) |>
      dplyr::transmute(
        proyecto,
        start = as.Date(fecha_adhesion_rigi),
        end = as.Date(fecha_limite_inversion_minima_activos_computables),
        amount = activos_computables_usd_mill
      )
    invalid_count <- sum(complete$end < complete$start, na.rm = TRUE)
    eligible <- complete |>
      dplyr::filter(end >= start)
    excluded_missing <- nrow(approved) - nrow(complete)
    color <- "#0F766E"
    axis_title <- "Desde la adhesión hasta la fecha límite"
  }

  if (nrow(eligible) == 0) {
    return(list(
      widget = empty_plot_message("No hay fechas completas y válidas para construir este cronograma."),
      included = 0L,
      excluded_missing = excluded_missing,
      invalid = invalid_count
    ))
  }

  eligible <- eligible |>
    dplyr::arrange(start, proyecto) |>
    dplyr::mutate(
      label_original = proyecto,
      label = factor(
        wrap_axis_label(proyecto, width = 34),
        levels = rev(unique(wrap_axis_label(proyecto, width = 34)))
      )
    )
  eligible$tooltip <- schedule_tooltip(eligible, type)

  p <- ggplot2::ggplot(
    eligible,
    ggplot2::aes(y = label, text = tooltip)
  ) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = end, yend = label),
      linewidth = 7,
      lineend = "round",
      color = color,
      alpha = 0.82
    ) +
    ggplot2::geom_point(ggplot2::aes(x = end), color = color, size = 3) +
    ggplot2::scale_x_date(
      date_breaks = "6 months",
      date_labels = "%m/%Y",
      expand = ggplot2::expansion(mult = c(0.01, 0.04))
    ) +
    ggplot2::labs(x = axis_title, y = NULL) +
    theme_rigi_chart() +
    ggplot2::theme(legend.position = "none")

  widget <- style_plotly(
    p,
    margin_left = smart_left_margin(eligible$label_original, min_margin = 165, max_margin = 290),
    margin_right = 35,
    margin_bottom = 70,
    margin_top = 25,
    height = smart_height(nrow(eligible), min_height = 420, per_row = 34, max_height = 900),
    mobile_min_width = 680,
    vertical_scroll = TRUE,
    hide_text_on_mobile = TRUE
  )

  list(
    widget = widget,
    included = nrow(eligible),
    excluded_missing = excluded_missing,
    invalid = invalid_count
  )
}

schedule_status_note <- function(result) {
  parts <- c(paste0(fmt_integer(result$included), " proyectos incluidos"))
  if (result$excluded_missing > 0) {
    parts <- c(parts, paste0(fmt_integer(result$excluded_missing), " excluidos por fechas faltantes"))
  }
  if (result$invalid > 0) {
    parts <- c(parts, paste0(fmt_integer(result$invalid), " excluidos por una fecha límite anterior a la adhesión"))
  }
  paste(parts, collapse = " · ")
}

make_commitment_schedule_module <- function(data) {
  commitment <- build_schedule_plot(data, "commitment")
  deadline <- build_schedule_plot(data, "deadline")

  htmltools::tagList(
    htmltools::tags$section(
      class = "rigi-schedule-block",
      htmltools::tags$h3("Compromiso de inversión de los primeros 2 años"),
      htmltools::tags$p(
        class = "rigi-schedule-block__description",
        "Cada barra representa el horizonte temporal de 24 meses desde la fecha de adhesión. El monto comprometido se consulta al tocar o pasar el cursor; la longitud representa tiempo, no inversión ejecutada."
      ),
      htmltools::tags$p(class = "rigi-schedule-block__status", schedule_status_note(commitment)),
      commitment$widget
    ),
    htmltools::tags$section(
      class = "rigi-schedule-block",
      htmltools::tags$h3("Fecha límite para alcanzar la inversión mínima"),
      htmltools::tags$p(
        class = "rigi-schedule-block__description",
        "Cada barra se extiende desde la fecha de adhesión hasta la fecha límite específica establecida para el proyecto."
      ),
      htmltools::tags$p(class = "rigi-schedule-block__status", schedule_status_note(deadline)),
      deadline$widget
    ),
    htmltools::tags$div(
      class = "note-box rigi-schedule-note",
      htmltools::tags$strong("Nota: "),
      "La fecha de adhesión se utiliza como referencia común. El plazo legal de los dos primeros años se computa desde la notificación de la aprobación, mientras que la fecha límite para alcanzar el monto mínimo de activos computables es específica de cada proyecto y surge de su resolución."
    )
  )
}

make_data_dictionary <- function(dictionary) {
  source_rows <- dictionary |>
    dplyr::select(variable, nombre_visible, tipo, unidad, descripcion_breve)

  derived_rows <- tibble::tribble(
    ~variable, ~nombre_visible, ~tipo, ~unidad, ~descripcion_breve,
    "row_id", "Identificador interno de fila", "Entera", "—", "Secuencia interna estable usada para evitar duplicaciones durante expansiones y agregaciones.",
    "estado_simplificado", "Estado simplificado", "Categórica", "—", "Clasificación editorial derivada de estado_administrativo: Aprobado, En evaluación, Rechazado u Otros.",
    "aprobado", "Indicador de proyecto aprobado", "Lógica", "Sí / No", "Vale verdadero cuando el estado administrativo normalizado corresponde a Aprobado.",
    "pendiente_aprobacion", "Indicador de proyecto en evaluación", "Lógica", "Sí / No", "Vale verdadero cuando el estado administrativo normalizado corresponde a En evaluación.",
    "fecha_aprobacion", "Fecha operacional de aprobación", "Fecha", "Fecha", "Prioriza la publicación en el Boletín Oficial y utiliza la fecha de adhesión como respaldo cuando corresponde.",
    "monto_usd_mill", "Inversión total (alias interno)", "Numérica", "Millones de USD", "Alias interno directo de inversion_total_mill_usd utilizado por componentes heredados del Monitor.",
    "activos_computables_usd_mill", "Inversión en activos computables (alias interno)", "Numérica", "Millones de USD", "Alias interno directo de inversion_activos_computables_mill_usd.",
    "compromiso_activos_2_anios_usd_mill", "Inversión comprometida — primeros 2 años (alias interno)", "Numérica", "Millones de USD", "Alias interno directo de inversion_activos_computables_comprometida_2_anios_mill_usd.",
    "empleos_directos_indirectos", "Empleo informado (alias interno)", "Numérica", "Personas", "Alias interno directo de empleos_directos_indirectos_informados.",
    "sector_simplificado", "Sector simplificado", "Categórica", "—", "Sector de origen con los faltantes rotulados como No informado.",
    "provincia_expandida", "Provincia expandida", "Categórica", "—", "Una fila por provincia para proyectos multiprovinciales.",
    "n_provincias_expandida", "Cantidad de provincias del proyecto", "Entera", "Provincias", "Número de provincias obtenido al separar la lista provincial del proyecto.",
    "proyecto_multiprovincial", "Indicador de proyecto multiprovincial", "Lógica", "Sí / No", "Vale verdadero cuando el proyecto involucra más de una provincia.",
    "monto_usd_mill_asignado_prop", "Inversión total asignada a la provincia", "Numérica", "Millones de USD", "Inversión total dividida en partes iguales entre las provincias del proyecto.",
    "activos_computables_usd_mill_asignado_prop", "Inversión en activos computables asignada a la provincia", "Numérica", "Millones de USD", "Inversión en activos computables dividida en partes iguales entre las provincias del proyecto.",
    "compromiso_activos_2_anios_usd_mill_asignado_prop", "Inversión comprometida en los primeros 2 años asignada a la provincia", "Numérica", "Millones de USD", "Compromiso de los primeros dos años dividido en partes iguales entre las provincias del proyecto.",
    "empleos_directos_indirectos_asignado_prop", "Empleo informado asignado a la provincia", "Numérica", "Personas", "Empleo informado dividido en partes iguales entre las provincias del proyecto."
  )

  build_rows <- function(rows) {
    lapply(seq_len(nrow(rows)), function(index) {
      htmltools::tags$tr(
        htmltools::tags$th(scope = "row", htmltools::tags$code(rows$variable[[index]])),
        htmltools::tags$td(rows$nombre_visible[[index]]),
        htmltools::tags$td(rows$tipo[[index]]),
        htmltools::tags$td(rows$unidad[[index]]),
        htmltools::tags$td(rows$descripcion_breve[[index]])
      )
    })
  }

  dictionary_table <- function(rows, caption) {
    htmltools::tags$div(
      class = "rigi-dictionary-scroll",
      tabindex = "0",
      `aria-label` = caption,
      htmltools::tags$table(
        class = "rigi-dictionary-table",
        htmltools::tags$caption(caption),
        htmltools::tags$thead(
          htmltools::tags$tr(
            htmltools::tags$th(scope = "col", "Nombre técnico"),
            htmltools::tags$th(scope = "col", "Nombre visible"),
            htmltools::tags$th(scope = "col", "Tipo"),
            htmltools::tags$th(scope = "col", "Unidad"),
            htmltools::tags$th(scope = "col", "Descripción breve")
          )
        ),
        htmltools::tags$tbody(build_rows(rows))
      )
    )
  }

  htmltools::tagList(
    dictionary_table(source_rows, "Variables de origen"),
    htmltools::tags$h3("Variables derivadas del Monitor"),
    dictionary_table(derived_rows, "Variables derivadas del Monitor")
  )
}
