# Limpieza y estandarización --------------------------------------------------

na_labels <- c(
  "", "NA", "N/A", "S/D", "s/d", "sd", "Sin dato", "sin dato",
  "No informado", "no informado", "NO INFORMADO", "No informa", "-", "--",
  "nan", "NaN", "NULL", "null"
)

empty_to_na <- function(x) {
  if (!is.character(x)) return(x)
  x <- stringr::str_squish(x)
  x[x %in% na_labels] <- NA_character_
  x
}

normalize_text <- function(x) {
  x <- as.character(x)
  x <- stringr::str_squish(x)
  x <- stringr::str_to_lower(x)
  x <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  x
}

normalize_si_no <- function(x) {
  x_norm <- normalize_text(x)
  dplyr::case_when(
    is.na(x_norm) | x_norm %in% c("", "na", "n/a", "s/d", "sd", "no informado") ~ NA_character_,
    stringr::str_detect(x_norm, "^(si|s)($|\\b)") ~ "Sí",
    stringr::str_detect(x_norm, "^(no|n)($|\\b)") ~ "No",
    TRUE ~ as.character(x)
  )
}

coalesce_text_cols <- function(data, candidates) {
  n <- nrow(data)
  out <- rep(NA_character_, n)
  for (col in candidates) {
    if (col %in% names(data)) {
      out <- dplyr::coalesce(out, empty_to_na(as.character(data[[col]])))
    }
  }
  out
}

coalesce_raw_cols <- function(data, candidates) {
  n <- nrow(data)
  out <- rep(NA_character_, n)
  for (col in candidates) {
    if (col %in% names(data)) {
      out <- dplyr::coalesce(out, as.character(data[[col]]))
    }
  }
  out
}

# Conversión robusta para montos, activos computables y empleos.
# Preserva columnas numéricas si ya vienen como numeric/double desde Excel.
parse_numeric_rigi <- function(x) {
  if (is.numeric(x)) return(as.numeric(x))

  x_chr <- as.character(x)
  x_chr <- stringr::str_trim(x_chr)
  x_chr[x_chr %in% na_labels] <- NA_character_

  # Remover símbolos y texto, preservando dígitos, coma, punto y signo negativo.
  x_chr <- stringr::str_replace_all(x_chr, "[^0-9,.-]", "")

  # Si viene con formato argentino 1.234,56.
  x_chr <- ifelse(
    stringr::str_detect(x_chr, "\\.\\d{3}") & stringr::str_detect(x_chr, ","),
    stringr::str_replace_all(x_chr, "\\.", ""),
    x_chr
  )

  # Si hay más de un punto y no hay coma, interpretamos puntos como separadores de miles.
  x_chr <- ifelse(
    !stringr::str_detect(x_chr, ",") & stringr::str_count(x_chr, "\\.") > 1,
    stringr::str_replace_all(x_chr, "\\.", ""),
    x_chr
  )

  x_chr <- stringr::str_replace_all(x_chr, ",", ".")
  suppressWarnings(as.numeric(x_chr))
}

convert_excel_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))

  x_chr <- as.character(x)
  x_chr <- stringr::str_squish(x_chr)
  x_chr[x_chr %in% na_labels] <- NA_character_

  out <- rep(as.Date(NA), length(x_chr))

  numeric_guess <- suppressWarnings(as.numeric(x_chr))
  numeric_idx <- !is.na(numeric_guess)

  # Excel usa 1899-12-30 como origen práctico para fechas seriales.
  out[numeric_idx] <- as.Date(numeric_guess[numeric_idx], origin = "1899-12-30")

  text_idx <- !numeric_idx & !is.na(x_chr)
  if (any(text_idx)) {
    parsed_text <- suppressWarnings(lubridate::parse_date_time(
      x_chr[text_idx],
      orders = c("ymd", "dmy", "mdy", "Ymd", "dmY", "mdY", "d/m/Y", "Y-m-d")
    ))
    out[text_idx] <- as.Date(parsed_text)
  }

  out
}

# Fuentes y enlaces ----------------------------------------------------------

globaris_source_url <- paste0(
  "https://app.powerbi.com/view?r=",
  "eyJrIjoiNTFjY2E4NTYtOTVlNy00YmFiLWIwYmMtNWZkMjE4OTNhYmRiIiwidCI6",
  "IjNlMDUxM2Q2LTY4ZmEtNDE2ZS04ZGUxLTZjNWNkYzMxOWZmYSIsImMiOjR9",
  "&pageName=d1ee75596a51a9bde708"
)

