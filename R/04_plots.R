# Visualizaciones y componentes HTML -----------------------------------------

# Paleta visual del dashboard: colores sobrios, contrastados y aptos para lectura en web.
bar_color_approved <- "#2563EB"        # azul
bar_color_pending <- "#F97316"         # naranja
bar_color_compare_approved <- "#2563EB"
bar_color_compare_pending <- "#F97316"
bar_color_employment <- "#0F766E"      # verde petróleo
bar_color_peelp <- "#7C3AED"           # violeta
bar_color_neutral <- "#475569"         # slate
bar_color_timeline <- "#7C3AED"        # violeta
bar_color_timeline_border <- "#4C1D95"

# Helpers de estética ---------------------------------------------------------

wrap_axis_label <- function(x, width = 28, max_lines = 2) {
  x <- as.character(x)
  x <- stringr::str_squish(x)
  x[is.na(x) | x == ""] <- "s/d"

  wrapped <- stringr::str_wrap(x, width = width)

  vapply(wrapped, function(z) {
    parts <- unlist(strsplit(z, "\n", fixed = TRUE), use.names = FALSE)
    if (length(parts) <= max_lines) {
      return(paste(parts, collapse = "\n"))
    }

    first_line <- parts[1]
    rest <- paste(parts[-1], collapse = " ")
    second_line <- stringr::str_trunc(rest, width = width, side = "right")
    paste(first_line, second_line, sep = "\n")
  }, character(1))
}

wrap_title <- function(x, width = 78) {
  if (is.null(x) || length(x) == 0 || is.na(x[[1]]) || !nzchar(trimws(x[[1]]))) {
    return(NULL)
  }
  stringr::str_wrap(as.character(x), width = width)
}

chart_share <- function(x, total = NULL) {
  if (is.null(total) || length(total) == 0) {
    total <- sum(x, na.rm = TRUE)
  }
  if (length(total) == 1) {
    if (!is.finite(total) || total <= 0) return(rep(NA_real_, length(x)))
    return(x / total)
  }

  total <- rep(total, length.out = length(x))
  out <- x / total
  out[!is.finite(total) | total <= 0] <- NA_real_
  out
}

chart_monto_label <- function(x, share) {
  paste0("US$ ", fmt_number(x, accuracy = 1), " M · ", fmt_pct(share))
}

chart_empleo_label <- function(x, share) {
  paste0(fmt_integer(x), " · ", fmt_pct(share))
}

chart_count_label <- function(x, share) {
  paste0(fmt_integer(x), " · ", fmt_pct(share))
}

format_month_year_es <- function(x) {
  meses <- c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")
  x <- as.Date(x)
  out <- paste0(meses[as.integer(format(x, "%m"))], "
", format(x, "%Y"))
  out[is.na(x)] <- ""
  out
}

smart_left_margin <- function(labels, min_margin = 120, max_margin = 235) {
  labels <- wrap_axis_label(labels)
  max_chars <- max(nchar(gsub("\n", "", labels)), na.rm = TRUE)
  margin <- min_margin + max(0, max_chars - 18) * 2.9
  max(min_margin, min(max_margin, margin))
}

smart_height <- function(n, min_height = 320, per_row = 31, max_height = 680) {
  n <- max(1, n)
  min(max_height, max(min_height, 130 + n * per_row))
}

theme_rigi_chart <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text = ggplot2::element_text(color = "#1F2937"),
      plot.title = ggplot2::element_text(face = "bold", size = 15.5, color = "#0F172A", margin = ggplot2::margin(b = 7)),
      plot.subtitle = ggplot2::element_text(size = 10.5, color = "#64748B", margin = ggplot2::margin(b = 10), lineheight = 1.05),
      axis.title.x = ggplot2::element_text(size = 10.5, color = "#475569", margin = ggplot2::margin(t = 8)),
      axis.title.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(color = "#475569", size = 10),
      axis.text.y = ggplot2::element_text(color = "#334155", size = 10.5, lineheight = 0.92),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(color = "#E5E7EB", linewidth = 0.35),
      axis.ticks = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "transparent", color = NA),
      panel.background = ggplot2::element_rect(fill = "transparent", color = NA),
      legend.position = "top",
      legend.justification = "left",
      legend.title = ggplot2::element_blank(),
      legend.text = ggplot2::element_text(color = "#334155", size = 10.5),
      plot.margin = ggplot2::margin(8, 12, 8, 8)
    )
}

lock_plotly_interactions <- function(widget) {
  widget$x$layout$dragmode <- FALSE

  axis_names <- grep("^[xy]axis[0-9]*$", names(widget$x$layout), value = TRUE)
  for (axis_name in axis_names) {
    widget$x$layout[[axis_name]]$fixedrange <- TRUE
  }

  widget |>
    plotly::config(
      displayModeBar = FALSE,
      responsive = TRUE,
      scrollZoom = FALSE,
      doubleClick = FALSE
    )
}

style_plotly <- function(p, margin_left = 150, margin_right = 35, margin_bottom = 65,
                         margin_top = 30, height = NULL, showlegend = NULL,
                         text_position = NULL, mobile_min_width = NULL) {
  out <- plotly::ggplotly(p, tooltip = "text") |>
    plotly::layout(
      margin = list(l = margin_left, r = margin_right, b = margin_bottom, t = margin_top),
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor = "rgba(0,0,0,0)",
      font = list(family = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif", color = "#1F2937"),
      hoverlabel = list(bgcolor = "#FFFFFF", bordercolor = "#CBD5E1", font = list(color = "#0F172A"))
    )

  # ggplotly puede centrar los textos generados por geom_text sobre el extremo
  # de las barras. Se fuerza el anclaje exterior en los gráficos que lo piden.
  if (!is.null(text_position)) {
    for (i in seq_along(out$x$data)) {
      trace <- out$x$data[[i]]
      trace_type <- if (is.null(trace$type)) "" else as.character(trace$type)
      trace_mode <- if (is.null(trace$mode)) "" else as.character(trace$mode)

      if (identical(trace_type, "scatter") && grepl("text", trace_mode, fixed = TRUE)) {
        trace$textposition <- text_position
        trace$cliponaxis <- FALSE
        out$x$data[[i]] <- trace
      }
    }
  }

  if (!is.null(height)) out <- out |> plotly::layout(height = height)
  if (!is.null(showlegend)) out <- out |> plotly::layout(showlegend = showlegend)

  out <- lock_plotly_interactions(out)

  if (is.null(mobile_min_width)) {
    mobile_min_width <- if (
      !is.null(text_position) && identical(text_position, "middle right")
    ) 520 else 0
  }

  responsive_js <- sprintf(
    "function(el, x) {
      var host = el.closest('.cell-output-display') || el.parentElement;
      var originalTextSizes = (x.data || []).map(function(trace) {
        return trace.textfont && trace.textfont.size ? trace.textfont.size : 11;
      });
      var resizeTimer = null;
      var lastHostWidth = -1;

      if (host) host.classList.add('rigi-static-plot-host');

      function getHint() {
        if (!host) return null;
        var hint = host.querySelector('.rigi-static-plot-hint');
        if (!hint) {
          hint = document.createElement('p');
          hint.className = 'rigi-scroll-hint rigi-static-plot-hint';
          hint.textContent = 'Deslizá el gráfico para ver todo el contenido →';
          hint.hidden = true;
          host.appendChild(hint);
        }
        return hint;
      }

      function resizeRigiChart() {
        var compact = window.matchMedia('(max-width: 640px)').matches;
        var tablet = !compact && window.matchMedia('(max-width: 900px)').matches;
        var hostWidth = host ? host.clientWidth : el.getBoundingClientRect().width;
        lastHostWidth = hostWidth;
        var mobileMinWidth = %s;
        var useScroll = compact && mobileMinWidth > 0 && hostWidth < mobileMinWidth - 2;

        el.style.width = useScroll ? mobileMinWidth + 'px' : '100%%';
        el.style.minWidth = useScroll ? mobileMinWidth + 'px' : '0';
        el.style.maxWidth = 'none';

        var plotWidth = useScroll ? mobileMinWidth : Math.max(1, hostWidth);
        var nextLeft = compact
          ? (useScroll ? %s : Math.max(68, Math.min(%s, Math.round(plotWidth * 0.34))))
          : %s;
        var nextRight = compact ? 12 : (tablet ? Math.min(%s, 24) : %s);
        var nextBottom = compact ? Math.min(%s, 54) : %s;
        var hint = getHint();
        if (host) host.classList.toggle('is-overflowing', useScroll);
        if (hint) hint.hidden = !useScroll;

        Plotly.Plots.resize(el);
        Plotly.relayout(el, {
          'dragmode': false,
          'margin.l': nextLeft,
          'margin.r': nextRight,
          'margin.b': nextBottom,
          'font.size': compact ? 10 : (tablet ? 11 : 12),
          'yaxis.tickfont.size': compact ? 9.5 : (tablet ? 10 : 10.5),
          'xaxis.tickfont.size': compact ? 9 : (tablet ? 9.5 : 10),
          'xaxis.fixedrange': true,
          'yaxis.fixedrange': true
        });

        (x.data || []).forEach(function(trace, index) {
          if (trace.type === 'scatter' && String(trace.mode || '').indexOf('text') !== -1) {
            Plotly.restyle(el, { 'textfont.size': compact ? 10 : originalTextSizes[index] }, [index]);
          }
        });
      }

      function scheduleResize() {
        var nextWidth = host ? host.clientWidth : el.getBoundingClientRect().width;
        if (Math.abs(nextWidth - lastHostWidth) < 1) return;
        window.clearTimeout(resizeTimer);
        resizeTimer = window.setTimeout(resizeRigiChart, 140);
      }

      window.setTimeout(resizeRigiChart, 0);

      if (el._rigiResizeObserver) el._rigiResizeObserver.disconnect();
      if (typeof ResizeObserver !== 'undefined' && host) {
        el._rigiResizeObserver = new ResizeObserver(scheduleResize);
        el._rigiResizeObserver.observe(host);
      } else {
        if (el._rigiResizeHandler) window.removeEventListener('resize', el._rigiResizeHandler);
        el._rigiResizeHandler = scheduleResize;
        window.addEventListener('resize', scheduleResize, { passive: true });
      }
    }",
    mobile_min_width,
    margin_left,
    margin_left,
    margin_left,
    margin_right,
    margin_right,
    margin_bottom,
    margin_bottom
  )

  htmlwidgets::onRender(out, responsive_js)
}

