# Módulos interactivos, cronogramas y diccionario ---------------------------

dictionary_value <- function(dictionary, variable_name, column, fallback = NA_character_) {
  row <- dictionary |>
    dplyr::filter(.data$variable == .env$variable_name) |>
    dplyr::slice_head(n = 1)
  if (nrow(row) == 0 || !column %in% names(row) || is.na(row[[column]][[1]])) {
    return(fallback)
  }
  rigi_as_utf8(
    row[[column]][[1]],
    paste0("Diccionario / ", variable_name, " / ", column)
  )
}

rigi_metric_payload_rows <- function(view) {
  lapply(seq_len(nrow(view)), function(index) {
    list(
      label = as.character(view$label[[index]]),
      value = as.numeric(view$value[[index]]),
      count = as.integer(view$count[[index]])
    )
  })
}

make_ranked_metric_module <- function(
  views,
  title,
  description,
  widget_id,
  color,
  universe_label,
  value_type = c("currency", "employment"),
  default_limit = 10L,
  show_tabs = TRUE,
  share_total = NULL,
  note_override = NULL,
  default_view = names(views)[[1]]
) {
  value_type <- match.arg(value_type)
  share_total_value <- if (
    is.numeric(share_total) && length(share_total) == 1L &&
      !is.na(share_total) && is.finite(share_total)
  ) {
    as.numeric(share_total)
  } else {
    NULL
  }
  note_override_value <- if (
    is.character(note_override) && length(note_override) == 1L &&
      !is.na(note_override) && nzchar(trimws(note_override))
  ) {
    trimws(note_override)
  } else {
    NULL
  }
  payload <- list(
    title = title,
    description = description,
    universe = universe_label,
    color = color,
    valueType = value_type,
    defaultLimit = as.character(default_limit),
    defaultView = default_view,
    shareTotal = share_total_value,
    noteOverride = note_override_value,
    views = lapply(views, rigi_metric_payload_rows)
  )
  json <- jsonlite::toJSON(
    payload,
    auto_unbox = TRUE,
    na = "null",
    null = "null",
    digits = 16
  )

  htmltools::tags$section(
    id = widget_id,
    class = paste("rigi-investment-module rigi-ranked-module", paste0("rigi-ranked-module--", value_type)),
    `data-ranked-module` = "true",
    `data-investment-module` = if (identical(value_type, "currency")) "true" else NULL,
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
          `data-ranked-limit` = "true",
          `data-investment-limit` = if (identical(value_type, "currency")) "true" else NULL,
          htmltools::tags$option(
            value = "5",
            selected = if (identical(as.character(default_limit), "5")) NA else NULL,
            "5"
          ),
          htmltools::tags$option(
            value = "10",
            selected = if (identical(as.character(default_limit), "10")) NA else NULL,
            "10"
          ),
          htmltools::tags$option(
            value = "15",
            selected = if (identical(as.character(default_limit), "15")) NA else NULL,
            "15"
          ),
          htmltools::tags$option(
            value = "all",
            selected = if (identical(as.character(default_limit), "all")) NA else NULL,
            "Todos"
          )
        )
      )
    ),
    if (isTRUE(show_tabs)) htmltools::tags$div(
      class = "rigi-investment-module__tabs",
      role = "tablist",
      `aria-label` = paste0("Desagregación de ", tolower(title)),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "true",
        `data-ranked-view` = "project", `data-investment-view` = if (identical(value_type, "currency")) "project" else NULL,
        "Por proyecto"
      ),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
        `data-ranked-view` = "sector", `data-investment-view` = if (identical(value_type, "currency")) "sector" else NULL,
        "Por sector"
      ),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
        `data-ranked-view` = "province", `data-investment-view` = if (identical(value_type, "currency")) "province" else NULL,
        "Por provincia"
      )
    ) else NULL,
    htmltools::tags$p(
      class = "rigi-investment-module__view-note",
      `data-ranked-note` = "true",
      `data-investment-note` = if (identical(value_type, "currency")) "true" else NULL
    ),
    htmltools::tags$div(
      class = "rigi-investment-module__chart",
      `data-ranked-chart` = "true",
      `data-investment-chart` = if (identical(value_type, "currency")) "true" else NULL,
      role = "region",
      `aria-live` = "polite"
    ),
    htmltools::tags$script(
      type = "application/json",
      `data-ranked-data` = "true",
      `data-investment-data` = if (identical(value_type, "currency")) "true" else NULL,
      htmltools::HTML(json)
    )
  )
}