safe_http_url <- function(x) {
  value <- empty_to_na(as.character(x))
  valid <- !is.na(value) & stringr::str_detect(
    value,
    stringr::regex("^https?://[^\\s<>\\\"']+$", ignore_case = TRUE)
  )
  value[!valid] <- NA_character_
  value
}

infer_source_name_from_url <- function(url) {
  url <- safe_http_url(url)
  domain <- stringr::str_match(
    dplyr::coalesce(url, ""),
    stringr::regex("^https?://(?:www\\.)?([^/:?#]+)", ignore_case = TRUE)
  )[, 2]
  domain <- stringr::str_to_lower(domain)

  dplyr::case_when(
    stringr::str_detect(domain, "(^|\\.)lanacion\\.com\\.ar$") ~ "La Nación",
    stringr::str_detect(domain, "(^|\\.)clarin\\.com$") ~ "Clarín",
    stringr::str_detect(domain, "(^|\\.)cronista\\.com$") ~ "El Cronista",
    stringr::str_detect(domain, "(^|\\.)econojournal\\.com\\.ar$") ~ "EconoJournal",
    stringr::str_detect(domain, "(^|\\.)boletinoficial\\.gob\\.ar$") ~ "Boletín Oficial",
    stringr::str_detect(domain, "(^|\\.)argentina\\.gob\\.ar$") ~ "Argentina.gob.ar",
    stringr::str_detect(domain, "(^|\\.)x\\.com$") ~ "X",
    stringr::str_detect(domain, "(^|\\.)instagram\\.com$") ~ "Instagram",
    is.na(url) | is.na(domain) | domain == "" ~ NA_character_,
    TRUE ~ domain
  )
}

normalize_source_key <- function(x) {
  out <- normalize_text(x)
  out[is.na(out)] <- ""
  out
}

compact_source_token <- function(x) {
  out <- as.character(x)
  out <- stringi::stri_trans_general(out, "Latin-ASCII")
  out <- stringr::str_to_lower(out)
  out <- stringr::str_replace_all(out, "[^a-z0-9]", "")
  out[is.na(out)] <- ""
  out
}

url_host_tokens <- function(url) {
  value <- safe_http_url(url)
  if (length(value) == 0 || is.na(value[[1]])) return(character(0))

  host <- stringr::str_match(
    value[[1]],
    stringr::regex("^https?://(?:www\\.)?([^/:?#]+)", ignore_case = TRUE)
  )[, 2]
  if (is.na(host) || host == "") return(character(0))

  labels <- stringr::str_split(host, stringr::fixed("."))[[1]]
  labels <- labels[!labels %in% c(
    "www", "com", "org", "net", "gov", "gob", "edu", "ar", "latam", "amp"
  )]
  tokens <- compact_source_token(labels)
  unique(tokens[nchar(tokens) >= 3L])
}

match_source_name_to_url <- function(url, source_names) {
  host_tokens <- url_host_tokens(url)
  if (length(host_tokens) == 0 || length(source_names) == 0) return(NA_character_)

  source_tokens <- compact_source_token(source_names)
  matches <- vapply(source_tokens, function(source_token) {
    if (source_token == "") return(FALSE)
    any(vapply(host_tokens, function(host_token) {
      stringr::str_detect(source_token, stringr::fixed(host_token)) ||
        stringr::str_detect(host_token, stringr::fixed(source_token))
    }, logical(1)))
  }, logical(1))

  if (sum(matches) != 1L) return(NA_character_)
  source_names[[which(matches)]]
}

expand_source_names_for_urls <- function(source_names, urls) {
  if (length(urls) <= length(source_names) || length(source_names) == 0) {
    return(source_names)
  }

  matched_names <- unname(vapply(
    urls,
    match_source_name_to_url,
    character(1),
    source_names = source_names
  ))
  all_sources_represented <- all(
    normalize_source_key(source_names) %in% normalize_source_key(matched_names)
  )

  if (all(!is.na(matched_names)) && all_sources_represented) matched_names else source_names
}

first_non_missing <- function(x) {
  x <- x[!is.na(x) & trimws(as.character(x)) != ""]
  if (length(x) == 0) return(NA_character_)
  as.character(x[[1]])
}

empty_sources_table <- function() {
  tibble::tibble(
    id_proyecto = character(),
    proyecto = character(),
    fuente = character(),
    url = character(),
    fecha_publicacion = as.Date(character()),
    titulo_fuente = character(),
    origen_fuente = character(),
    orden_fuente = integer()
  )
}

