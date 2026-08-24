#!/usr/bin/env Rscript

# Regresión de codificación para macOS, Linux y GitHub Actions. Reproduce el
# caso que hacía fallar sort(method = "radix") con "En evaluación" marcada
# como texto de codificación desconocida.

source("R/00_packages.R")
source("R/01_load_data.R")
source("R/02_clean_data.R")
source("R/03_indicators.R")
source("R/04_plots.R")
source("R/07_investment_modules.R")

fail <- function(...) stop(..., call. = FALSE)

unknown_utf8 <- function(value) {
  value <- enc2utf8(value)
  result <- rawToChar(charToRaw(value))
  Encoding(result) <- "unknown"
  result
}

expected_labels <- enc2utf8(c(
  "En evaluación",
  "Petróleo y Gas",
  "Minería",
  "Neuquén",
  "Río Negro"
))
unknown_labels <- vapply(expected_labels, unknown_utf8, character(1), USE.NAMES = FALSE)

filtered <- rigi_filter_values(c(unknown_labels, NA_character_, ""))
if (!setequal(enc2utf8(filtered), expected_labels)) {
  fail("rigi_filter_values() no preservó todas las etiquetas UTF-8 esperadas.")
}

split_provinces <- unknown_utf8("Neuquén; Río Negro")
split_result <- rigi_filter_values(split_provinces, split = TRUE)
if (!setequal(enc2utf8(split_result), enc2utf8(c("Neuquén", "Río Negro")))) {
  fail("rigi_filter_values(split = TRUE) no preservó las provincias con tilde.")
}

raw_data <- load_proyectos()
diccionario <- load_diccionario()
variable_mapping <- load_variable_mapping()
raw_sources <- load_fuentes_proyectos()
project_sources <- build_project_sources(raw_data, raw_sources)
proyectos <- clean_proyectos(raw_data) |>
  attach_project_sources(project_sources)
proyectos_prov <- expand_provincias(proyectos)
tablas <- make_tables(proyectos, proyectos_prov)

check_frame <- function(data, label) {
  character_columns <- names(data)[vapply(data, is.character, logical(1))]
  for (column in character_columns) {
    rigi_as_utf8(data[[column]], paste0(label, " / ", column))
  }
  invisible(TRUE)
}

check_frame(raw_data, "Proyectos")
check_frame(diccionario, "Diccionario")
check_frame(variable_mapping, "Variable_Anterior")
check_frame(proyectos, "modelo interno")

render_cards <- function(data, table_type, caption, widget_key) {
  widget <- make_rigi_project_cards(
    data,
    table_type = table_type,
    caption = caption,
    widget_key = widget_key
  )
  html <- htmltools::renderTags(widget)$html
  if (!nzchar(html)) fail("No se pudo serializar el componente ", widget_key, ".")
  enc2utf8(html)
}

approved_html <- render_cards(
  tablas$base_aprobados,
  "aprobados",
  "Proyectos aprobados",
  "qa-approved"
)
evaluation_html <- render_cards(
  tablas$base_pendientes,
  "pendientes",
  "Proyectos en evaluación",
  "qa-evaluation"
)
total_html <- render_cards(
  tablas$base_total,
  "total",
  "Base completa",
  "qa-total"
)

if (!grepl("En evaluación", evaluation_html, fixed = TRUE)) {
  fail("Las fichas de evaluación no conservaron la etiqueta 'En evaluación'.")
}
if (!grepl("En evaluación", total_html, fixed = TRUE)) {
  fail("La base completa no conservó la etiqueta 'En evaluación'.")
}
if (!grepl("Aprobado", approved_html, fixed = TRUE)) {
  fail("Las fichas de aprobados no conservaron la etiqueta 'Aprobado'.")
}

cat("QA de codificación UTF-8: OK\n")