investment_view_data <- function(data, data_prov, value_col, value_col_prov) {
  project <- data |>
    dplyr::transmute(
      label = rigi_as_utf8(dplyr::coalesce(proyecto, "No informado"), "inversión por proyecto"),
      value = as.numeric(.data[[value_col]]),
      count = 1L
    ) |>
    dplyr::filter(!is.na(value), is.finite(value)) |>
    dplyr::arrange(dplyr::desc(value), label)

  sector <- data |>
    dplyr::filter(!is.na(.data[[value_col]]), is.finite(.data[[value_col]])) |>
    dplyr::group_by(label = rigi_as_utf8(
      dplyr::coalesce(sector_simplificado, "No informado"),
      "inversión por sector"
    )) |>
    dplyr::summarise(
      value = sum_or_na(.data[[value_col]]),
      count = dplyr::n_distinct(row_id),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(value), label)

  province <- data_prov |>
    dplyr::filter(!is.na(.data[[value_col_prov]]), is.finite(.data[[value_col_prov]])) |>
    dplyr::group_by(label = rigi_as_utf8(
      dplyr::coalesce(provincia_simplificada, "No informado"),
      "inversión por provincia"
    )) |>
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
  make_ranked_metric_module(
    views = investment_view_data(data, data_prov, value_col, value_col_prov),
    title = dictionary_value(dictionary, value_col, "nombre_visible", value_col),
    description = dictionary_value(
      dictionary,
      value_col,
      "descripcion_breve",
      "Monto informado para los proyectos del universo seleccionado."
    ),
    widget_id = paste0("rigi-investment-", gsub("[^A-Za-z0-9_-]+", "-", widget_key)),
    color = color,
    universe_label = universe_label,
    value_type = "currency"
  )
}

employment_view_data <- function(data, data_prov) {
  project <- data |>
    dplyr::transmute(
      label = rigi_as_utf8(dplyr::coalesce(proyecto, "No informado"), "empleo por proyecto"),
      value = as.numeric(empleos_directos_indirectos),
      count = 1L
    ) |>
    dplyr::filter(!is.na(value), is.finite(value)) |>
    dplyr::arrange(dplyr::desc(value), label)

  sector <- data |>
    dplyr::filter(!is.na(empleos_directos_indirectos), is.finite(empleos_directos_indirectos)) |>
    dplyr::group_by(label = rigi_as_utf8(
      dplyr::coalesce(sector_simplificado, "No informado"),
      "empleo por sector"
    )) |>
    dplyr::summarise(
      value = sum_or_na(empleos_directos_indirectos),
      count = dplyr::n_distinct(row_id),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(value), label)

  province <- data_prov |>
    dplyr::filter(
      !is.na(empleos_directos_indirectos_asignado_prop),
      is.finite(empleos_directos_indirectos_asignado_prop)
    ) |>
    dplyr::group_by(label = rigi_as_utf8(
      dplyr::coalesce(provincia_simplificada, "No informado"),
      "empleo por provincia"
    )) |>
    dplyr::summarise(
      value = sum_or_na(empleos_directos_indirectos_asignado_prop),
      count = dplyr::n_distinct(row_id),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(value), label)

  list(project = project, sector = sector, province = province)
}

make_employment_explorer <- function(data, data_prov, dictionary, widget_key = "approved-employment") {
  make_ranked_metric_module(
    views = employment_view_data(data, data_prov),
    title = dictionary_value(
      dictionary,
      "empleos_directos_indirectos_informados",
      "nombre_visible",
      "Empleo informado"
    ),
    description = dictionary_value(
      dictionary,
      "empleos_directos_indirectos_informados",
      "descripcion_breve",
      "Cantidad de empleos directos e indirectos informados para el proyecto."
    ),
    widget_id = paste0("rigi-employment-", gsub("[^A-Za-z0-9_-]+", "-", widget_key)),
    color = bar_color_employment,
    universe_label = "proyectos aprobados con empleo informado",
    value_type = "employment"
  )
}

