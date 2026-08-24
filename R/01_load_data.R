# Lectura de datos ------------------------------------------------------------

excel_path <- "data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
sheet_proyectos <- "Proyectos"
sheet_diccionario <- "Diccionario"
sheet_variable_anterior <- "Variable_Anterior"

# Codificación de texto ------------------------------------------------------
#
# readxl entrega contenido Unicode, pero en algunos entornos (en particular
# macOS) una cadena no ASCII puede conservar bytes UTF-8 con marca de
# codificación "unknown". Ese estado hace fallar a order/sort con el método
# radix. La conversión se resuelve una sola vez, de forma explícita y sin
# sustituir silenciosamente bytes inválidos.
rigi_as_utf8 <- function(x, context = "texto") {
  x <- as.character(x)
  if (length(x) == 0L) return(x)

  out <- rep(NA_character_, length(x))
  present <- !is.na(x)
  if (!any(present)) return(out)

  source_values <- x[present]
  source_encoding <- Encoding(source_values)
  converted <- rep(NA_character_, length(source_values))

  latin1 <- source_encoding == "latin1"
  if (any(latin1)) {
    converted[latin1] <- iconv(
      source_values[latin1],
      from = "latin1",
      to = "UTF-8",
      sub = NA_character_,
      mark = TRUE
    )
  }

  utf8_bytes <- !latin1
  if (any(utf8_bytes)) {
    # Las cadenas UTF-8, bytes y unknown se validan por sus bytes. No se usa
    # la locale del sistema para evitar resultados distintos entre macOS y CI.
    converted[utf8_bytes] <- iconv(
      source_values[utf8_bytes],
      from = "UTF-8",
      to = "UTF-8",
      sub = NA_character_,
      mark = TRUE
    )
  }

  invalid <- is.na(converted)
  if (any(invalid)) {
    original_positions <- which(present)[which(invalid)]
    preview <- paste(utils::head(original_positions, 8L), collapse = ", ")
    if (length(original_positions) > 8L) preview <- paste0(preview, ", ...")
    stop(
      "Se detectó texto con codificación inválida en ", context,
      " (posiciones: ", preview, "). Se esperaba UTF-8 o Latin-1 declarado.",
      call. = FALSE
    )
  }

  out[present] <- converted
  out
}

rigi_utf8_data_frame <- function(data, context = "tabla") {
  names(data) <- rigi_as_utf8(names(data), paste0(context, " / encabezados"))
  character_columns <- names(data)[vapply(data, is.character, logical(1))]

  for (column in character_columns) {
    data[[column]] <- rigi_as_utf8(
      data[[column]],
      paste0(context, " / ", column)
    )
  }
  data
}

rigi_sort_unique_text <- function(x, context = "valores de texto") {
  values <- rigi_as_utf8(x, context)
  values <- values[!is.na(values)]
  sort(unique(values), method = "radix")
}

required_project_variables <- c(
  "vpu", "descripcion_proyecto", "peelp", "id_proyecto", "empresa",
  "titular_proyecto", "cuit", "sector", "subsector",
  "actividad_subsector_resolucion_mecon", "provincia", "localidad_region",
  "inversion_total_mill_usd", "inversion_total_resolucion_mill_usd",
  "inversion_activos_computables_mill_usd",
  "inversion_activos_computables_comprometida_anio_1_mill_usd",
  "inversion_activos_computables_comprometida_anio_2_mill_usd",
  "inversion_activos_computables_comprometida_2_anios_mill_usd",
  "estado_administrativo", "empleos_directos_indirectos_informados",
  "fecha_limite_inversion_minima_activos_computables", "fecha_presentacion",
  "fecha_adhesion_rigi", "fecha_publicacion_bo", "norma_aprobacion",
  "clasificacion_preexistencia_boletin_oficial",
  "justificacion_preexistencia_boletin_oficial", "link_norma", "fuentes",
  "links_fuentes"
)