make_source_note <- function() {
  htmltools::div(
    class = "source-note-box",
    htmltools::strong("Fuentes y alcance."),
    htmltools::tags$br(),
    htmltools::tags$br(),
    htmltools::strong("Proyectos aprobados. "),
    "Las principales fuentes son las resoluciones publicadas en el ",
    htmltools::a(
      "Boletín Oficial",
      href = "https://www.boletinoficial.gob.ar/",
      target = "_blank",
      rel = "noopener noreferrer"
    ),
    " y el ",
    htmltools::a(
      "sitio oficial del RIGI",
      href = "https://www.argentina.gob.ar/economia/rigi",
      target = "_blank",
      rel = "noopener noreferrer"
    ),
    ". La identificación de las empresas involucradas en cada proyecto se complementa con datos de ",
    htmltools::a(
      "Globaris",
      href = globaris_source_url,
      target = "_blank",
      rel = "noopener noreferrer"
    ),
    ".",
    htmltools::tags$br(),
    htmltools::tags$br(),
    htmltools::strong("Proyectos en evaluación. "),
    "El relevamiento se construye a partir de distintas fuentes públicas, entre ellas ",
    htmltools::a(
      "Globaris",
      href = globaris_source_url,
      target = "_blank",
      rel = "noopener noreferrer"
    ),
    ", sitios web empresariales, anuncios públicos y medios periodísticos. Esta información se complementa con otras fuentes disponibles cuando resulta necesario. Las fuentes utilizadas se detallan en la ficha de cada proyecto para garantizar la trazabilidad de la información.",
    htmltools::tags$br(),
    htmltools::tags$br(),
    htmltools::strong("Empleo. "),
    "Los datos de empleo directo e indirecto corresponden a los valores informados en el ",
    htmltools::a(
      "sitio oficial del RIGI",
      href = "https://www.argentina.gob.ar/economia/rigi",
      target = "_blank",
      rel = "noopener noreferrer"
    ),
    "."
  )
}

make_province_note <- function() {
  htmltools::div(
    class = "note-box",
    "Cuando un proyecto abarca más de una provincia, el monto de inversión, los activos computables y el empleo informado se distribuyen en partes iguales entre las provincias involucradas."
  )
}

make_download_links <- function(type = c("aprobados", "pendientes", "total")) {
  type <- match.arg(type)
  download_config <- switch(
    type,
    aprobados = list(title = "Descarga de datos — proyectos aprobados:", stem = "base_interactiva_aprobados"),
    pendientes = list(title = "Descarga de datos — proyectos en evaluación:", stem = "base_interactiva_pendientes"),
    total = list(title = "Descarga de datos — base completa:", stem = "base_completa")
  )

  htmltools::div(
    class = "download-box",
    htmltools::strong(download_config$title),
    htmltools::a(
      "Excel",
      href = paste0("downloads/", download_config$stem, ".xlsx"),
      download = paste0(download_config$stem, ".xlsx"),
      class = "download-button"
    ),
    htmltools::a(
      "CSV",
      href = paste0("downloads/", download_config$stem, ".csv"),
      download = paste0(download_config$stem, ".csv"),
      class = "download-button"
    )
  )
}

make_kpi_card <- function(label, value, sublabel = NULL) {
  htmltools::div(
    class = "kpi-card",
    htmltools::div(class = "kpi-label", label),
    htmltools::div(class = "kpi-value", value),
    if (!is.null(sublabel)) htmltools::div(class = "kpi-sublabel", sublabel)
  )
}

make_kpi_cards_aprobados <- function(ind) {
  htmltools::div(
    class = "kpi-grid kpi-grid-approved",
    make_kpi_card("Proyectos aprobados", fmt_integer(ind$n_aprobados), "Cantidad de proyectos"),
    make_kpi_card("Monto de proyectos aprobados", fmt_currency_mill(ind$monto_aprobado, accuracy = 1), "Millones de USD"),
    make_kpi_card("Activos computables", fmt_currency_mill(ind$activos_aprobados, accuracy = 1), "Proyectos aprobados · millones de USD"),
    make_kpi_card("Empleo informado", fmt_integer(ind$empleos_aprobados), "Directos e indirectos"),
    make_kpi_card("Monto promedio informado", fmt_currency_mill(ind$monto_promedio_aprobado, accuracy = 1), "Por proyecto aprobado"),
    make_kpi_card("Monto mediano informado", fmt_currency_mill(ind$monto_mediano_aprobado, accuracy = 1), "Por proyecto aprobado")
  )
}

make_kpi_cards_empleo_aprobado <- function(ind) {
  htmltools::div(
    class = "kpi-grid kpi-grid-employment",
    make_kpi_card("Empleo informado", fmt_integer(ind$empleos_aprobados), "Directos e indirectos"),
    make_kpi_card("Empleo promedio informado", fmt_integer(ind$empleos_promedio_aprobados), "Por proyecto aprobado"),
    make_kpi_card("Empleo mediano informado", fmt_integer(ind$empleos_mediana_aprobados), "Por proyecto aprobado"),
    make_kpi_card("Proyecto con mayor empleo", ind$empleo_top_proyecto, "Entre aprobados"),
    make_kpi_card("Sector con mayor empleo", ind$empleo_top_sector, "Entre aprobados"),
    make_kpi_card("Provincia con mayor empleo", ind$empleo_top_provincia, "Asignación en partes iguales si es multiprovincial")
  )
}

make_kpi_cards_exportacion_largo_plazo <- function(ind) {
  htmltools::div(
    class = "kpi-grid kpi-grid-peelp",
    make_kpi_card("Proyectos aprobados PEELP", fmt_integer(ind$n_aprobados_exportacion_largo_plazo), "Cantidad de proyectos"),
    make_kpi_card("Monto de inversión PEELP", fmt_currency_mill(ind$monto_aprobados_exportacion_largo_plazo, accuracy = 1), "Inversión total informada"),
    make_kpi_card("Activos computables asociados", fmt_currency_mill(ind$activos_aprobados_exportacion_largo_plazo, accuracy = 1), "Millones de USD"),
    make_kpi_card("Empleo asociado", fmt_integer(ind$empleos_aprobados_exportacion_largo_plazo), "Directos e indirectos"),
    make_kpi_card("Participación de proyectos PEELP", fmt_pct(ind$participacion_aprobados_exportacion_largo_plazo), "Sobre la cantidad de proyectos aprobados"),
    make_kpi_card("Participación del monto PEELP", fmt_pct(ind$participacion_monto_aprobados_exportacion_largo_plazo), "Sobre el monto informado de proyectos aprobados")
  )
}

make_kpi_cards_pendientes <- function(ind) {
  htmltools::div(
    class = "kpi-grid kpi-grid-pending",
    make_kpi_card("Proyectos en evaluación", fmt_integer(ind$n_pendientes), "Cantidad de proyectos"),
    make_kpi_card("Monto informado", fmt_currency_mill(ind$monto_pendiente, accuracy = 1), "Proyectos en evaluación · millones de USD"),
    make_kpi_card("Activos computables informados", fmt_currency_mill(ind$activos_pendientes, accuracy = 1), "Proyectos en evaluación · millones de USD"),
    make_kpi_card("Monto promedio informado", fmt_currency_mill(ind$monto_promedio_pendiente, accuracy = 1), "Por proyecto en evaluación"),
    make_kpi_card("Monto mediano informado", fmt_currency_mill(ind$monto_mediano_pendiente, accuracy = 1), "Por proyecto en evaluación")
  )
}

make_kpi_cards_total <- function(ind) {
  htmltools::div(
    class = "kpi-grid kpi-grid-status",
    make_kpi_card("Total de proyectos", fmt_integer(ind$n_total), "Universo de la base"),
    make_kpi_card("Monto total informado", fmt_currency_mill(ind$monto_total, accuracy = 1), "Millones de USD"),
    make_kpi_card("Proyectos aprobados / total", fmt_pct(ind$participacion_proyectos_aprobados), "Participación en cantidad"),
    make_kpi_card("Monto de aprobados / total", fmt_pct(ind$participacion_monto_aprobado), "Participación en monto")
  )
}

