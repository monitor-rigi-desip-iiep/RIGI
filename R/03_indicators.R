# Indicadores, tablas auxiliares y resumen automático -------------------------

sum_or_na <- function(x) {
  if (length(x) == 0 || all(is.na(x))) return(NA_real_)
  sum(x, na.rm = TRUE)
}

mean_or_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_real_)
  mean(x)
}

median_or_na <- function(x) {
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_real_)
  median(x)
}

ratio_or_na <- function(numerator, denominator) {
  if (
    length(numerator) == 0 ||
    length(denominator) == 0 ||
    is.na(numerator) ||
    is.na(denominator) ||
    denominator == 0
  ) {
    return(NA_real_)
  }

  numerator / denominator
}

fmt_number <- function(x, accuracy = 1) {
  if (length(x) == 0) return(character(0))
  out <- scales::number(x, accuracy = accuracy, big.mark = ".", decimal.mark = ",")
  out[is.na(x) | is.nan(x)] <- "s/d"
  out
}

fmt_integer <- function(x) {
  fmt_number(x, accuracy = 1)
}

fmt_currency_mill <- function(x, accuracy = 1) {
  if (length(x) == 0) return(character(0))
  out <- paste0(fmt_number(x, accuracy = accuracy), " millones de USD")
  out[is.na(x) | is.nan(x)] <- "s/d"
  out
}

fmt_currency_short <- function(x, accuracy = 1) {
  if (length(x) == 0) return(character(0))
  out <- paste0("USD ", fmt_number(x, accuracy = accuracy), " M")
  out[is.na(x) | is.nan(x)] <- "No informado"
  out
}

fmt_pct <- function(x, accuracy = 0.1) {
  if (length(x) == 0) return(character(0))
  out <- scales::percent(x, accuracy = accuracy, decimal.mark = ",")
  out[is.na(x) | is.nan(x)] <- "s/d"
  out
}

fmt_date <- function(x) {
  if (length(x) == 0) return(character(0))
  x_date <- as.Date(x)
  out <- format(x_date, "%d/%m/%Y")
  out[is.na(x_date)] <- "s/d"
  out
}

fmt_datetime <- function(x) {
  if (length(x) == 0) return(character(0))
  x_posix <- as.POSIXct(x)
  out <- format(x_posix, "%d/%m/%Y %H:%M")
  out[is.na(x_posix)] <- "s/d"
  out
}

first_or_sd <- function(x) {
  if (length(x) == 0 || all(is.na(x))) return("s/d")
  x[which(!is.na(x))[1]]
}