is_source_audit_metadata <- function(x) {
  normalized <- as.character(x)
  normalized <- stringi::stri_trans_general(normalized, "Latin-ASCII")
  normalized <- stringr::str_to_lower(stringr::str_squish(normalized))
  detected <- stringr::str_detect(
    normalized,
    "^(auditoria|fecha\\s+de\\s+auditoria)(?:\\s|$)"
  )
  detected[is.na(detected)] <- FALSE
  detected
}

split_source_names <- function(x) {
  value <- as.character(x)
  if (length(value) == 0 || is.na(value[[1]])) return(character(0))
  if (empty_to_na(value[[1]]) |> is.na()) return(character(0))

  value <- stringr::str_replace_all(
    value[[1]],
    stringr::regex(",\\s*(Globaris)\\b", ignore_case = TRUE),
    "; \\1"
  )
  value <- stringr::str_replace_all(value, stringr::fixed("\r\n"), ";")
  value <- stringr::str_replace_all(value, stringr::fixed("\n"), ";")
  value <- stringr::str_replace_all(value, stringr::fixed("\r"), ";")
  value <- stringr::str_replace_all(value, stringr::fixed("|"), ";")
  out <- stringr::str_split(value, stringr::fixed(";"))[[1]]
  out <- stringr::str_squish(out)
  out <- out[!is.na(out) & out != ""]
  out[!is_source_audit_metadata(out)]
}

extract_source_urls <- function(x) {
  value <- empty_to_na(as.character(x))
  if (length(value) == 0 || is.na(value[[1]])) return(character(0))
  urls <- stringr::str_extract_all(value[[1]], "https?://[^;|\\s]+")[[1]]
  urls <- stringr::str_remove(urls, "[,;]+$")
  as.character(stats::na.omit(safe_http_url(urls)))
}