make_peelp_share_module <- function(indicators) {
  peelp_amount <- as.numeric(indicators$monto_aprobados_exportacion_largo_plazo)
  approved_amount <- as.numeric(indicators$monto_aprobado)
  if (
    length(peelp_amount) == 0 || length(approved_amount) == 0 ||
      !is.finite(peelp_amount) || !is.finite(approved_amount) || approved_amount <= 0
  ) {
    return(empty_plot_message("No hay datos suficientes para calcular la participación PEELP."))
  }

  rows <- tibble::tibble(
    label = c("PEELP", "No PEELP"),
    value = c(peelp_amount, max(approved_amount - peelp_amount, 0)),
    color = c(bar_color_peelp, "#94A3B8")
  )
  htmltools::tags$section(
    id = "rigi-peelp-share",
    class = "rigi-status-overview rigi-peelp-share-module",
    `data-peelp-share-module` = "true",
    `aria-label` = "Participación PEELP en el monto informado de proyectos aprobados",
    lapply(seq_len(nrow(rows)), function(index) {
      share <- ratio_or_na(rows$value[[index]], approved_amount)
      width <- if (is.finite(share)) {
        100 * share
      } else {
        0
      }
      accessible <- paste0(
        rows$label[[index]], ": ",
        fmt_currency_mill(rows$value[[index]], accuracy = 1), ", ",
        fmt_pct(share), " del monto informado de proyectos aprobados"
      )
      htmltools::tags$div(
        class = "rigi-status-overview__row rigi-peelp-share-module__row",
        tabindex = "0",
        `aria-label` = accessible,
        title = accessible,
        htmltools::tags$strong(rows$label[[index]]),
        htmltools::tags$div(
          class = "rigi-status-overview__track",
          `aria-hidden` = "true",
          htmltools::tags$span(
            style = sprintf("width: %.4f%%; background: %s;", width, rows$color[[index]])
          )
        ),
        htmltools::tags$span(
          class = "rigi-status-overview__value",
          paste0(
            fmt_currency_mill(rows$value[[index]], accuracy = 1),
            " · ", fmt_pct(share)
          )
        )
      )
    })
  )
}

make_peelp_ranking_module <- function(data, approved_total) {
  approved_total <- as.numeric(approved_total)
  rows <- data |>
    dplyr::transmute(
      label = rigi_as_utf8(dplyr::coalesce(proyecto, "No informado"), "ranking PEELP"),
      value = as.numeric(monto_usd_mill),
      count = 1L
    ) |>
    dplyr::filter(!is.na(value), is.finite(value)) |>
    dplyr::arrange(dplyr::desc(value), label)

  make_ranked_metric_module(
    views = list(project = rows),
    title = "Principales proyectos PEELP por monto",
    description = paste0(
      "Ranking de proyectos PEELP por inversión total informada. ",
      "La participación se calcula sobre el monto total informado de todos los proyectos aprobados."
    ),
    widget_id = "rigi-peelp-ranking",
    color = bar_color_peelp,
    universe_label = "proyectos aprobados clasificados como PEELP",
    value_type = "currency",
    default_limit = 5L,
    show_tabs = FALSE,
    share_total = approved_total,
    note_override = paste0(
      "Los proyectos se ordenan de mayor a menor. ",
      "Cada porcentaje utiliza como denominador el monto total informado de todos los proyectos aprobados."
    ),
    default_view = "project"
  )
}