empty_plot_message <- function(message = "No hay datos disponibles para este gráfico.") {
  htmltools::div(class = "empty-plot-box", message)
}

plot_bar_monto <- function(data, label_col, title = NULL, subtitle = NULL, fill_color = bar_color_neutral) {
  if (nrow(data) == 0 || all(is.na(data$monto_usd_mill))) return(empty_plot_message())

  count_col <- dplyr::case_when(
    "n_proyectos" %in% names(data) ~ "n_proyectos",
    "n_incidencias_provinciales" %in% names(data) ~ "n_incidencias_provinciales",
    TRUE ~ NA_character_
  )

  data_plot <- data |>
    dplyr::filter(!is.na(monto_usd_mill)) |>
    dplyr::arrange(monto_usd_mill) |>
    dplyr::mutate(
      label_original = .data[[label_col]],
      label = forcats::fct_inorder(wrap_axis_label(.data[[label_col]], width = 30)),
      count_info = if (!is.na(count_col)) as.numeric(.data[[count_col]]) else NA_real_,
      participacion = chart_share(monto_usd_mill),
      etiqueta = chart_monto_label(monto_usd_mill, participacion)
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = monto_usd_mill,
    y = label,
    text = paste0(
      label_original,
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
      "<br>Participación: ", fmt_pct(participacion),
      "<br>Proyectos/incidencias: ", fmt_integer(count_info)
    )
  )) +
    ggplot2::geom_col(fill = fill_color, width = 0.64, alpha = 0.96) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      hjust = -0.06,
      size = 3.05,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_number(x, accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.34))
    ) +
    ggplot2::labs(title = wrap_title(title), subtitle = if (!is.null(subtitle)) wrap_title(subtitle, 95) else NULL, x = "Millones de USD", y = NULL) +
    theme_rigi_chart()

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original),
    margin_right = 42,
    margin_top = if (is.null(title) && is.null(subtitle)) 22 else 76,
    height = smart_height(nrow(data_plot)),
    text_position = "middle right"
  )
}

plot_bar_empleo <- function(data, label_col, title = NULL, subtitle = NULL, fill_color = bar_color_employment) {
  if (nrow(data) == 0 || all(is.na(data$empleos_directos_indirectos))) return(empty_plot_message("No hay datos de empleo disponibles para este gráfico."))

  count_col <- dplyr::case_when(
    "n_proyectos" %in% names(data) ~ "n_proyectos",
    "n_incidencias_provinciales" %in% names(data) ~ "n_incidencias_provinciales",
    TRUE ~ NA_character_
  )

  data_plot <- data |>
    dplyr::filter(!is.na(empleos_directos_indirectos)) |>
    dplyr::arrange(empleos_directos_indirectos) |>
    dplyr::mutate(
      label_original = .data[[label_col]],
      label = forcats::fct_inorder(wrap_axis_label(.data[[label_col]], width = 30)),
      count_info = if (!is.na(count_col)) as.numeric(.data[[count_col]]) else NA_real_,
      participacion = chart_share(empleos_directos_indirectos),
      etiqueta = chart_empleo_label(empleos_directos_indirectos, participacion)
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = empleos_directos_indirectos,
    y = label,
    text = paste0(
      label_original,
      "<br>Empleo: ", fmt_integer(empleos_directos_indirectos),
      "<br>Participación: ", fmt_pct(participacion),
      "<br>Proyectos/incidencias: ", fmt_integer(count_info)
    )
  )) +
    ggplot2::geom_col(fill = fill_color, width = 0.64, alpha = 0.96) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      hjust = -0.06,
      size = 3.05,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_integer(x),
      expand = ggplot2::expansion(mult = c(0, 0.34))
    ) +
    ggplot2::labs(title = wrap_title(title), subtitle = if (!is.null(subtitle)) wrap_title(subtitle, 95) else NULL, x = "Empleos directos e indirectos", y = NULL) +
    theme_rigi_chart()

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original),
    margin_right = 42,
    margin_top = if (is.null(title) && is.null(subtitle)) 22 else 76,
    height = smart_height(nrow(data_plot)),
    text_position = "middle right"
  )
}

plot_top_proyectos_monto <- function(data, title = NULL, fill_color = bar_color_neutral,
                                     total_value = NULL, share_reference = "del monto del grupo") {
  if (nrow(data) == 0 || all(is.na(data$monto_usd_mill))) return(empty_plot_message())

  data_plot <- data |>
    dplyr::filter(!is.na(monto_usd_mill)) |>
    dplyr::mutate(ranking = dplyr::min_rank(dplyr::desc(monto_usd_mill))) |>
    dplyr::arrange(monto_usd_mill) |>
    dplyr::mutate(
      label_original = paste0(ranking, ". ", proyecto),
      label = forcats::fct_inorder(wrap_axis_label(label_original, width = 34)),
      participacion = chart_share(monto_usd_mill, total_value),
      etiqueta = chart_monto_label(monto_usd_mill, participacion),
      grupo_ranking = dplyr::case_when(
        ranking == 1 ~ "Primero",
        ranking == 2 ~ "Segundo",
        ranking == 3 ~ "Tercero",
        TRUE ~ "Resto"
      )
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = monto_usd_mill,
    y = label,
    fill = grupo_ranking,
    text = paste0(
      "Posición: ", ranking,
      "<br>",
      proyecto,
      "<br>Empresa: ", dplyr::coalesce(empresa, "s/d"),
      "<br>Sector: ", dplyr::coalesce(sector, "s/d"),
      "<br>Provincia: ", dplyr::coalesce(provincia_original, "s/d"),
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
      "<br>Participación ", share_reference, ": ", fmt_pct(participacion)
    )
  )) +
    ggplot2::geom_col(width = 0.64) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      hjust = -0.06,
      size = 3,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Primero" = fill_color,
        "Segundo" = scales::alpha(fill_color, 0.82),
        "Tercero" = scales::alpha(fill_color, 0.68),
        "Resto" = scales::alpha(fill_color, 0.48)
      ),
      guide = "none"
    ) +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_number(x, accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.34))
    ) +
    ggplot2::labs(title = wrap_title(title), x = "Millones de USD", y = NULL) +
    theme_rigi_chart() +
    ggplot2::theme(legend.position = "none")

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original, min_margin = 150, max_margin = 255),
    margin_right = 42,
    margin_top = if (is.null(title)) 22 else 70,
    height = smart_height(nrow(data_plot), min_height = 360, per_row = 34),
    text_position = "middle right"
  )
}

plot_top_proyectos_empleo <- function(data, title = NULL, fill_color = bar_color_employment,
                                      total_value = NULL) {
  if (nrow(data) == 0 || all(is.na(data$empleos_directos_indirectos))) return(empty_plot_message("No hay datos de empleo disponibles para este gráfico."))

  data_plot <- data |>
    dplyr::filter(!is.na(empleos_directos_indirectos)) |>
    dplyr::mutate(ranking = dplyr::min_rank(dplyr::desc(empleos_directos_indirectos))) |>
    dplyr::arrange(empleos_directos_indirectos) |>
    dplyr::mutate(
      label_original = paste0(ranking, ". ", proyecto),
      label = forcats::fct_inorder(wrap_axis_label(label_original, width = 34)),
      participacion = chart_share(empleos_directos_indirectos, total_value),
      etiqueta = chart_empleo_label(empleos_directos_indirectos, participacion),
      grupo_ranking = dplyr::case_when(
        ranking == 1 ~ "Primero",
        ranking == 2 ~ "Segundo",
        ranking == 3 ~ "Tercero",
        TRUE ~ "Resto"
      )
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = empleos_directos_indirectos,
    y = label,
    fill = grupo_ranking,
    text = paste0(
      "Posición: ", ranking,
      "<br>",
      proyecto,
      "<br>Empresa: ", dplyr::coalesce(empresa, "s/d"),
      "<br>Sector: ", dplyr::coalesce(sector, "s/d"),
      "<br>Provincia: ", dplyr::coalesce(provincia_original, "s/d"),
      "<br>Empleo: ", fmt_integer(empleos_directos_indirectos),
      "<br>Participación del empleo informado: ", fmt_pct(participacion)
    )
  )) +
    ggplot2::geom_col(width = 0.64) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      hjust = -0.06,
      size = 3,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        "Primero" = fill_color,
        "Segundo" = scales::alpha(fill_color, 0.82),
        "Tercero" = scales::alpha(fill_color, 0.68),
        "Resto" = scales::alpha(fill_color, 0.48)
      ),
      guide = "none"
    ) +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_integer(x),
      expand = ggplot2::expansion(mult = c(0, 0.34))
    ) +
    ggplot2::labs(title = wrap_title(title), x = "Empleos directos e indirectos", y = NULL) +
    theme_rigi_chart() +
    ggplot2::theme(legend.position = "none")

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original, min_margin = 150, max_margin = 255),
    margin_right = 42,
    margin_top = if (is.null(title)) 22 else 70,
    height = smart_height(nrow(data_plot), min_height = 360, per_row = 34),
    text_position = "middle right"
  )
}