parse_project_source_cells <- function(raw_data) {
  if (nrow(raw_data) == 0) return(empty_sources_table())

  data <- raw_data |>
    janitor::clean_names() |>
    dplyr::mutate(dplyr::across(where(is.character), empty_to_na))

  ids <- coalesce_text_cols(data, c("id_proyecto", "project_id", "id"))
  projects <- coalesce_text_cols(data, c("proyecto", "vpu", "nombre_proyecto_matcheado"))
  source_cells <- coalesce_text_cols(data, c("fuentes", "fuente"))
  url_cells <- coalesce_text_cols(data, c(
    "links_fuentes", "links_de_fuentes", "urls_fuentes", "url_fuentes",
    "enlaces_fuentes", "links", "urls"
  ))

  records <- vector("list", nrow(data))
  for (i in seq_len(nrow(data))) {
    source_names <- split_source_names(source_cells[[i]])
    urls <- extract_source_urls(url_cells[[i]])
    row_records <- list()
    order_value <- 1L

    is_globaris <- normalize_source_key(source_names) == "globaris"
    if (any(is_globaris)) {
      row_records[[length(row_records) + 1L]] <- tibble::tibble(
        id_proyecto = ids[[i]],
        proyecto = projects[[i]],
        fuente = "Globaris",
        url = globaris_source_url,
        fecha_publicacion = as.Date(NA),
        titulo_fuente = NA_character_,
        origen_fuente = "Proyectos:Fuentes",
        orden_fuente = order_value
      )
      order_value <- order_value + 1L
      source_names <- source_names[!is_globaris]
    }

    # Si un mismo medio aporta más de un enlace, la celda de nombres puede
    # mencionarlo una sola vez. Sólo en ese caso se expande el nombre mediante
    # una coincidencia inequívoca con el dominio, preservando el orden de URLs.
    source_names <- expand_source_names_for_urls(source_names, urls)

    pair_count <- min(length(source_names), length(urls))
    if (pair_count > 0) {
      for (j in seq_len(pair_count)) {
        row_records[[length(row_records) + 1L]] <- tibble::tibble(
          id_proyecto = ids[[i]],
          proyecto = projects[[i]],
          fuente = source_names[[j]],
          url = urls[[j]],
          fecha_publicacion = as.Date(NA),
          titulo_fuente = NA_character_,
          origen_fuente = "Proyectos:Fuentes+Links",
          orden_fuente = order_value
        )
        order_value <- order_value + 1L
      }
    }

    if (length(source_names) > pair_count) {
      for (j in seq.int(pair_count + 1L, length(source_names))) {
        row_records[[length(row_records) + 1L]] <- tibble::tibble(
          id_proyecto = ids[[i]],
          proyecto = projects[[i]],
          fuente = source_names[[j]],
          url = NA_character_,
          fecha_publicacion = as.Date(NA),
          titulo_fuente = NA_character_,
          origen_fuente = "Proyectos:Fuentes",
          orden_fuente = order_value
        )
        order_value <- order_value + 1L
      }
    }

    if (length(urls) > pair_count) {
      for (j in seq.int(pair_count + 1L, length(urls))) {
        row_records[[length(row_records) + 1L]] <- tibble::tibble(
          id_proyecto = ids[[i]],
          proyecto = projects[[i]],
          fuente = infer_source_name_from_url(urls[[j]]),
          url = urls[[j]],
          fecha_publicacion = as.Date(NA),
          titulo_fuente = NA_character_,
          origen_fuente = "Proyectos:Links",
          orden_fuente = order_value
        )
        order_value <- order_value + 1L
      }
    }

    records[[i]] <- dplyr::bind_rows(row_records)
  }

  cell_sources <- dplyr::bind_rows(records)

  # Compatibilidad futura con pares numerados como fuente_1/link_fuente_1.
  source_columns <- names(data)[stringr::str_detect(
    names(data),
    "^(fuente|nombre_fuente|source|medio)_?[0-9]+$"
  )]
  paired_records <- list()
  if (length(source_columns) > 0) {
    for (source_column in source_columns) {
      suffix <- stringr::str_extract(source_column, "[0-9]+$")
      url_candidates <- c(
        paste0("url_fuente_", suffix), paste0("link_fuente_", suffix),
        paste0("enlace_fuente_", suffix), paste0("url_", suffix),
        paste0("link_", suffix), paste0("enlace_", suffix)
      )
      date_candidates <- c(paste0("fecha_fuente_", suffix), paste0("fecha_", suffix))
      title_candidates <- c(paste0("titulo_fuente_", suffix), paste0("titulo_", suffix))
      url_column <- url_candidates[url_candidates %in% names(data)][1]
      date_column <- date_candidates[date_candidates %in% names(data)][1]
      title_column <- title_candidates[title_candidates %in% names(data)][1]

      source_values <- empty_to_na(as.character(data[[source_column]]))
      url_values <- if (!is.na(url_column)) safe_http_url(data[[url_column]]) else rep(NA_character_, nrow(data))
      date_values <- if (!is.na(date_column)) convert_excel_date(data[[date_column]]) else rep(as.Date(NA), nrow(data))
      title_values <- if (!is.na(title_column)) empty_to_na(as.character(data[[title_column]])) else rep(NA_character_, nrow(data))

      paired_records[[length(paired_records) + 1L]] <- tibble::tibble(
        id_proyecto = ids,
        proyecto = projects,
        fuente = dplyr::coalesce(source_values, infer_source_name_from_url(url_values)),
        url = url_values,
        fecha_publicacion = date_values,
        titulo_fuente = title_values,
        origen_fuente = paste0("Proyectos:", source_column),
        orden_fuente = as.integer(suffix) + 1000L
      ) |>
        dplyr::filter(!is.na(fuente) | !is.na(url))
    }
  }

  dplyr::bind_rows(cell_sources, paired_records)
}

parse_long_source_table <- function(raw_sources) {
  if (is.null(raw_sources) || nrow(raw_sources) == 0) return(empty_sources_table())

  data <- raw_sources |>
    janitor::clean_names() |>
    dplyr::mutate(dplyr::across(where(is.character), empty_to_na))

  sources <- tibble::tibble(
    id_proyecto = coalesce_text_cols(data, c("id_proyecto", "project_id", "id")),
    proyecto = coalesce_text_cols(data, c("nombre_proyecto", "proyecto", "vpu")),
    fuente = coalesce_text_cols(data, c("fuente", "nombre_fuente", "source", "medio")),
    url = coalesce_text_cols(data, c("url", "url_fuente", "link_fuente", "link", "enlace")),
    fecha_publicacion = convert_excel_date(coalesce_raw_cols(
      data,
      c("fecha_publicacion", "fecha_fuente", "fecha", "date")
    )),
    titulo_fuente = coalesce_text_cols(data, c(
      "titulo_fuente", "titulo", "articulo", "titulo_articulo", "title"
    )),
    origen_fuente = coalesce_text_cols(data, c("hoja_origen_fuentes")),
    orden_fuente = seq_len(nrow(data))
  ) |>
    dplyr::mutate(
      url = safe_http_url(url),
      fuente = dplyr::coalesce(fuente, infer_source_name_from_url(url)),
      origen_fuente = dplyr::coalesce(origen_fuente, "Hoja de fuentes")
    ) |>
    dplyr::filter(
      !is_source_audit_metadata(fuente),
      !is.na(fuente) | !is.na(url)
    )

  sources
}

