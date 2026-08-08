# Lectura de datos ------------------------------------------------------------

excel_path <- "data/RIGI_tracker_data_final_con_proyectos_integrados.xlsx"
sheet_proyectos <- "Proyectos"

load_proyectos <- function(path = excel_path, sheet = sheet_proyectos) {
  if (!file.exists(path)) {
    stop(
      "No se encontró el archivo Excel en: ", path,
      "\nVerificá que el archivo esté dentro de la carpeta data/.",
      call. = FALSE
    )
  }

  readxl::read_excel(
    path = path,
    sheet = sheet,
    guess_max = 10000
  )
}

# Detecta hojas largas de fuentes sin depender de un nombre fijo. Se priorizan
# las hojas cuyo nombre contiene "fuente" y se valida su estructura antes de
# leerlas. Si el Excel no incluye una hoja compatible, devuelve una tabla vacía.
load_fuentes_proyectos <- function(path = excel_path) {
  if (!file.exists(path)) return(tibble::tibble())

  sheets <- readxl::excel_sheets(path)
  sheets <- sheets[sheets != sheet_proyectos]
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