plot_estado <- function(data, title = NULL) {
  if (nrow(data) == 0) return(empty_plot_message())

  data_plot <- data |>
    dplyr::mutate(
      label_original = estado_simplificado,
      label = forcats::fct_reorder(wrap_axis_label(estado_simplificado, width = 28), n_proyectos),
      participacion = chart_share(n_proyectos),
      etiqueta = chart_count_label(n_proyectos, participacion),
      color_estado = dplyr::case_when(
        stringr::str_detect(stringr::str_to_lower(estado_simplificado), "aprob") ~ bar_color_approved,
        stringr::str_detect(stringr::str_to_lower(estado_simplificado), "pend|eval|an[aá]l|present") ~ bar_color_pending,
        TRUE ~ bar_color_neutral
      )
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = n_proyectos,
    y = label,
    fill = color_estado,
    text = paste0(
      label_original,
      "<br>Proyectos: ", fmt_integer(n_proyectos),
      "<br>Participación: ", fmt_pct(participacion),
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1)
    )
  )) +
    ggplot2::geom_col(width = 0.64, alpha = 0.96) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      hjust = -0.07,
      size = 3.15,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_fill_identity() +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_integer(x),
      expand = ggplot2::expansion(mult = c(0, 0.34))
    ) +
    ggplot2::labs(title = wrap_title(title), x = "Cantidad de proyectos", y = NULL) +
    theme_rigi_chart() +
    ggplot2::theme(legend.position = "none")

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original),
    margin_right = 42,
    margin_top = if (is.null(title)) 22 else 70,
    height = smart_height(nrow(data_plot), min_height = 300),
    text_position = "middle right"
  )
}

plot_compare_aprobado_pendiente <- function(aprobado_tbl, pendiente_tbl, label_col, title = NULL) {
  data_plot <- dplyr::bind_rows(
    aprobado_tbl |> dplyr::transmute(label_original = .data[[label_col]], estado = "Aprobado", monto_usd_mill),
    pendiente_tbl |> dplyr::transmute(label_original = .data[[label_col]], estado = "En evaluación", monto_usd_mill)
  ) |>
    dplyr::filter(!is.na(monto_usd_mill)) |>
    dplyr::group_by(label_original) |>
    dplyr::mutate(
      total_label = sum(monto_usd_mill, na.rm = TRUE),
      participacion = chart_share(monto_usd_mill, total_label),
      etiqueta = chart_monto_label(monto_usd_mill, participacion)
    ) |>
    dplyr::ungroup() |>
    dplyr::arrange(total_label) |>
    dplyr::mutate(label = forcats::fct_inorder(wrap_axis_label(label_original, width = 30)))

  if (nrow(data_plot) == 0) return(empty_plot_message())

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = monto_usd_mill,
    y = label,
    fill = estado,
    text = paste0(
      label_original,
      "<br>", estado,
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
      "<br>Participación dentro de la categoría: ", fmt_pct(participacion)
    )
  )) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.72), width = 0.60, alpha = 0.96) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      position = ggplot2::position_dodge(width = 0.72),
      hjust = -0.07,
      size = 2.65,
      fontface = "bold",
      color = "#334155",
      show.legend = FALSE
    ) +
    ggplot2::scale_fill_manual(values = c("Aprobado" = bar_color_compare_approved, "En evaluación" = bar_color_compare_pending)) +
    ggplot2::scale_x_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_number(x, accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.42))
    ) +
    ggplot2::labs(title = wrap_title(title), x = "Millones de USD", y = NULL, fill = NULL) +
    theme_rigi_chart()

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original),
    margin_right = 52,
    margin_top = if (is.null(title)) 42 else 82,
    height = smart_height(dplyr::n_distinct(data_plot$label_original), min_height = 360, per_row = 36),
    text_position = "middle right"
  )
}

plot_compare_counts_montos <- function(ind, title = NULL) {
  data_plot <- tibble::tibble(
    grupo_original = c("Aprobados", "En evaluación"),
    proyectos = c(ind$n_aprobados, ind$n_pendientes),
    monto_usd_mill = c(ind$monto_aprobado, ind$monto_pendiente)
  ) |>
    dplyr::mutate(
      grupo = wrap_axis_label(grupo_original, width = 18),
      participacion = chart_share(monto_usd_mill),
      etiqueta = chart_monto_label(monto_usd_mill, participacion)
    )

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = grupo,
    y = monto_usd_mill,
    fill = grupo_original,
    text = paste0(
      grupo_original,
      "<br>Proyectos: ", fmt_integer(proyectos),
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
      "<br>Participación del monto: ", fmt_pct(participacion)
    )
  )) +
    ggplot2::geom_col(width = 0.56, alpha = 0.96) +
    ggplot2::geom_text(
      ggplot2::aes(label = etiqueta),
      vjust = -0.25,
      size = 3.15,
      fontface = "bold",
      color = "#334155"
    ) +
    ggplot2::scale_fill_manual(values = c("Aprobados" = bar_color_compare_approved, "En evaluación" = bar_color_compare_pending)) +
    ggplot2::scale_y_continuous(
      breaks = scales::breaks_pretty(n = 4),
      labels = function(x) fmt_number(x, accuracy = 1),
      expand = ggplot2::expansion(mult = c(0, 0.20))
    ) +
    ggplot2::labs(title = wrap_title(title), x = NULL, y = "Millones de USD") +
    theme_rigi_chart() +
    ggplot2::theme(legend.position = "none")

  style_plotly(
    p,
    margin_left = 62,
    margin_right = 34,
    margin_top = if (is.null(title)) 22 else 70,
    height = 350,
    showlegend = FALSE,
    text_position = "top center"
  )
}

plot_peelp_share <- function(ind, title = NULL) {
  peelp_amount <- as.numeric(ind$monto_aprobados_exportacion_largo_plazo)
  approved_amount <- as.numeric(ind$monto_aprobado)

  if (
    length(peelp_amount) == 0 ||
      length(approved_amount) == 0 ||
      !is.finite(peelp_amount) ||
      !is.finite(approved_amount) ||
      approved_amount <= 0
  ) {
    return(empty_plot_message("No hay datos suficientes para calcular la participación PEELP."))
  }

  data_plot <- tibble::tibble(
    clasificacion = c("PEELP", "No PEELP"),
    monto_usd_mill = c(peelp_amount, max(approved_amount - peelp_amount, 0))
  ) |>
    dplyr::mutate(
      participacion = monto_usd_mill / sum(monto_usd_mill),
      etiqueta = paste0(clasificacion, "<br>", fmt_pct(participacion)),
      tooltip = paste0(
        "<b>", clasificacion, "</b>",
        "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
        "<br>Participación en el monto de proyectos aprobados: ", fmt_pct(participacion)
      )
    )

  circular_plot <- plotly::plot_ly(
    data = data_plot,
    labels = ~clasificacion,
    values = ~monto_usd_mill,
    type = "pie",
    sort = FALSE,
    direction = "clockwise",
    rotation = 90,
    text = ~etiqueta,
    textinfo = "text",
    textposition = "inside",
    insidetextorientation = "horizontal",
    insidetextfont = list(
      family = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      color = c("#FFFFFF", "#0F172A"),
      size = 13
    ),
    hovertext = ~tooltip,
    hoverinfo = "text",
    marker = list(
      colors = c(bar_color_peelp, "#94A3B8"),
      line = list(color = "#FFFFFF", width = 2)
    )
  ) |>
    plotly::layout(
      title = if (is.null(title)) NULL else list(text = wrap_title(title)),
      height = 330,
      autosize = TRUE,
      showlegend = TRUE,
      dragmode = FALSE,
      margin = list(
        l = 16,
        r = 16,
        b = 70,
        t = if (is.null(title)) 22 else 62
      ),
      paper_bgcolor = "rgba(0,0,0,0)",
      plot_bgcolor = "rgba(0,0,0,0)",
      font = list(
        family = "Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        color = "#334155",
        size = 12
      ),
      legend = list(
        orientation = "h",
        x = 0.5,
        xanchor = "center",
        y = -0.04,
        yanchor = "top",
        font = list(size = 11)
      ),
      hoverlabel = list(
        bgcolor = "#FFFFFF",
        bordercolor = "#CBD5E1",
        font = list(color = "#0F172A")
      ),
      uniformtext = list(mode = "hide", minsize = 11)
    )

  lock_plotly_interactions(circular_plot)
}

make_chart_context_note <- function(...) {
  htmltools::div(
    class = "chart-context-note",
    htmltools::tags$span(class = "chart-context-note__dot", `aria-hidden` = "true"),
    htmltools::tags$p(...)
  )
}

# Línea de tiempo vertical de hitos RIGI ------------------------------------

timeline_text_or_sd <- function(x, squish = TRUE) {
  if (length(x) == 0 || is.na(x[[1]])) return("s/d")

  value <- as.character(x[[1]])
  value <- if (squish) stringr::str_squish(value) else stringr::str_trim(value)

  if (
    !nzchar(value) ||
      tolower(value) %in% c("na", "n/a", "nan", "null", "s/d", "sd")
  ) {
    return("s/d")
  }

  value
}

timeline_fmt_date_es <- function(x) {
  if (length(x) == 0 || is.na(x[[1]])) return("s/d")

  date_value <- as.Date(x[[1]])
  if (is.na(date_value)) return("s/d")

  meses <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")
  paste(
    as.integer(format(date_value, "%d")),
    meses[as.integer(format(date_value, "%m"))],
    format(date_value, "%Y")
  )
}