schedule_view_data <- function(data, type = c("commitment", "deadline")) {
  type <- match.arg(type)
  approved <- data |> dplyr::filter(aprobado)

  if (identical(type, "commitment")) {
    eligible <- approved |>
      dplyr::filter(!is.na(fecha_adhesion_rigi)) |>
      dplyr::transmute(
        label = rigi_as_utf8(proyecto, "cronograma de compromiso"),
        start = as.Date(fecha_adhesion_rigi),
        end = as.Date(lubridate::add_with_rollback(fecha_adhesion_rigi, lubridate::years(2))),
        amount = as.numeric(compromiso_activos_2_anios_usd_mill)
      ) |>
      dplyr::arrange(start, label)
    excluded_missing <- nrow(approved) - nrow(eligible)
    invalid <- 0L
  } else {
    complete <- approved |>
      dplyr::filter(
        !is.na(fecha_adhesion_rigi),
        !is.na(fecha_limite_inversion_minima_activos_computables)
      ) |>
      dplyr::transmute(
        label = rigi_as_utf8(proyecto, "cronograma de fecha límite"),
        start = as.Date(fecha_adhesion_rigi),
        end = as.Date(fecha_limite_inversion_minima_activos_computables),
        amount = as.numeric(activos_computables_usd_mill)
      )
    invalid <- sum(complete$end < complete$start, na.rm = TRUE)
    eligible <- complete |>
      dplyr::filter(end >= start) |>
      dplyr::arrange(start, label)
    excluded_missing <- nrow(approved) - nrow(complete)
  }

  rows <- lapply(seq_len(nrow(eligible)), function(index) {
    list(
      label = as.character(eligible$label[[index]]),
      start = format(eligible$start[[index]], "%Y-%m-%d"),
      end = format(eligible$end[[index]], "%Y-%m-%d"),
      amount = as.numeric(eligible$amount[[index]])
    )
  })
  list(rows = rows, included = nrow(eligible), excludedMissing = excluded_missing, invalid = invalid)
}

make_commitment_schedule_module <- function(data) {
  payload <- list(
    views = list(
      commitment = schedule_view_data(data, "commitment"),
      deadline = schedule_view_data(data, "deadline")
    )
  )
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 16)
  widget_id <- "rigi-commitment-schedule"

  htmltools::tagList(
    htmltools::tags$section(
      id = widget_id,
      class = "rigi-schedule-module",
      `data-schedule-module` = "true",
      `aria-label` = "Compromisos y plazos de inversión",
      htmltools::tags$div(
        class = "rigi-schedule-module__header",
        htmltools::tags$p(
          "Las barras representan períodos de tiempo. El monto se informa a la derecha y no determina la longitud de la barra."
        ),
        htmltools::tags$label(
          class = "rigi-investment-module__limit",
          `for` = paste0(widget_id, "-limit"),
          htmltools::tags$span("Cantidad a mostrar"),
          htmltools::tags$select(
            id = paste0(widget_id, "-limit"),
            `data-schedule-limit` = "true",
            htmltools::tags$option(value = "5", "5"),
            htmltools::tags$option(value = "10", selected = TRUE, "10"),
            htmltools::tags$option(value = "15", "15"),
            htmltools::tags$option(value = "all", "Todos")
          )
        )
      ),
      htmltools::tags$div(
        class = "rigi-investment-module__tabs rigi-schedule-module__tabs",
        role = "tablist",
        `aria-label` = "Tipo de plazo de inversión",
        htmltools::tags$button(
          type = "button", role = "tab", `aria-selected` = "true",
          `data-schedule-view` = "commitment",
          "Compromiso de inversión de los primeros dos años"
        ),
        htmltools::tags$button(
          type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
          `data-schedule-view` = "deadline",
          "Fecha límite para alcanzar la inversión mínima"
        )
      ),
      htmltools::tags$p(
        class = "rigi-investment-module__view-note",
        `data-schedule-note` = "true"
      ),
      htmltools::tags$p(class = "rigi-schedule-module__status", `data-schedule-status` = "true"),
      htmltools::tags$div(
        class = "rigi-schedule-module__chart",
        `data-schedule-chart` = "true",
        role = "region",
        `aria-live` = "polite"
      ),
      htmltools::tags$script(
        type = "application/json",
        `data-schedule-data` = "true",
        htmltools::HTML(json)
      )
    ),
    htmltools::tags$div(
      class = "note-box rigi-schedule-note",
      htmltools::tags$strong("Nota: "),
      "La fecha de adhesión se utiliza como referencia común. El plazo legal de los dos primeros años se computa desde la notificación de la aprobación, mientras que la fecha límite para alcanzar el monto mínimo de activos computables es específica de cada proyecto y surge de su resolución."
    )
  )
}