make_indicators <- function(data, data_prov, file_update_time) {
  aprobados <- data |> dplyr::filter(aprobado)
  pendientes <- data |> dplyr::filter(pendiente_aprobacion)
  rechazados <- data |> dplyr::filter(estado_simplificado == "Rechazado")
  aprobados_exportacion_lp <- aprobados |> dplyr::filter(proyecto_exportacion_estrategia_largo_plazo_si)
  aprobados_prov <- data_prov |> dplyr::filter(aprobado)
  pendientes_prov <- data_prov |> dplyr::filter(pendiente_aprobacion)

  sector_top_aprobado <- aprobados |>
    dplyr::group_by(sector_simplificado) |>
    dplyr::summarise(monto = sum_or_na(monto_usd_mill), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(monto)) |>
    dplyr::slice_head(n = 1) |>
    dplyr::pull(sector_simplificado) |>
    first_or_sd()

  provincia_top_aprobada <- aprobados_prov |>
    dplyr::group_by(provincia_simplificada) |>
    dplyr::summarise(monto = sum_or_na(monto_usd_mill_asignado_prop), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(monto)) |>
    dplyr::slice_head(n = 1) |>
    dplyr::pull(provincia_simplificada) |>
    first_or_sd()

  empleo_top_proyecto <- aprobados |>
    dplyr::filter(!is.na(empleos_directos_indirectos)) |>
    dplyr::arrange(dplyr::desc(empleos_directos_indirectos)) |>
    dplyr::slice_head(n = 1) |>
    dplyr::pull(proyecto) |>
    first_or_sd()

  empleo_top_sector <- aprobados |>
    dplyr::group_by(sector_simplificado) |>
    dplyr::summarise(empleos = sum_or_na(empleos_directos_indirectos), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(empleos)) |>
    dplyr::slice_head(n = 1) |>
    dplyr::pull(sector_simplificado) |>
    first_or_sd()

  empleo_top_provincia <- aprobados_prov |>
    dplyr::group_by(provincia_simplificada) |>
    dplyr::summarise(empleos = sum_or_na(empleos_directos_indirectos_asignado_prop), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(empleos)) |>
    dplyr::slice_head(n = 1) |>
    dplyr::pull(provincia_simplificada) |>
    first_or_sd()

  sectores_aprobados_concentracion <- aprobados |>
    dplyr::filter(!is.na(monto_usd_mill)) |>
    dplyr::group_by(sector_simplificado) |>
    dplyr::summarise(monto = sum(monto_usd_mill, na.rm = TRUE), .groups = "drop") |>
    dplyr::arrange(dplyr::desc(monto))

  sectores_top_dos <- sectores_aprobados_concentracion |>
    dplyr::slice_head(n = 2)

  nombres_sectores_top_dos <- if (nrow(sectores_top_dos) > 0) {
    paste(sectores_top_dos$sector_simplificado, collapse = " y ")
  } else {
    "No informado"
  }

  participacion_sectores_top_dos <- ratio_or_na(
    sum_or_na(sectores_top_dos$monto),
    sum_or_na(aprobados$monto_usd_mill)
  )

  proyectos_aprobados_concentracion <- aprobados |>
    dplyr::filter(!is.na(monto_usd_mill), monto_usd_mill >= 0) |>
    dplyr::arrange(dplyr::desc(monto_usd_mill)) |>
    dplyr::mutate(
      participacion = chart_share(monto_usd_mill),
      participacion_acumulada = cumsum(dplyr::coalesce(participacion, 0))
    )

  participacion_top_cinco <- proyectos_aprobados_concentracion |>
    dplyr::slice_head(n = 5) |>
    dplyr::summarise(valor = sum(participacion, na.rm = TRUE)) |>
    dplyr::pull(valor)

  proyectos_hasta_75 <- if (nrow(proyectos_aprobados_concentracion) == 0) {
    NA_integer_
  } else {
    which(proyectos_aprobados_concentracion$participacion_acumulada >= 0.75)[1]
  }

  participacion_hasta_75 <- if (
    is.na(proyectos_hasta_75) ||
    nrow(proyectos_aprobados_concentracion) == 0
  ) {
    NA_real_
  } else {
    proyectos_aprobados_concentracion$participacion_acumulada[[proyectos_hasta_75]]
  }

  tibble::tibble(
    fecha_actualizacion = Sys.Date(),
    fecha_actualizacion_fmt = fmt_date(Sys.Date()),
    fecha_modificacion_archivo = file_update_time,
    fecha_modificacion_archivo_fmt = fmt_datetime(file_update_time),

    n_total = nrow(data),
    monto_total = sum_or_na(data$monto_usd_mill),
    activos_total = sum_or_na(data$activos_computables_usd_mill),

    n_aprobados = nrow(aprobados),
    monto_aprobado = sum_or_na(aprobados$monto_usd_mill),
    activos_aprobados = sum_or_na(aprobados$activos_computables_usd_mill),
    monto_promedio_aprobado = mean_or_na(aprobados$monto_usd_mill),
    monto_mediano_aprobado = median_or_na(aprobados$monto_usd_mill),
    empleos_aprobados = sum_or_na(aprobados$empleos_directos_indirectos),
    n_aprobados_con_empleo = sum(!is.na(aprobados$empleos_directos_indirectos)),
    empleos_promedio_aprobados = mean_or_na(aprobados$empleos_directos_indirectos),
    empleos_mediana_aprobados = median_or_na(aprobados$empleos_directos_indirectos),
    n_aprobados_exportacion_largo_plazo = nrow(aprobados_exportacion_lp),
    monto_aprobados_exportacion_largo_plazo = sum_or_na(aprobados_exportacion_lp$monto_usd_mill),
    activos_aprobados_exportacion_largo_plazo = sum_or_na(aprobados_exportacion_lp$activos_computables_usd_mill),
    empleos_aprobados_exportacion_largo_plazo = sum_or_na(aprobados_exportacion_lp$empleos_directos_indirectos),
    participacion_aprobados_exportacion_largo_plazo = ratio_or_na(
      n_aprobados_exportacion_largo_plazo,
      n_aprobados
    ),
    participacion_monto_aprobados_exportacion_largo_plazo = ratio_or_na(
      monto_aprobados_exportacion_largo_plazo,
      monto_aprobado
    ),
    ratio_monto_pendiente_aprobado = ratio_or_na(
      sum_or_na(pendientes$monto_usd_mill),
      sum_or_na(aprobados$monto_usd_mill)
    ),
    sectores_top_dos_aprobados = nombres_sectores_top_dos,
    participacion_sectores_top_dos_aprobados = participacion_sectores_top_dos,
    participacion_top_cinco_aprobados = participacion_top_cinco,
    n_proyectos_hasta_75_aprobados = proyectos_hasta_75,
    participacion_proyectos_hasta_75_aprobados = participacion_hasta_75,
    sector_top_aprobado = sector_top_aprobado,
    provincia_top_aprobada = provincia_top_aprobada,
    empleo_top_proyecto = empleo_top_proyecto,
    empleo_top_sector = empleo_top_sector,
    empleo_top_provincia = empleo_top_provincia,

    n_pendientes = nrow(pendientes),
    monto_pendiente = sum_or_na(pendientes$monto_usd_mill),
    activos_pendientes = sum_or_na(pendientes$activos_computables_usd_mill),
    monto_promedio_pendiente = mean_or_na(pendientes$monto_usd_mill),
    monto_mediano_pendiente = median_or_na(pendientes$monto_usd_mill),

    n_rechazados = nrow(rechazados),
    monto_rechazado = sum_or_na(rechazados$monto_usd_mill),

    participacion_monto_aprobado = ratio_or_na(monto_aprobado, monto_total),
    participacion_proyectos_aprobados = ratio_or_na(n_aprobados, n_total)
  ) |>
    dplyr::slice(1)
}