timeline_fmt_monto <- function(x) {
  if (length(x) == 0 || is.na(x[[1]])) return("s/d")

  value <- suppressWarnings(as.numeric(x[[1]]))
  if (!is.finite(value)) return("s/d")

  digits <- dplyr::case_when(
    abs(value - round(value)) < 1e-9 ~ 0,
    abs(value * 10 - round(value * 10)) < 1e-9 ~ 1,
    TRUE ~ 2
  )

  formatted <- scales::number(
    value,
    accuracy = 10^(-digits),
    big.mark = ".",
    decimal.mark = ",",
    trim = TRUE
  )

  paste0("US$ ", formatted, " millones")
}

make_rigi_institutional_milestone <- function(date, title, description, details = NULL, url = NULL) {
  event_date <- as.Date(date)
  date_label <- timeline_fmt_date_es(event_date)

  norm_link_tag <- if (is.null(url) || is.na(url) || !nzchar(stringr::str_trim(url))) {
    NULL
  } else {
    htmltools::tags$a(
      class = "rigi-milestone__norm-link",
      href = url,
      target = "_blank",
      rel = "noopener noreferrer",
      `aria-label` = paste0(title, ": ver norma oficial (se abre en una nueva pestaña)"),
      "Ver norma ",
      htmltools::tags$span(`aria-hidden` = "true", "↗")
    )
  }

  panel_content <- if (is.null(details) || is.na(details) || !nzchar(stringr::str_trim(details))) {
    norm_link_tag
  } else {
    htmltools::tagList(
      htmltools::tags$h4("Alcance normativo"),
      htmltools::tags$p(class = "rigi-milestone__description", details),
      norm_link_tag
    )
  }

  htmltools::tags$li(
    class = "rigi-milestone rigi-milestone--institutional",
    `data-timeline-kind` = "institutional",
    `data-event-date` = format(event_date, "%Y-%m-%d"),
    htmltools::tags$time(
      class = "rigi-milestone__date",
      datetime = format(event_date, "%Y-%m-%d"),
      date_label
    ),
    htmltools::tags$div(
      class = "rigi-milestone__track",
      `aria-hidden` = "true",
      htmltools::tags$span(class = "rigi-milestone__node")
    ),
    htmltools::tags$details(
      class = "rigi-milestone__details rigi-milestone__details--institutional",
      htmltools::tags$summary(
        class = "rigi-milestone__summary",
        htmltools::tags$span(
          class = "rigi-milestone__summary-copy",
          htmltools::tags$span(
            class = "rigi-milestone__institutional-title",
            htmltools::tags$strong(title)
          ),
          htmltools::tags$span(
            class = "rigi-milestone__institutional-description",
            description
          )
        ),
        htmltools::tags$span(
          class = "rigi-milestone__chevron",
          `aria-hidden` = "true"
        )
      ),
      htmltools::tags$div(
        class = "rigi-milestone__panel",
        panel_content
      )
    )
  )
}

make_rigi_project_milestone <- function(row) {
  adhesion_date <- as.Date(row$fecha_adhesion_rigi[[1]])
  adhesion_missing <- is.na(adhesion_date)

  project_name <- timeline_text_or_sd(row$proyecto)
  approval_rule <- timeline_text_or_sd(row$norma_aprobacion)
  sector <- timeline_text_or_sd(row$sector)
  province <- timeline_text_or_sd(row$provincia_original)
  amount <- timeline_fmt_monto(row$monto_usd_mill)
  presentation_date <- timeline_fmt_date_es(row$fecha_presentacion)
  owner <- timeline_text_or_sd(row$titular_proyecto)
  description <- timeline_text_or_sd(row$descripcion_del_proyecto, squish = FALSE)
  norm_link <- timeline_text_or_sd(row$link_norma)

  date_tag <- if (adhesion_missing) {
    htmltools::tags$div(
      class = "rigi-milestone__date rigi-milestone__date--missing",
      "Fecha de adhesión s/d"
    )
  } else {
    htmltools::tags$time(
      class = "rigi-milestone__date",
      datetime = format(adhesion_date, "%Y-%m-%d"),
      timeline_fmt_date_es(adhesion_date)
    )
  }

  norm_link_tag <- if (identical(norm_link, "s/d")) {
    NULL
  } else {
    htmltools::tags$a(
      class = "rigi-milestone__norm-link",
      href = norm_link,
      target = "_blank",
      rel = "noopener noreferrer",
      `aria-label` = paste0(
        "Ver norma de aprobación de ",
        project_name,
        " (se abre en una nueva pestaña)"
      ),
      "Ver norma de aprobación"
    )
  }

  htmltools::tags$li(
    class = "rigi-milestone rigi-milestone--project",
    `data-timeline-kind` = "project",
    `data-project-row-id` = timeline_text_or_sd(row$row_id),
    `data-adhesion-date` = if (adhesion_missing) "" else format(adhesion_date, "%Y-%m-%d"),
    date_tag,
    htmltools::tags$div(
      class = "rigi-milestone__track",
      `aria-hidden` = "true",
      htmltools::tags$span(class = "rigi-milestone__node")
    ),
    htmltools::tags$details(
      class = "rigi-milestone__details",
      htmltools::tags$summary(
        class = "rigi-milestone__summary",
        htmltools::tags$span(
          class = "rigi-milestone__summary-copy",
          htmltools::tags$span(
            class = "rigi-milestone__project-title",
            htmltools::tags$strong(approval_rule),
            htmltools::tags$span(`aria-hidden` = "true", " · "),
            htmltools::tags$strong(project_name)
          ),
          htmltools::tags$span(
            class = "rigi-milestone__meta",
            paste0(
              "Sector: ", sector,
              " · Provincia: ", province,
              " · Monto: ", amount,
              " · Presentación: ", presentation_date,
              " · Titular: ", owner
            )
          )
        ),
        htmltools::tags$span(
          class = "rigi-milestone__chevron",
          `aria-hidden` = "true"
        )
      ),
      htmltools::tags$div(
        class = "rigi-milestone__panel",
        htmltools::tags$h4("Descripción del proyecto"),
        htmltools::tags$p(class = "rigi-milestone__description", description),
        htmltools::tags$h4("Titular del proyecto"),
        htmltools::tags$p(owner),
        norm_link_tag
      )
    )
  )
}

make_rigi_milestones_timeline <- function(data) {
  date_cols <- c("fecha_adhesion_rigi", "fecha_presentacion")
  text_cols <- c(
    "proyecto", "norma_aprobacion", "sector", "provincia_original",
    "titular_proyecto", "descripcion_del_proyecto", "link_norma", "row_id"
  )

  for (col in setdiff(date_cols, names(data))) {
    data[[col]] <- rep(as.Date(NA), nrow(data))
  }
  for (col in setdiff(text_cols, names(data))) {
    data[[col]] <- rep(NA_character_, nrow(data))
  }
  if (!"monto_usd_mill" %in% names(data)) {
    data$monto_usd_mill <- rep(NA_real_, nrow(data))
  }

  if ("aprobado" %in% names(data)) {
    data <- data |>
      dplyr::filter(!is.na(aprobado) & aprobado)
  }

  data <- data |>
    dplyr::mutate(.project_sort = dplyr::coalesce(as.character(proyecto), "")) |>
    dplyr::arrange(
      is.na(fecha_adhesion_rigi),
      fecha_adhesion_rigi,
      stringr::str_to_lower(.project_sort)
    ) |>
    dplyr::select(-.project_sort)

  normative_events <- tibble::tribble(
    ~date, ~title, ~description, ~details, ~url,
    as.Date("2024-07-08"),
    "Ley 27.742 · Creación del RIGI",
    "Se crea el Régimen de Incentivo para Grandes Inversiones (RIGI) en el Título VII de la Ley de Bases y Puntos de Partida para la Libertad de los Argentinos.",
    "El Título VII de la Ley 27.742 (artículos 164 a 228) establece el RIGI, sus objetivos, sujetos, requisitos, incentivos y garantías aplicables a los Vehículos de Proyecto Único que adhieran al régimen.",
    "https://www.boletinoficial.gob.ar/detalleAviso/primera/310189/20240708",
    as.Date("2024-08-23"),
    "Decreto 749/2024 · Reglamentación del RIGI",
    "Se aprueba la reglamentación del Título VII de la Ley 27.742, estableciendo las disposiciones necesarias para la implementación del régimen, sus requisitos, procedimientos y marco operativo.",
    "El Decreto 749/2024 aprueba la reglamentación de los artículos 164 a 228 de la Ley 27.742 y dispone que las normas complementarias sean dictadas por la Autoridad de Aplicación y los organismos competentes.",
    "https://www.boletinoficial.gob.ar/detalleAviso/primera/312707/20240823",
    as.Date("2024-10-22"),
    "Resolución 1074/2024 · Implementación operativa del RIGI",
    "Se aprueban los procedimientos para la adhesión al régimen a través de Trámites a Distancia (TAD) y se establecen disposiciones operativas vinculadas con proveedores, importaciones y procedimientos aduaneros.",
    "La resolución aprueba los procedimientos administrativos de implementación del RIGI mediante TAD y establece reglas operativas sobre bienes susceptibles de importación, origen nacional, Ventanilla Única de Comercio Exterior y garantías aduaneras.",
    "https://www.boletinoficial.gob.ar/detalleAviso/primera/315906/20241022",
    as.Date("2026-02-19"),
    "Decreto 105/2026 · Ampliación y prórroga del RIGI",
    "Se prorroga por un año el plazo de adhesión al régimen y se incorporan los nuevos desarrollos de explotación y producción de hidrocarburos líquidos y gaseosos costa adentro entre las actividades elegibles del sector de petróleo y gas.",
    "La prórroga rige por un año a partir del 8 de julio de 2026. Para los nuevos desarrollos de hidrocarburos líquidos y gaseosos costa adentro, el decreto fija un monto mínimo de inversión en activos computables de US$ 600 millones.",
    "https://www.boletinoficial.gob.ar/detalleAviso/primera/338519/20260219",
    as.Date("2026-04-13"),
    "Resolución 484/2026 · Adecuación del criterio de larga maduración",
    "Se eleva del 30% al 35% el umbral máximo del cociente utilizado para determinar el carácter de largo plazo de las inversiones.",
    "La adecuación se realiza tras la incorporación de nuevos desarrollos de hidrocarburos costa adentro y la revisión técnica de los sectores comprendidos en el RIGI. El cociente compara el valor presente del flujo neto de caja esperado —excluidas inversiones— durante los primeros tres años desde el primer desembolso de capital con el valor presente neto de las inversiones de capital planeadas para ese mismo período. El nuevo máximo de 35% se aplica simultáneamente a todos los sectores comprendidos en el RIGI.",
    "https://www.boletinoficial.gob.ar/detalleAviso/primera/340620/20260413"
  )

  normative_entries <- lapply(
    seq_len(nrow(normative_events)),
    function(i) {
      row <- normative_events[i, , drop = FALSE]
      list(
        sort_date = row$date[[1]],
        sort_kind = 0L,
        sort_label = row$title[[1]],
        tag = make_rigi_institutional_milestone(
          date = row$date[[1]],
          title = row$title[[1]],
          description = row$description[[1]],
          details = row$details[[1]],
          url = row$url[[1]]
        )
      )
    }
  )

  project_entries <- lapply(
    seq_len(nrow(data)),
    function(i) {
      project_date <- as.Date(data$fecha_adhesion_rigi[[i]])
      list(
        sort_date = project_date,
        sort_kind = 1L,
        sort_label = timeline_text_or_sd(data$proyecto[i]),
        tag = make_rigi_project_milestone(data[i, , drop = FALSE])
      )
    }
  )

  all_entries <- c(normative_entries, project_entries)
  if (length(all_entries) > 0) {
    sort_dates <- vapply(
      all_entries,
      function(x) if (is.na(x$sort_date)) Inf else as.numeric(x$sort_date),
      numeric(1)
    )
    sort_kinds <- vapply(all_entries, function(x) x$sort_kind, integer(1))
    sort_labels <- stringr::str_to_lower(vapply(all_entries, function(x) x$sort_label, character(1)))
    all_entries <- all_entries[order(sort_dates, sort_kinds, sort_labels)]
  }

  htmltools::tags$ol(
    class = "rigi-milestones",
    do.call(htmltools::tagList, lapply(all_entries, `[[`, "tag"))
  )
}