comparison_view_data <- function(approved, evaluation, label_col) {
  approved_data <- approved |>
    dplyr::transmute(
      label = rigi_as_utf8(.data[[label_col]], paste0("comparación aprobada por ", label_col)),
      approved = as.numeric(monto_usd_mill),
      approved_present = TRUE
    )
  evaluation_data <- evaluation |>
    dplyr::transmute(
      label = rigi_as_utf8(.data[[label_col]], paste0("comparación en evaluación por ", label_col)),
      evaluation = as.numeric(monto_usd_mill),
      evaluation_present = TRUE
    )

  dplyr::full_join(approved_data, evaluation_data, by = "label") |>
    dplyr::mutate(
      approved = dplyr::if_else(is.na(approved_present), 0, approved),
      evaluation = dplyr::if_else(is.na(evaluation_present), 0, evaluation),
      total = dplyr::coalesce(approved, 0) + dplyr::coalesce(evaluation, 0)
    ) |>
    dplyr::select(label, approved, evaluation, total) |>
    dplyr::arrange(dplyr::desc(total), label)
}

comparison_payload_rows <- function(view) {
  lapply(seq_len(nrow(view)), function(index) {
    list(
      label = as.character(view$label[[index]]),
      approved = as.numeric(view$approved[[index]]),
      evaluation = as.numeric(view$evaluation[[index]])
    )
  })
}

make_comparison_explorer <- function(tables) {
  views <- list(
    sector = comparison_view_data(
      tables$sector_tbl_aprobados,
      tables$sector_tbl_pendientes,
      "sector_simplificado"
    ),
    province = comparison_view_data(
      tables$provincia_tbl_aprobados,
      tables$provincia_tbl_pendientes,
      "provincia_simplificada"
    )
  )
  payload <- list(
    colors = list(approved = bar_color_compare_approved, evaluation = bar_color_compare_pending),
    views = lapply(views, comparison_payload_rows)
  )
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, na = "null", digits = 16)
  widget_id <- "rigi-comparison-territorial-sectoral"

  htmltools::tags$section(
    id = widget_id,
    class = "rigi-investment-module rigi-comparison-module",
    `data-comparison-module` = "true",
    `aria-label` = "Comparación sectorial y territorial por estado",
    htmltools::tags$div(
      class = "rigi-investment-module__header",
      htmltools::tags$p(
        class = "rigi-investment-module__description",
        "Cada participación se calcula dentro del monto total informado de su propio estado administrativo."
      ),
      htmltools::tags$label(
        class = "rigi-investment-module__limit",
        `for` = paste0(widget_id, "-limit"),
        htmltools::tags$span("Cantidad a mostrar"),
        htmltools::tags$select(
          id = paste0(widget_id, "-limit"),
          `data-comparison-limit` = "true",
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
      `aria-label` = "Desagregación de la comparación",
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "true",
        `data-comparison-view` = "sector", "Por sector"
      ),
      htmltools::tags$button(
        type = "button", role = "tab", `aria-selected` = "false", tabindex = "-1",
        `data-comparison-view` = "province", "Por provincia"
      )
    ),
    htmltools::tags$p(
      class = "rigi-investment-module__view-note",
      `data-comparison-note` = "true"
    ),
    htmltools::tags$div(
      class = "rigi-comparison-module__legend",
      htmltools::tags$span(class = "is-approved", "Aprobados"),
      htmltools::tags$span(class = "is-evaluation", "En evaluación")
    ),
    htmltools::tags$div(
      class = "rigi-comparison-module__chart",
      `data-comparison-chart` = "true",
      role = "region",
      `aria-live` = "polite"
    ),
    htmltools::tags$script(
      type = "application/json",
      `data-comparison-data` = "true",
      htmltools::HTML(json)
    )
  )
}