make_tables <- function(data, data_prov) {
  aprobados <- data |> dplyr::filter(aprobado)
  pendientes <- data |> dplyr::filter(pendiente_aprobacion)
  aprobados_exportacion_lp <- aprobados |> dplyr::filter(proyecto_exportacion_estrategia_largo_plazo_si)
  aprobados_prov <- data_prov |> dplyr::filter(aprobado)
  pendientes_prov <- data_prov |> dplyr::filter(pendiente_aprobacion)

  sector_summary <- function(df) {
    df |>
      dplyr::group_by(sector_simplificado) |>
      dplyr::summarise(
        n_proyectos = dplyr::n(),
        monto_usd_mill = sum_or_na(monto_usd_mill),
        activos_computables_usd_mill = sum_or_na(activos_computables_usd_mill),
        empleos_directos_indirectos = sum_or_na(empleos_directos_indirectos),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(monto_usd_mill))
  }

  provincia_summary <- function(df) {
    df |>
      dplyr::group_by(provincia_simplificada) |>
      dplyr::summarise(
        n_incidencias_provinciales = dplyr::n_distinct(row_id),
        monto_usd_mill = sum_or_na(monto_usd_mill_asignado_prop),
        activos_computables_usd_mill = sum_or_na(activos_computables_usd_mill_asignado_prop),
        empleos_directos_indirectos = sum_or_na(empleos_directos_indirectos_asignado_prop),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(monto_usd_mill))
  }

  list(
    estado_tbl = data |>
      dplyr::group_by(estado_simplificado) |>
      dplyr::summarise(
        n_proyectos = dplyr::n(),
        monto_usd_mill = sum_or_na(monto_usd_mill),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(n_proyectos)),

    sector_tbl_aprobados = sector_summary(aprobados),
    sector_tbl_pendientes = sector_summary(pendientes),
    provincia_tbl_aprobados = provincia_summary(aprobados_prov),
    provincia_tbl_pendientes = provincia_summary(pendientes_prov),

    aprobados_exportacion_largo_plazo = aprobados_exportacion_lp |>
      dplyr::arrange(dplyr::desc(monto_usd_mill)),

    top_projects_aprobados = aprobados |>
      dplyr::arrange(dplyr::desc(monto_usd_mill)) |>
      dplyr::slice_head(n = 10),

    projects_pareto_aprobados = aprobados |>
      dplyr::filter(!is.na(monto_usd_mill), monto_usd_mill >= 0) |>
      dplyr::arrange(dplyr::desc(monto_usd_mill), proyecto) |>
      dplyr::mutate(
        ranking = dplyr::row_number(),
        participacion = chart_share(monto_usd_mill),
        participacion_acumulada = cumsum(dplyr::coalesce(participacion, 0))
      ),

    top_projects_pendientes = pendientes |>
      dplyr::arrange(dplyr::desc(monto_usd_mill)) |>
      dplyr::slice_head(n = 10),

    top_empleos_aprobados = aprobados |>
      dplyr::filter(!is.na(empleos_directos_indirectos)) |>
      dplyr::arrange(dplyr::desc(empleos_directos_indirectos)) |>
      dplyr::slice_head(n = 10),

    empleo_sector_aprobados = aprobados |>
      dplyr::group_by(sector_simplificado) |>
      dplyr::summarise(
        empleos_directos_indirectos = sum_or_na(empleos_directos_indirectos),
        n_proyectos = dplyr::n(),
        .groups = "drop"
      ) |>
      dplyr::filter(!is.na(empleos_directos_indirectos)) |>
      dplyr::arrange(dplyr::desc(empleos_directos_indirectos)),

    empleo_provincia_aprobados = aprobados_prov |>
      dplyr::group_by(provincia_simplificada) |>
      dplyr::summarise(
        empleos_directos_indirectos = sum_or_na(empleos_directos_indirectos_asignado_prop),
        n_incidencias_provinciales = dplyr::n_distinct(row_id),
        .groups = "drop"
      ) |>
      dplyr::filter(!is.na(empleos_directos_indirectos)) |>
      dplyr::arrange(dplyr::desc(empleos_directos_indirectos)),

    timeline_aprobados_tbl = aprobados |>
      dplyr::arrange(is.na(fecha_adhesion_rigi), fecha_adhesion_rigi, proyecto),

    timeline_pendientes_tbl = pendientes |>
      dplyr::filter(!is.na(fecha_presentacion)) |>
      dplyr::arrange(fecha_presentacion),

    base_aprobados = aprobados,
    base_pendientes = pendientes,
    base_total = data
  )
}