plot_timeline <- function(data, date_col = "fecha_aprobacion", title = NULL) {
  if (nrow(data) == 0 || all(is.na(data[[date_col]]))) return(empty_plot_message())

  data_plot <- data |>
    dplyr::filter(!is.na(.data[[date_col]])) |>
    dplyr::arrange(.data[[date_col]], proyecto) |>
    dplyr::mutate(
      y_pos = rev(dplyr::row_number()),
      label_original = dplyr::coalesce(proyecto, "s/d"),
      label_wrapped = wrap_axis_label(label_original, width = 32),
      monto_size = dplyr::if_else(
        is.na(monto_usd_mill) | monto_usd_mill <= 0,
        1,
        monto_usd_mill
      ),
      monto_label = dplyr::if_else(
        is.na(monto_usd_mill),
        "Monto s/d",
        paste0("US$ ", fmt_number(monto_usd_mill, accuracy = 1), " M")
      )
    )

  y_break_order <- order(data_plot$y_pos)
  date_min <- min(data_plot[[date_col]], na.rm = TRUE)
  date_max <- max(data_plot[[date_col]], na.rm = TRUE)

  p <- ggplot2::ggplot(data_plot, ggplot2::aes(
    x = .data[[date_col]],
    y = y_pos,
    size = monto_size,
    text = paste0(
      proyecto,
      "<br>Fecha: ", fmt_date(.data[[date_col]]),
      "<br>Estado: ", estado_simplificado,
      "<br>Monto: ", fmt_currency_mill(monto_usd_mill, accuracy = 1),
      "<br>Tamaño del punto: monto del proyecto"
    )
  )) +
    ggplot2::geom_point(
      shape = 21,
      color = bar_color_timeline_border,
      fill = bar_color_timeline,
      stroke = 0.7,
      alpha = 0.82
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = monto_label),
      hjust = -0.16,
      size = 2.75,
      color = "#334155",
      fontface = "bold",
      show.legend = FALSE
    ) +
    ggplot2::scale_size_continuous(
      range = c(5, 14),
      name = "Monto del proyecto\n(millones de USD)",
      breaks = scales::breaks_pretty(n = 3),
      labels = function(x) fmt_number(x, accuracy = 1),
      guide = ggplot2::guide_legend(
        title.position = "top",
        direction = "horizontal",
        nrow = 1,
        label.position = "bottom"
      )
    ) +
    ggplot2::scale_x_date(
      date_breaks = "3 months",
      labels = format_month_year_es,
      limits = c(date_min - 28, date_max + 105),
      expand = c(0, 0)
    ) +
    ggplot2::scale_y_continuous(
      breaks = data_plot$y_pos[y_break_order],
      labels = data_plot$label_wrapped[y_break_order],
      expand = ggplot2::expansion(add = 0.65)
    ) +
    ggplot2::labs(
      title = wrap_title(title),
      x = "Fecha de presentación",
      y = NULL
    ) +
    theme_rigi_chart() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(size = 9.5, lineheight = 0.95),
      axis.text.y = ggplot2::element_text(
        size = 9.5,
        color = "#334155",
        lineheight = 0.92
      ),
      panel.grid.major.y = ggplot2::element_line(color = "#EEF2F7", linewidth = 0.45),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.justification = "left",
      legend.text = ggplot2::element_text(size = 9),
      legend.title = ggplot2::element_text(size = 9.5, face = "bold", color = "#334155"),
      legend.spacing.x = grid::unit(0.12, "cm"),
      legend.key.width = grid::unit(0.62, "cm")
    )

  style_plotly(
    p,
    margin_left = smart_left_margin(data_plot$label_original, min_margin = 175, max_margin = 285),
    margin_right = 58,
    margin_bottom = 72,
    margin_top = if (is.null(title)) 78 else 106,
    height = smart_height(nrow(data_plot), min_height = 540, per_row = 34, max_height = 820),
    showlegend = TRUE,
    text_position = "middle right"
  )
}

make_datatable <- function(data, caption = NULL) {
  source_html <- if ("fuentes_lista" %in% names(data)) {
    vapply(data$fuentes_lista, render_project_sources_html, character(1))
  } else {
    htmltools::htmlEscape(dplyr::coalesce(as.character(data$fuentes), ""))
  }

  data_display <- data |>
    dplyr::mutate(fuentes_web = source_html) |>
    dplyr::select(
      proyecto,
      proyecto_de_exportacion_estrategia_largo_plazo,
      empresa,
      titular_proyecto,
      sector,
      subsector,
      provincia_original,
      localidad_region,
      monto_usd_mill,
      activos_computables_usd_mill,
      empleos_directos_indirectos,
      estado,
      fecha_presentacion,
      fecha_aprobacion,
      norma_aprobacion,
      link_norma,
      fuentes_web
    ) |>
    dplyr::rename(
      Proyecto = proyecto,
      `Proyectos de exportación estratégica de largo plazo (PEELP)` = proyecto_de_exportacion_estrategia_largo_plazo,
      Empresa = empresa,
      `Titular / VPU` = titular_proyecto,
      Sector = sector,
      Subsector = subsector,
      Provincia = provincia_original,
      `Localidad / región` = localidad_region,
      `Monto (mill. USD)` = monto_usd_mill,
      `Activos Computables (mill. USD)` = activos_computables_usd_mill,
      `Empleos (directos e indirectos)` = empleos_directos_indirectos,
      `Estado administrativo` = estado,
      `Fecha de presentación` = fecha_presentacion,
      `Fecha de aprobación` = fecha_aprobacion,
      `Norma de aprobación` = norma_aprobacion,
      `Link norma` = link_norma,
      Fuentes = fuentes_web
    )

  DT::datatable(
    data_display,
    caption = caption,
    rownames = FALSE,
    escape = setdiff(names(data_display), "Fuentes"),
    filter = "top",
    extensions = c("Buttons"),
    class = "stripe hover order-column compact",
    options = list(
      pageLength = 10,
      scrollX = TRUE,
      dom = "Bfrtip",
      buttons = c("copy", "csv", "excel"),
      language = list(url = "https://cdn.datatables.net/plug-ins/1.13.7/i18n/es-ES.json")
    )
  ) |>
    DT::formatRound(columns = c("Monto (mill. USD)", "Activos Computables (mill. USD)"), digits = 1, mark = ".", dec.mark = ",") |>
    DT::formatRound(columns = c("Empleos (directos e indirectos)"), digits = 0, mark = ".", dec.mark = ",")
}