make_comparison_overview <- function(indicators) {
  values <- c(as.numeric(indicators$monto_aprobado), as.numeric(indicators$monto_pendiente))
  maximum <- if (any(is.finite(values))) max(values, na.rm = TRUE) else NA_real_
  total <- sum(values, na.rm = TRUE)
  rows <- tibble::tibble(
    label = c("Aprobados", "En evaluación"),
    value = values,
    count = c(as.numeric(indicators$n_aprobados), as.numeric(indicators$n_pendientes)),
    color = c(bar_color_compare_approved, bar_color_compare_pending)
  )

  htmltools::tags$section(
    class = "rigi-status-overview",
    `aria-label` = "Comparación del monto informado por estado",
    lapply(seq_len(nrow(rows)), function(index) {
      share <- ratio_or_na(rows$value[[index]], total)
      width <- if (is.finite(maximum) && maximum > 0) 100 * rows$value[[index]] / maximum else 0
      accessible <- paste0(
        rows$label[[index]], ": ", fmt_currency_mill(rows$value[[index]], accuracy = 1),
        ", ", fmt_pct(share), ", ", fmt_integer(rows$count[[index]]), " proyectos"
      )
      htmltools::tags$div(
        class = "rigi-status-overview__row",
        tabindex = "0",
        `aria-label` = accessible,
        title = accessible,
        htmltools::tags$strong(rows$label[[index]]),
        htmltools::tags$div(
          class = "rigi-status-overview__track",
          htmltools::tags$span(style = sprintf("width: %.4f%%; background: %s;", width, rows$color[[index]]))
        ),
        htmltools::tags$span(
          class = "rigi-status-overview__value",
          paste0(fmt_currency_mill(rows$value[[index]], accuracy = 1), " · ", fmt_pct(share))
        )
      )
    })
  )
}

make_state_composition <- function(data) {
  total <- sum(data$n_proyectos, na.rm = TRUE)
  maximum <- max(data$n_proyectos, na.rm = TRUE)
  colors <- c(
    "Aprobado" = bar_color_compare_approved,
    "En evaluación" = bar_color_compare_pending,
    "Rechazado" = bar_color_neutral
  )
  data <- data |>
    dplyr::mutate(
      state_order = match(estado_simplificado, c("Aprobado", "En evaluación", "Rechazado"))
    ) |>
    dplyr::arrange(state_order)

  htmltools::tags$section(
    class = "rigi-status-composition",
    `aria-label` = "Composición por estado administrativo",
    lapply(seq_len(nrow(data)), function(index) {
      state <- as.character(data$estado_simplificado[[index]])
      value <- as.numeric(data$n_proyectos[[index]])
      share <- ratio_or_na(value, total)
      width <- if (is.finite(maximum) && maximum > 0) 100 * value / maximum else 0
      color <- unname(colors[[state]])
      if (is.null(color) || is.na(color)) color <- bar_color_neutral
      accessible <- paste0(state, ": ", fmt_integer(value), " proyectos, ", fmt_pct(share))
      htmltools::tags$div(
        class = "rigi-status-composition__row",
        tabindex = "0",
        `aria-label` = accessible,
        title = paste0(accessible, ". Monto: ", fmt_currency_mill(data$monto_usd_mill[[index]], accuracy = 1)),
        htmltools::tags$strong(state),
        htmltools::tags$div(
          class = "rigi-status-composition__track",
          htmltools::tags$span(style = sprintf("width: %.4f%%; background: %s;", width, color))
        ),
        htmltools::tags$span(
          class = "rigi-status-composition__value",
          paste0(fmt_integer(value), " · ", fmt_pct(share))
        )
      )
    })
  )
}

make_data_dictionary <- function(dictionary) {
  excluded <- c(
    "justificacion_preexistencia_boletin_oficial",
    "clasificacion_preexistencia_boletin_oficial"
  )
  source_rows <- dictionary |>
    dplyr::filter(!variable %in% excluded) |>
    dplyr::select(variable, nombre_visible, tipo, unidad, descripcion_breve) |>
    rigi_utf8_data_frame(context = "diccionario metodológico")

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

  htmltools::tags$div(
    class = "rigi-dictionary-scroll",
    tabindex = "0",
    `aria-label` = "Variables de origen",
    htmltools::tags$table(
      class = "rigi-dictionary-table",
      htmltools::tags$caption("Variables de origen"),
      htmltools::tags$thead(
        htmltools::tags$tr(
          htmltools::tags$th(scope = "col", "Nombre técnico"),
          htmltools::tags$th(scope = "col", "Nombre visible"),
          htmltools::tags$th(scope = "col", "Tipo"),
          htmltools::tags$th(scope = "col", "Unidad"),
          htmltools::tags$th(scope = "col", "Descripción breve")
        )
      ),
      htmltools::tags$tbody(build_rows(source_rows))
    )
  )
}