build_project_sources <- function(raw_data, raw_sources = tibble::tibble()) {
  cell_sources <- parse_project_source_cells(raw_data)
  long_sources <- parse_long_source_table(raw_sources)

  # Cuando existe una hoja larga para un proyecto, esa estructura prevalece
  # sobre la alineación posicional de las celdas Fuentes/Links_fuentes. De las
  # celdas se conserva Globaris y cualquier par fuente-URL confirmado también
  # en la hoja larga. Esto evita asociar por error una segunda URL a la fuente
  # siguiente cuando un mismo medio tiene más de un artículo.
  if (nrow(long_sources) > 0 && nrow(cell_sources) > 0) {
    project_match_key <- function(id, project) {
      id <- empty_to_na(as.character(id))
      project <- normalize_source_key(project)
      ifelse(!is.na(id), paste0("id:", id), paste0("project:", project))
    }
    long_project_keys <- project_match_key(long_sources$id_proyecto, long_sources$proyecto)
    cell_project_keys <- project_match_key(cell_sources$id_proyecto, cell_sources$proyecto)
    long_exact_keys <- paste(
      long_project_keys,
      normalize_source_key(long_sources$fuente),
      dplyr::coalesce(safe_http_url(long_sources$url), ""),
      sep = "\r"
    )
    cell_exact_keys <- paste(
      cell_project_keys,
      normalize_source_key(cell_sources$fuente),
      dplyr::coalesce(safe_http_url(cell_sources$url), ""),
      sep = "\r"
    )
    cell_sources <- cell_sources[
      !cell_project_keys %in% long_project_keys |
        normalize_source_key(cell_sources$fuente) == "globaris" |
        cell_exact_keys %in% long_exact_keys,
      ,
      drop = FALSE
    ]
  }

  sources <- dplyr::bind_rows(cell_sources, long_sources) |>
    dplyr::mutate(
      id_proyecto = empty_to_na(as.character(id_proyecto)),
      proyecto = empty_to_na(as.character(proyecto)),
      fuente = empty_to_na(as.character(fuente)),
      url = safe_http_url(url),
      fuente = dplyr::coalesce(fuente, infer_source_name_from_url(url)),
      id_key = dplyr::coalesce(id_proyecto, ""),
      project_key = normalize_source_key(proyecto),
      source_key = normalize_source_key(fuente),
      url_key = dplyr::coalesce(url, "")
    ) |>
    dplyr::filter(
      !is_source_audit_metadata(fuente),
      fuente != "" | url_key != ""
    ) |>
    dplyr::group_by(id_key, project_key, source_key, url_key) |>
    dplyr::summarise(
      id_proyecto = first_non_missing(id_proyecto),
      proyecto = first_non_missing(proyecto),
      fuente = first_non_missing(fuente),
      url = first_non_missing(url),
      fecha_publicacion = {
        value <- fecha_publicacion[!is.na(fecha_publicacion)]
        if (length(value) == 0) as.Date(NA) else value[[1]]
      },
      titulo_fuente = first_non_missing(titulo_fuente),
      origen_fuente = paste(unique(stats::na.omit(origen_fuente)), collapse = "; "),
      orden_fuente = min(orden_fuente, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      source_priority = dplyr::if_else(source_key == "globaris", 0L, 1L)
    ) |>
    dplyr::arrange(id_key, project_key, source_priority, orden_fuente, fuente)

  sources |>
    dplyr::select(
      id_proyecto, proyecto, fuente, url, fecha_publicacion,
      titulo_fuente, origen_fuente, orden_fuente
    )
}

format_sources_download <- function(sources) {
  if (is.null(sources) || nrow(sources) == 0) return(NA_character_)

  source_keys <- normalize_source_key(sources$fuente)
  repeated <- ave(source_keys, source_keys, FUN = length) > 1
  labels <- dplyr::coalesce(sources$fuente, infer_source_name_from_url(sources$url), "Fuente")
  has_date <- !is.na(sources$fecha_publicacion)
  labels[repeated & has_date] <- paste0(
    labels[repeated & has_date],
    " (", format(sources$fecha_publicacion[repeated & has_date], "%d/%m/%Y"), ")"
  )

  values <- ifelse(
    !is.na(sources$url),
    paste0(labels, " [", sources$url, "]"),
    labels
  )
  paste(values, collapse = "; ")
}

attach_project_sources <- function(data, sources) {
  source_ids <- empty_to_na(as.character(sources$id_proyecto))
  source_projects <- normalize_source_key(sources$proyecto)

  source_lists <- lapply(seq_len(nrow(data)), function(i) {
    id_value <- empty_to_na(as.character(data$id_proyecto[[i]]))
    project_value <- normalize_source_key(data$proyecto[[i]])
    matches <- (!is.na(id_value) & source_ids == id_value) |
      (project_value != "" & source_projects == project_value)
    matches[is.na(matches)] <- FALSE
    project_sources <- sources[matches, , drop = FALSE]

    if (isTRUE(data$pendiente_aprobacion[[i]]) &&
        !any(normalize_source_key(project_sources$fuente) == "globaris")) {
      project_sources <- dplyr::bind_rows(
        tibble::tibble(
          id_proyecto = id_value,
          proyecto = data$proyecto[[i]],
          fuente = "Globaris",
          url = globaris_source_url,
          fecha_publicacion = as.Date(NA),
          titulo_fuente = NA_character_,
          origen_fuente = "Metodología del dashboard",
          orden_fuente = 0L
        ),
        project_sources
      )
    }

    project_sources |>
      dplyr::mutate(
        source_priority = dplyr::if_else(normalize_source_key(fuente) == "globaris", 0L, 1L)
      ) |>
      dplyr::arrange(source_priority, orden_fuente, fuente) |>
      dplyr::select(-source_priority)
  })

  data |>
    dplyr::mutate(
      fuentes_lista = source_lists,
      fuentes_descarga = vapply(source_lists, format_sources_download, character(1))
    )
}

make_source_audit <- function(data) {
  pending <- data |> dplyr::filter(pendiente_aprobacion)
  if (nrow(pending) == 0) return(tibble::tibble())

  purrr::map_dfr(seq_len(nrow(pending)), function(i) {
    sources <- pending$fuentes_lista[[i]]
    complementary <- sources[normalize_source_key(sources$fuente) != "globaris", , drop = FALSE]
    tibble::tibble(
      id_proyecto = pending$id_proyecto[[i]],
      Proyecto = pending$proyecto[[i]],
      `Fuentes encontradas` = nrow(sources),
      `URLs encontradas` = sum(!is.na(sources$url)),
      `Fuentes complementarias` = nrow(complementary),
      `Fuentes mostradas en ficha` = format_sources_download(sources),
      Estado = dplyr::case_when(
        nrow(sources) == 0 ~ "Sin fuentes",
        any(is.na(sources$fuente) & !is.na(sources$url)) ~ "Revisar nombre de fuente",
        TRUE ~ "OK"
      )
    )
  })
}

clean_proyectos <- function(raw_data) {
  data <- raw_data |>
    janitor::clean_names() |>
    dplyr::mutate(dplyr::across(where(is.character), empty_to_na))

  proyecto <- coalesce_text_cols(data, c("proyecto", "vpu", "nombre_proyecto_matcheado"))
  descripcion <- coalesce_text_cols(data, c("descripcion_del_proyecto", "descripcion", "description"))
  empresa <- coalesce_text_cols(data, c("empresa", "empresas"))
  titular <- coalesce_text_cols(data, c("titular_proyecto", "vpu_o_sociedad", "sociedad", "titular"))
  cuit <- coalesce_text_cols(data, c("cuit", "cuit_titular"))
  sector <- coalesce_text_cols(data, c("sector"))
  subsector <- coalesce_text_cols(data, c("subsector"))
  actividad_subsector <- coalesce_text_cols(data, c("actividad_subsector_resolucion_mecon", "actividad_subsector"))
  provincia <- coalesce_text_cols(data, c("provincia"))
  localidad_region <- coalesce_text_cols(data, c("localidad_region", "localidad", "region"))
  estado <- coalesce_text_cols(data, c("estado_administrativo", "estado"))
  norma <- coalesce_text_cols(data, c("norma_aprobacion", "norma"))
  link_norma <- coalesce_text_cols(data, c("link_norma", "url_norma", "enlace_norma"))
  fuentes <- coalesce_text_cols(data, c("fuentes", "fuente"))
  links_fuentes <- coalesce_text_cols(data, c(
    "links_fuentes", "links_de_fuentes", "urls_fuentes", "url_fuentes",
    "enlaces_fuentes", "links", "urls"
  ))
  preexistencia <- coalesce_text_cols(data, c("clasificacion_preexistencia_boletin_oficial", "clasificacion_preexistencia"))
  justificacion_preexistencia <- coalesce_text_cols(data, c("justificacion_preexistencia_boletin_oficial", "justificacion_preexistencia"))
  proyecto_exportacion <- coalesce_text_cols(data, c(
    "proyectos_de_exportacion_estrategica_de_largo_plazo_peelp",
    "proyecto_de_exportacion_estrategica_de_largo_plazo_peelp",
    "proyectos_de_exportacion_estrategica_largo_plazo_peelp",
    "proyecto_de_exportacion_estrategica_largo_plazo_peelp",
    "proyecto_de_exportacion_estrategia_a_largo_plazo",
    "proyecto_de_exportacion_estrategia_a_largo_plazo_"
  ))

  monto_raw <- coalesce_raw_cols(data, c("monto_mill_usd", "monto_usd_mill", "monto"))
  activos_raw <- coalesce_raw_cols(data, c("activos_computables_mill_usd", "activos_computables_usd_mill", "activos_computables"))
  empleos_raw <- coalesce_raw_cols(data, c(
    "empleos_directos_e_indirectos",
    "empleos_directos_indirectos",
    "empleos_directos_e_indirectos_",
    "empleos",
    "empleo",
    "empleos_directos_indirectos_total"
  ))

  fecha_presentacion_raw <- coalesce_raw_cols(data, c("fecha_presentacion", "fecha_de_presentacion"))
  fecha_adhesion_raw <- coalesce_raw_cols(data, c("fecha_adhesion_rigi", "fecha_adhesion", "fecha_de_adhesion_rigi"))
  fecha_publicacion_bo_raw <- coalesce_raw_cols(data, c("fecha_publicacion_bo", "fecha_publicacion_boletin_oficial", "fecha_publicacion"))
  fecha_aprobacion_raw <- coalesce_raw_cols(data, c("fecha_aprobacion", "fecha_de_aprobacion"))

  fecha_presentacion <- convert_excel_date(fecha_presentacion_raw)
  fecha_adhesion_rigi <- convert_excel_date(fecha_adhesion_raw)
  fecha_publicacion_bo <- convert_excel_date(fecha_publicacion_bo_raw)
  fecha_aprobacion_original <- convert_excel_date(fecha_aprobacion_raw)

  # Para aprobados, la fecha operacional de aprobación se prioriza como publicación en BO.
  fecha_aprobacion <- dplyr::coalesce(fecha_aprobacion_original, fecha_publicacion_bo, fecha_adhesion_rigi)

  estado_norm <- normalize_text(estado)
  aprobado <- stringr::str_detect(estado_norm, "aprob") & !stringr::str_detect(estado_norm, "no aprob|rechaz|desest")
  pendiente <- !aprobado & stringr::str_detect(estado_norm, "evalu|pend|anal|present|tram|anunci")

  base <- tibble::tibble(
    row_id = seq_len(nrow(data)),
    id_proyecto = coalesce_text_cols(data, c("id_proyecto", "id")),
    proyecto = proyecto,
    descripcion_del_proyecto = descripcion,
    proyecto_de_exportacion_estrategia_largo_plazo = normalize_si_no(proyecto_exportacion),
    proyecto_exportacion_estrategia_largo_plazo_si = normalize_si_no(proyecto_exportacion) == "Sí",
    empresa = empresa,
    titular_proyecto = titular,
    vpu_o_sociedad = titular,
    cuit = cuit,
    sector = sector,
    subsector = subsector,
    actividad_subsector_resolucion_mecon = actividad_subsector,
    provincia_original = provincia,
    provincia = provincia,
    localidad_region = localidad_region,
    monto_usd_mill = parse_numeric_rigi(monto_raw),
    activos_computables_usd_mill = parse_numeric_rigi(activos_raw),
    empleos_directos_indirectos = parse_numeric_rigi(empleos_raw),
    estado = estado,
    fecha_presentacion = fecha_presentacion,
    fecha_adhesion_rigi = fecha_adhesion_rigi,
    fecha_publicacion_bo = fecha_publicacion_bo,
    fecha_aprobacion = fecha_aprobacion,
    norma_aprobacion = norma,
    clasificacion_preexistencia_boletin_oficial = preexistencia,
    justificacion_preexistencia_boletin_oficial = justificacion_preexistencia,
    link_norma = link_norma,
    fuentes = fuentes,
    fuentes_original = fuentes,
    links_fuentes_original = links_fuentes,
    estado_simplificado = dplyr::case_when(
      aprobado ~ "Aprobado",
      pendiente ~ "Pendiente de aprobación",
      stringr::str_detect(estado_norm, "no aprob|rechaz|desest") ~ "Rechazado",
      is.na(estado) ~ "No informado",
      TRUE ~ "Otros"
    ),
    aprobado = aprobado,
    pendiente_aprobacion = pendiente,
    sector_simplificado = dplyr::coalesce(sector, "No informado"),
    subsector_simplificado = dplyr::coalesce(subsector, "No informado"),
    provincia_simplificada = dplyr::coalesce(provincia, "No informado"),
    anio_presentacion = lubridate::year(fecha_presentacion),
    anio_aprobacion = lubridate::year(fecha_aprobacion),
    mes_presentacion = lubridate::floor_date(fecha_presentacion, "month"),
    mes_aprobacion = lubridate::floor_date(fecha_aprobacion, "month")
  )

  base |>
    dplyr::mutate(
      n_provincias = stringr::str_count(dplyr::coalesce(provincia_original, "No informado"), ";") + 1L,
      n_provincias = dplyr::if_else(is.na(n_provincias) | n_provincias < 1L, 1L, n_provincias),
      proyecto_multiprovincial = n_provincias > 1L
    )
}

expand_provincias <- function(data) {
  data |>
    dplyr::mutate(
      provincia_expandida = dplyr::coalesce(provincia_original, "No informado"),
      provincia_expandida = dplyr::if_else(provincia_expandida == "", "No informado", provincia_expandida)
    ) |>
    tidyr::separate_rows(provincia_expandida, sep = ";") |>
    dplyr::mutate(
      provincia_expandida = stringr::str_squish(provincia_expandida),
      provincia_expandida = dplyr::if_else(is.na(provincia_expandida) | provincia_expandida == "", "No informado", provincia_expandida)
    ) |>
    dplyr::group_by(row_id) |>
    dplyr::mutate(n_provincias_expandida = dplyr::n()) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      monto_usd_mill_asignado_prop = monto_usd_mill / n_provincias_expandida,
      activos_computables_usd_mill_asignado_prop = activos_computables_usd_mill / n_provincias_expandida,
      empleos_directos_indirectos_asignado_prop = empleos_directos_indirectos / n_provincias_expandida,
      provincia_simplificada = provincia_expandida
    )
}