# Opción 3: fichas de proyectos --------------------------------------------

rigi_card_value <- function(x) {
  value <- as.character(x)
  value[is.na(value) | trimws(value) == ""] <- "s/d"
  value
}

rigi_card_date <- function(x) {
  value <- fmt_date(x)
  value[is.na(value) | trimws(value) == ""] <- "s/d"
  value
}

rigi_card_amount <- function(x) {
  if (length(x) == 0 || is.na(x) || is.nan(x)) return("s/d")
  paste0("US$ ", fmt_number(x, accuracy = 0.1), " millones")
}

rigi_card_integer <- function(x) {
  if (length(x) == 0 || is.na(x) || is.nan(x)) return("s/d")
  fmt_integer(x)
}

rigi_card_field <- function(label, value, class = NULL) {
  htmltools::tags$div(
    class = paste("rigi-card-field", class),
    htmltools::tags$dt(label),
    htmltools::tags$dd(rigi_card_value(value))
  )
}

rigi_card_link <- function(url, label) {
  value <- safe_http_url(url)
  if (length(value) == 0 || is.na(value[[1]])) return(NULL)

  htmltools::tags$a(
    class = "rigi-project-card__link",
    href = value[[1]],
    target = "_blank",
    rel = "noopener noreferrer",
    label
  )
}

render_project_sources <- function(sources, fallback = NA_character_) {
  if (!is.data.frame(sources) || nrow(sources) == 0) {
    fallback_value <- empty_to_na(as.character(fallback))
    if (length(fallback_value) == 0 || is.na(fallback_value[[1]])) return(NULL)
    return(htmltools::tags$span(class = "rigi-project-card__source-text", fallback_value[[1]]))
  }

  source_names <- dplyr::coalesce(
    empty_to_na(as.character(sources$fuente)),
    infer_source_name_from_url(sources$url),
    "Fuente"
  )
  source_keys <- normalize_source_key(source_names)
  repeated <- ave(source_keys, source_keys, FUN = length) > 1
  occurrence <- ave(seq_along(source_keys), source_keys, FUN = seq_along)
  labels <- source_names

  has_date <- !is.na(sources$fecha_publicacion)
  labels[repeated & has_date] <- paste0(
    labels[repeated & has_date],
    " (", format(sources$fecha_publicacion[repeated & has_date], "%d/%m/%Y"), ")"
  )
  labels[repeated & !has_date] <- paste0(
    labels[repeated & !has_date],
    " (", occurrence[repeated & !has_date], ")"
  )

  nodes <- list()
  for (i in seq_len(nrow(sources))) {
    separator <- if (i > 1L) {
      htmltools::tags$span(
        class = "rigi-project-card__source-separator",
        `aria-hidden` = "true",
        "·"
      )
    } else {
      NULL
    }

    url <- safe_http_url(sources$url[[i]])
    title <- empty_to_na(as.character(sources$titulo_fuente[[i]]))
    title <- if (length(title) > 0 && !is.na(title[[1]])) title[[1]] else NULL

    source_node <- if (length(url) > 0 && !is.na(url[[1]])) {
      htmltools::tags$a(
        class = "rigi-project-card__source-link",
        href = url[[1]],
        target = "_blank",
        rel = "noopener noreferrer",
        title = title,
        labels[[i]]
      )
    } else {
      htmltools::tags$span(class = "rigi-project-card__source-text", labels[[i]])
    }

    nodes[[length(nodes) + 1L]] <- htmltools::tags$span(
      class = "rigi-project-card__source-item",
      separator,
      source_node
    )
  }

  htmltools::tagList(nodes)
}

render_project_sources_html <- function(sources) {
  rendered <- render_project_sources(sources)
  if (is.null(rendered)) return("")
  as.character(htmltools::tags$span(class = "rigi-project-card__source-list", rendered))
}

rigi_filter_values <- function(x, split = FALSE) {
  values <- as.character(x)
  values <- values[!is.na(values) & trimws(values) != ""]
  if (split && length(values) > 0) {
    values <- unlist(strsplit(values, ";", fixed = TRUE), use.names = FALSE)
  }
  sort(unique(trimws(values)), method = "radix")
}

rigi_filter_select <- function(id, label, values, data_filter) {
  options <- c(
    list(htmltools::tags$option(value = "", paste("Todos", tolower(label)))),
    lapply(values, function(value) htmltools::tags$option(value = value, value))
  )

  htmltools::tags$label(
    class = "rigi-card-filter",
    `for` = id,
    htmltools::tags$span(label),
    htmltools::tags$select(
      id = id,
      `data-filter` = data_filter,
      options
    )
  )
}

rigi_classification_filter_select <- function(id) {
  htmltools::tags$label(
    class = "rigi-card-filter",
    `for` = id,
    htmltools::tags$span("Clasificación del proyecto"),
    htmltools::tags$select(
      id = id,
      `data-filter` = "peelp",
      htmltools::tags$option(value = "", "Todos los proyectos"),
      htmltools::tags$option(value = "Sí", "Solo proyectos PEELP"),
      htmltools::tags$option(value = "No", "Solo proyectos no PEELP")
    )
  )
}

make_rigi_project_card <- function(row, table_type, index) {
  value <- function(column) {
    if (!column %in% names(row)) return(NA)
    row[[column]][[1]]
  }

  approved <- isTRUE(value("aprobado"))
  peelp_raw <- value("proyecto_exportacion_estrategia_largo_plazo_si")
  peelp <- isTRUE(peelp_raw)
  state_class <- if (approved) {
    "rigi-badge--approved"
  } else if (identical(value("estado_simplificado"), "Pendiente de aprobación")) {
    "rigi-badge--pending"
  } else {
    "rigi-badge--muted"
  }

  key_date <- switch(
    table_type,
    aprobados = value("fecha_adhesion_rigi"),
    pendientes = value("fecha_presentacion"),
    total = dplyr::coalesce(
      as.Date(value("fecha_adhesion_rigi")),
      as.Date(value("fecha_presentacion"))
    )
  )
  key_date_label <- switch(
    table_type,
    aprobados = "Adhesión",
    pendientes = "Presentación",
    total = "Fecha principal"
  )

  project_name <- rigi_card_value(value("proyecto"))
  state <- rigi_card_value(value("estado"))
  sector <- rigi_card_value(value("sector"))
  province <- rigi_card_value(value("provincia_original"))
  company <- rigi_card_value(value("empresa"))
  holder <- rigi_card_value(value("titular_proyecto"))
  project_sources <- value("fuentes_lista")
  rendered_sources <- render_project_sources(
    project_sources,
    fallback = value("fuentes_original")
  )
  source_search_text <- if (is.data.frame(project_sources) && nrow(project_sources) > 0) {
    paste(project_sources$fuente, collapse = " ")
  } else {
    rigi_card_value(value("fuentes_original"))
  }
  peelp_label <- if (is.na(peelp_raw)) {
    "s/d"
  } else if (peelp) {
    "Sí"
  } else {
    "No"
  }
  amount_value <- suppressWarnings(as.numeric(value("monto_usd_mill")))
  amount_sort <- if (is.na(amount_value)) -1 else amount_value
  date_sort <- suppressWarnings(as.numeric(as.Date(key_date)))
  if (is.na(date_sort)) date_sort <- -1

  search_text <- paste(
    project_name,
    state,
    sector,
    rigi_card_value(value("subsector")),
    province,
    rigi_card_value(value("localidad_region")),
    company,
    holder,
    rigi_card_value(value("norma_aprobacion")),
    rigi_card_value(value("descripcion_del_proyecto")),
    source_search_text,
    collapse = " "
  )

  detail_fields <- htmltools::tags$dl(
    class = "rigi-project-card__details-grid",
    rigi_card_field("Empresa", company),
    rigi_card_field("Titular / VPU", holder),
    rigi_card_field("Subsector", value("subsector")),
    rigi_card_field("Localidad / región", value("localidad_region")),
    rigi_card_field(
      "Activos computables",
      rigi_card_amount(value("activos_computables_usd_mill"))
    ),
    rigi_card_field(
      "Empleos directos e indirectos",
      rigi_card_integer(value("empleos_directos_indirectos"))
    ),
    rigi_card_field("Fecha de presentación", rigi_card_date(value("fecha_presentacion"))),
    rigi_card_field("Fecha de adhesión", rigi_card_date(value("fecha_adhesion_rigi"))),
    rigi_card_field("Fecha de aprobación", rigi_card_date(value("fecha_aprobacion"))),
    rigi_card_field("Norma de aprobación", value("norma_aprobacion"))
  )

  htmltools::tags$article(
    class = "rigi-project-card",
    `data-project-card` = "true",
    `data-original-order` = index,
    `data-search` = search_text,
    `data-status` = state,
    `data-sector` = sector,
    `data-province` = gsub("\\s*;\\s*", "|", province),
    `data-peelp` = peelp_label,
    `data-amount` = amount_sort,
    `data-date` = date_sort,
    `data-name` = project_name,
    htmltools::tags$div(
      class = "rigi-project-card__header",
      htmltools::tags$div(
        class = "rigi-project-card__title-block",
        htmltools::tags$div(
          class = "rigi-project-card__badges",
          htmltools::tags$span(class = paste("rigi-badge", state_class), state),
          if (peelp) {
            htmltools::tags$span(class = "rigi-badge rigi-badge--peelp", "PEELP")
          }
        ),
        htmltools::tags$h3(project_name),
        htmltools::tags$p(class = "rigi-project-card__holder", holder)
      ),
      htmltools::tags$div(
        class = "rigi-project-card__amount",
        htmltools::tags$span("Monto informado"),
        htmltools::tags$strong(rigi_card_amount(value("monto_usd_mill")))
      )
    ),
    htmltools::tags$dl(
      class = "rigi-project-card__summary-grid",
      rigi_card_field("Sector", sector),
      rigi_card_field("Provincia", province),
      rigi_card_field(key_date_label, rigi_card_date(key_date))
    ),
    htmltools::tags$details(
      class = "rigi-project-card__details",
      htmltools::tags$summary(
        htmltools::tags$span("Ver detalles"),
        htmltools::tags$span(
          class = "rigi-project-card__chevron",
          `aria-hidden` = "true"
        )
      ),
      htmltools::tags$div(
        class = "rigi-project-card__detail-panel",
        detail_fields,
        htmltools::tags$div(
          class = "rigi-project-card__description",
          htmltools::tags$h4("Descripción del proyecto"),
          htmltools::tags$p(rigi_card_value(value("descripcion_del_proyecto")))
        ),
        htmltools::tags$div(
          class = "rigi-project-card__sources",
          rigi_card_link(value("link_norma"), "Ver norma de aprobación"),
          if (!is.null(rendered_sources)) {
            htmltools::tags$div(
              class = "rigi-project-card__source-group",
              htmltools::tags$strong("Fuentes"),
              htmltools::tags$span(
                class = "rigi-project-card__source-list",
                rendered_sources
              )
            )
          }
        )
      )
    )
  )
}