validate_workbook_structure <- function(path = excel_path) {
  if (!file.exists(path)) {
    stop("No se encontró el archivo Excel en: ", path, call. = FALSE)
  }

  sheets <- readxl::excel_sheets(path)
  required_sheets <- c(sheet_proyectos, sheet_diccionario, sheet_variable_anterior)
  missing_sheets <- setdiff(required_sheets, sheets)
  if (length(missing_sheets) > 0) {
    stop(
      "El XLSX no contiene las hojas obligatorias: ",
      paste(missing_sheets, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

validate_project_schema <- function(data) {
  clean_names <- janitor::make_clean_names(names(data))
  duplicated_names <- unique(clean_names[duplicated(clean_names)])
  missing_variables <- setdiff(required_project_variables, clean_names)
  unexpected_variables <- setdiff(clean_names, required_project_variables)

  if (length(duplicated_names) > 0) {
    stop(
      "La hoja Proyectos contiene encabezados duplicados luego de normalizarlos: ",
      paste(duplicated_names, collapse = ", "),
      call. = FALSE
    )
  }
  if (length(missing_variables) > 0) {
    stop(
      "La hoja Proyectos no coincide con el esquema canónico. Faltan: ",
      paste(missing_variables, collapse = ", "),
      call. = FALSE
    )
  }
  if (length(unexpected_variables) > 0) {
    stop(
      "La hoja Proyectos contiene variables no previstas por el esquema canónico: ",
      paste(unexpected_variables, collapse = ", "),
      call. = FALSE
    )
  }

  ids <- as.character(data[[which(clean_names == "id_proyecto")]])
  duplicated_ids <- unique(ids[!is.na(ids) & ids != "" & duplicated(ids)])
  if (length(duplicated_ids) > 0) {
    stop(
      "La hoja Proyectos contiene id_proyecto duplicados: ",
      paste(duplicated_ids, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(TRUE)
}

load_proyectos <- function(path = excel_path, sheet = sheet_proyectos) {
  validate_workbook_structure(path)

  data <- readxl::read_excel(
    path = path,
    sheet = sheet,
    guess_max = 10000
  ) |>
    rigi_utf8_data_frame(context = paste0("XLSX / ", sheet))
  validate_project_schema(data)
  data
}

load_diccionario <- function(path = excel_path, sheet = sheet_diccionario) {
  validate_workbook_structure(path)
  dictionary <- readxl::read_excel(path = path, sheet = sheet, guess_max = 1000) |>
    rigi_utf8_data_frame(context = paste0("XLSX / ", sheet)) |>
    janitor::clean_names() |>
    dplyr::filter(!is.na(variable), trimws(as.character(variable)) != "") |>
    dplyr::mutate(variable = janitor::make_clean_names(variable))

  required_columns <- c("orden", "variable", "nombre_visible", "tipo", "unidad", "descripcion_breve")
  missing_columns <- setdiff(required_columns, names(dictionary))
  if (length(missing_columns) > 0) {
    stop(
      "La hoja Diccionario no contiene las columnas obligatorias: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(dictionary$variable)) {
    stop("La hoja Diccionario contiene variables duplicadas.", call. = FALSE)
  }
  missing_definitions <- setdiff(required_project_variables, dictionary$variable)
  if (length(missing_definitions) > 0) {
    stop(
      "La hoja Diccionario no define: ",
      paste(missing_definitions, collapse = ", "),
      call. = FALSE
    )
  }
  dictionary |>
    dplyr::arrange(orden)
}

load_variable_mapping <- function(path = excel_path, sheet = sheet_variable_anterior) {
  validate_workbook_structure(path)
  mapping <- readxl::read_excel(path = path, sheet = sheet, guess_max = 1000) |>
    rigi_utf8_data_frame(context = paste0("XLSX / ", sheet)) |>
    janitor::clean_names() |>
    dplyr::filter(!is.na(variable_recomendada), trimws(as.character(variable_recomendada)) != "") |>
    dplyr::mutate(variable_recomendada = janitor::make_clean_names(variable_recomendada))

  required_columns <- c("orden", "nombre_actual_en_xlsx_madre", "variable_recomendada")
  missing_columns <- setdiff(required_columns, names(mapping))
  if (length(missing_columns) > 0) {
    stop(
      "La hoja Variable_Anterior no contiene las columnas obligatorias: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }
  if (anyDuplicated(mapping$variable_recomendada)) {
    stop("Variable_Anterior contiene destinos canónicos duplicados.", call. = FALSE)
  }
  missing_targets <- setdiff(required_project_variables, mapping$variable_recomendada)
  if (length(missing_targets) > 0) {
    stop(
      "Variable_Anterior no documenta las variables canónicas: ",
      paste(missing_targets, collapse = ", "),
      call. = FALSE
    )
  }
  mapping |>
    dplyr::arrange(orden)
}

# Detecta hojas largas de fuentes sin depender de un nombre fijo. Se priorizan
# las hojas cuyo nombre contiene "fuente" y se valida su estructura antes de
# leerlas. Si el Excel no incluye una hoja compatible, devuelve una tabla vacía.
load_fuentes_proyectos <- function(path = excel_path) {
  if (!file.exists(path)) return(tibble::tibble())

  sheets <- readxl::excel_sheets(path)
  sheets <- setdiff(sheets, c(sheet_proyectos, sheet_diccionario, sheet_variable_anterior))
  if (length(sheets) == 0) return(tibble::tibble())

  preferred <- sheets[stringr::str_detect(
    janitor::make_clean_names(sheets),
    "fuente|source"
  )]
  candidates <- if (length(preferred) > 0) preferred else sheets

  source_tables <- lapply(candidates, function(sheet) {
    headers <- tryCatch(
      names(readxl::read_excel(path, sheet = sheet, n_max = 0)),
      error = function(e) character(0)
    )
    clean_headers <- janitor::make_clean_names(headers)

    has_source <- any(stringr::str_detect(clean_headers, "(^|_)(fuente|source|medio)($|_)"))
    has_url <- any(stringr::str_detect(clean_headers, "(^|_)(url|link|enlace)($|_)"))
    has_project_key <- any(clean_headers %in% c(
      "id_proyecto", "project_id", "id", "nombre_proyecto", "proyecto", "vpu"
    ))

    if (!has_source || !has_url || !has_project_key) return(NULL)

    readxl::read_excel(path, sheet = sheet, guess_max = 10000) |>
      rigi_utf8_data_frame(context = paste0("XLSX / ", sheet)) |>
      dplyr::mutate(hoja_origen_fuentes = sheet)
  })

  source_tables <- Filter(Negate(is.null), source_tables)
  if (length(source_tables) == 0) return(tibble::tibble())

  dplyr::bind_rows(source_tables)
}

get_file_update_time <- function(path = excel_path) {
  if (!file.exists(path)) return(as.POSIXct(NA))
  file.info(path)$mtime
}