make_summary_text <- function(indicadores, tablas) {
  top_projects_text <- tablas$top_projects_aprobados |>
    dplyr::slice_head(n = 3) |>
    dplyr::mutate(txt = paste0(proyecto, " (", fmt_currency_mill(monto_usd_mill, accuracy = 1), ")")) |>
    dplyr::pull(txt) |>
    paste(collapse = "; ")

  if (identical(top_projects_text, "")) top_projects_text <- "s/d"

  empleo_text <- if (is.na(indicadores$empleos_aprobados)) {
    "No hay datos de empleo informados para los proyectos aprobados o todos los valores disponibles están vacíos."
  } else {
    glue::glue(
      "Los proyectos aprobados informan {fmt_integer(indicadores$empleos_aprobados)} empleos directos e indirectos. El sector con mayor empleo informado entre aprobados es {indicadores$empleo_top_sector}, y la provincia con mayor empleo informado —considerando la asignación en partes iguales en proyectos multiprovinciales— es {indicadores$empleo_top_provincia}."
    )
  }

  glue::glue(
    "El Monitor releva {fmt_integer(indicadores$n_total)} proyectos: {fmt_integer(indicadores$n_aprobados)} aprobados, {fmt_integer(indicadores$n_pendientes)} en evaluación y {fmt_integer(indicadores$n_rechazados)} proyectos rechazados. El monto informado correspondiente a los proyectos aprobados asciende a {fmt_currency_mill(indicadores$monto_aprobado, accuracy = 1)}, equivalente al {fmt_pct(indicadores$participacion_monto_aprobado)} del monto total informado en la base. Entre los proyectos aprobados, el sector con mayor monto acumulado es {indicadores$sector_top_aprobado}, y la provincia con mayor monto —considerando la asignación en partes iguales en proyectos multiprovinciales— es {indicadores$provincia_top_aprobada}. Los principales proyectos aprobados por monto son: {top_projects_text}. {empleo_text} Última actualización: {indicadores$fecha_actualizacion_fmt}."
  )
}