make_download_table <- function(data) {
  data |>
    dplyr::transmute(
      id_proyecto = id_proyecto,
      Proyecto = proyecto,
      `Descripción del proyecto` = descripcion_del_proyecto,
      `Proyectos de exportación estratégica de largo plazo (PEELP)` = proyecto_de_exportacion_estrategia_largo_plazo,
      empresa = empresa,
      titular_proyecto = titular_proyecto,
      CUIT = cuit,
      sector = sector,
      subsector = subsector,
      provincia = provincia_original,
      localidad_region = localidad_region,
      `Monto (mill. USD)` = as.numeric(monto_usd_mill),
      `Activos Computables (mill. USD)` = as.numeric(activos_computables_usd_mill),
      `Empleos (directos e indirectos)` = as.numeric(empleos_directos_indirectos),
      `Estado administrativo` = estado,
      fecha_presentacion = fecha_presentacion,
      fecha_adhesion_rigi = fecha_adhesion_rigi,
      fecha_publicacion_bo = fecha_publicacion_bo,
      fecha_aprobacion = fecha_aprobacion,
      norma_aprobacion = norma_aprobacion,
      link_norma = link_norma,
      Fuentes = fuentes_descarga,
      `Fuentes (original)` = fuentes_original,
      `Links fuentes (original)` = links_fuentes_original
    )
}

create_download_files <- function(data, output_dir = "downloads") {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  aprobados_download <- data |>
    dplyr::filter(aprobado) |>
    make_download_table()

  pendientes_download <- data |>
    dplyr::filter(pendiente_aprobacion) |>
    make_download_table()

  total_download <- data |>
    make_download_table()

  readr::write_csv(aprobados_download, file.path(output_dir, "base_interactiva_aprobados.csv"), na = "")
  readr::write_csv(pendientes_download, file.path(output_dir, "base_interactiva_pendientes.csv"), na = "")
  readr::write_csv(total_download, file.path(output_dir, "base_completa.csv"), na = "")

  writexl::write_xlsx(aprobados_download, file.path(output_dir, "base_interactiva_aprobados.xlsx"))
  writexl::write_xlsx(pendientes_download, file.path(output_dir, "base_interactiva_pendientes.xlsx"))
  writexl::write_xlsx(total_download, file.path(output_dir, "base_completa.xlsx"))

  invisible(list(
    aprobados = aprobados_download,
    pendientes = pendientes_download,
    total = total_download
  ))
}