make_rigi_project_cards <- function(
  data,
  table_type = c("aprobados", "pendientes", "total"),
  caption = NULL,
  widget_key = NULL,
  show_classification_filter = NULL
) {
  table_type <- match.arg(table_type)
  if (is.null(widget_key)) widget_key <- table_type
  widget_key <- tolower(gsub("[^A-Za-z0-9_-]+", "-", as.character(widget_key[[1]])))
  widget_key <- gsub("(^-+|-+$)", "", widget_key)
  if (!nzchar(widget_key)) stop("widget_key debe contener al menos un carácter alfanumérico.")

  if (is.null(show_classification_filter)) {
    show_classification_filter <- table_type %in% c("aprobados", "total")
  }

  widget_id <- paste0("rigi-project-cards-", widget_key)

  status_values <- rigi_filter_values(data$estado)
  sector_values <- rigi_filter_values(data$sector)
  province_values <- rigi_filter_values(data$provincia_original, split = TRUE)

  filters <- switch(
    table_type,
    aprobados = list(
      rigi_filter_select(
        paste0(widget_id, "-sector"),
        "Sector",
        sector_values,
        "sector"
      ),
      rigi_filter_select(
        paste0(widget_id, "-province"),
        "Provincia",
        province_values,
        "province"
      ),
      if (show_classification_filter) {
        rigi_classification_filter_select(paste0(widget_id, "-classification"))
      }
    ),
    pendientes = list(
      rigi_filter_select(
        paste0(widget_id, "-status"),
        "Estado",
        status_values,
        "status"
      ),
      rigi_filter_select(
        paste0(widget_id, "-sector"),
        "Sector",
        sector_values,
        "sector"
      ),
      rigi_filter_select(
        paste0(widget_id, "-province"),
        "Provincia",
        province_values,
        "province"
      )
    ),
    total = list(
      rigi_filter_select(
        paste0(widget_id, "-status"),
        "Estado",
        status_values,
        "status"
      ),
      rigi_filter_select(
        paste0(widget_id, "-sector"),
        "Sector",
        sector_values,
        "sector"
      ),
      rigi_filter_select(
        paste0(widget_id, "-province"),
        "Provincia",
        province_values,
        "province"
      ),
      if (show_classification_filter) {
        rigi_classification_filter_select(paste0(widget_id, "-classification"))
      }
    )
  )
  filters <- Filter(Negate(is.null), filters)

  cards <- lapply(
    seq_len(nrow(data)),
    function(index) make_rigi_project_card(
      data[index, , drop = FALSE],
      table_type,
      index
    )
  )

  script <- htmltools::tags$script(htmltools::HTML(sprintf(
    "(function() {
      var root = document.getElementById('%s');
      if (!root) return;
      var grid = root.querySelector('[data-card-grid]');
      var cards = Array.prototype.slice.call(root.querySelectorAll('[data-project-card]'));
      var search = root.querySelector('[data-card-search]');
      var filters = Array.prototype.slice.call(root.querySelectorAll('[data-filter]'));
      var sort = root.querySelector('[data-card-sort]');
      var clear = root.querySelector('[data-card-clear]');
      var count = root.querySelector('[data-card-count]');
      var empty = root.querySelector('[data-card-empty]');

      function normalized(value) {
        return (value || '').toLocaleLowerCase('es').normalize('NFD').replace(/[\\u0300-\\u036f]/g, '');
      }

      function matches(card) {
        var query = normalized(search.value);
        if (query && normalized(card.dataset.search).indexOf(query) === -1) return false;

        for (var i = 0; i < filters.length; i += 1) {
          var select = filters[i];
          var selected = select.value;
          if (!selected) continue;
          var key = select.dataset.filter;
          var cardValue = card.dataset[key] || '';
          if (key === 'province') {
            var provinces = cardValue.split('|').map(function(value) { return value.trim(); });
            if (provinces.indexOf(selected) === -1) return false;
          } else if (cardValue !== selected) {
            return false;
          }
        }
        return true;
      }

      function sortCards(visibleCards) {
        var mode = sort.value;
        visibleCards.sort(function(a, b) {
          if (mode === 'amount-desc') return Number(b.dataset.amount) - Number(a.dataset.amount);
          if (mode === 'amount-asc') return Number(a.dataset.amount) - Number(b.dataset.amount);
          if (mode === 'date-desc') return Number(b.dataset.date) - Number(a.dataset.date);
          if (mode === 'date-asc') return Number(a.dataset.date) - Number(b.dataset.date);
          if (mode === 'name-asc') return a.dataset.name.localeCompare(b.dataset.name, 'es');
          return Number(a.dataset.originalOrder) - Number(b.dataset.originalOrder);
        });
        visibleCards.forEach(function(card) { grid.appendChild(card); });
      }

      function update() {
        var visibleCards = [];
        cards.forEach(function(card) {
          var show = matches(card);
          card.hidden = !show;
          if (show) visibleCards.push(card);
        });
        sortCards(visibleCards);
        count.textContent = visibleCards.length + (visibleCards.length === 1 ? ' proyecto' : ' proyectos');
        empty.hidden = visibleCards.length !== 0;
      }

      search.addEventListener('input', update);
      filters.forEach(function(select) { select.addEventListener('change', update); });
      sort.addEventListener('change', update);
      clear.addEventListener('click', function() {
        search.value = '';
        filters.forEach(function(select) { select.value = ''; });
        sort.value = 'amount-desc';
        update();
        search.focus();
      });
      update();
    })();",
    widget_id
  )))

  htmltools::tags$section(
    id = widget_id,
    class = "rigi-project-cards",
    `aria-label` = caption,
    `data-filter-count` = length(filters),
    htmltools::tags$div(
      class = "rigi-project-cards__toolbar",
      htmltools::tags$label(
        class = "rigi-card-search",
        `for` = paste0(widget_id, "-search"),
        htmltools::tags$span("Buscar"),
        htmltools::tags$input(
          id = paste0(widget_id, "-search"),
          type = "search",
          placeholder = "Proyecto, empresa, titular, sector…",
          `data-card-search` = "true"
        )
      ),
      filters,
      htmltools::tags$label(
        class = "rigi-card-filter rigi-card-sort",
        `for` = paste0(widget_id, "-sort"),
        htmltools::tags$span("Ordenar"),
        htmltools::tags$select(
          id = paste0(widget_id, "-sort"),
          `data-card-sort` = "true",
          htmltools::tags$option(value = "amount-desc", "Monto: mayor a menor"),
          htmltools::tags$option(value = "amount-asc", "Monto: menor a mayor"),
          htmltools::tags$option(value = "date-desc", "Fecha: más reciente"),
          htmltools::tags$option(value = "date-asc", "Fecha: más antigua"),
          htmltools::tags$option(value = "name-asc", "Proyecto: A–Z")
        )
      ),
      htmltools::tags$button(
        class = "rigi-card-clear",
        type = "button",
        `data-card-clear` = "true",
        "Limpiar filtros"
      )
    ),
    htmltools::tags$div(
      class = "rigi-project-cards__status",
      htmltools::tags$strong(`data-card-count` = "true"),
      htmltools::tags$span(" · seleccioná una ficha para ampliar la información")
    ),
    htmltools::tags$div(
      class = "rigi-project-cards__grid",
      `data-card-grid` = "true",
      cards
    ),
    htmltools::tags$div(
      class = "rigi-project-cards__empty",
      `data-card-empty` = "true",
      hidden = TRUE,
      htmltools::tags$strong("No se encontraron proyectos"),
      htmltools::tags$p("Probá con otros términos o limpiá los filtros.")
    ),
    script
  )
}
