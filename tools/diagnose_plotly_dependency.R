#!/usr/bin/env Rscript

# Diagnóstico reproducible de la dependencia Plotly usada por los módulos
# JavaScript de aprobados.qmd. No imprime ni renderiza el widget mínimo.

summarize_dependencies <- function(dependencies) {
  if (inherits(dependencies, "html_dependency")) {
    dependencies <- list(dependencies)
  }

  lapply(dependencies, function(dependency) {
    list(
      name = dependency$name,
      version = dependency$version,
      script = dependency$script,
      stylesheet = dependency$stylesheet,
      src = dependency$src
    )
  })
}

cat("R: ", R.version.string, "\n", sep = "")
cat("plotly: ", as.character(utils::packageVersion("plotly")), "\n", sep = "")
cat("htmlwidgets: ", as.character(utils::packageVersion("htmlwidgets")), "\n", sep = "")
cat("htmltools: ", as.character(utils::packageVersion("htmltools")), "\n", sep = "")

static_dependencies <- htmlwidgets::getDependency(
  "plotly",
  package = "plotly"
)

minimal_widget <- plotly::plot_ly(
  x = 0,
  y = 0,
  type = "scatter",
  mode = "markers"
)
dynamic_dependencies <- minimal_widget$dependencies

source(file.path("R", "05_planes_inversion.R"), encoding = "UTF-8")
resolved_dependencies <- rigi_plotly_dependencies()

cat("\nDependencias estáticas de htmlwidgets::getDependency():\n")
print(summarize_dependencies(static_dependencies))
cat("\nDependencias dinámicas de minimal_widget$dependencies:\n")
print(summarize_dependencies(dynamic_dependencies))
cat("\nEstructura de minimal_widget$dependencies:\n")
str(dynamic_dependencies)
cat("\nDependencias resueltas y deduplicadas:\n")
print(summarize_dependencies(resolved_dependencies))

resolved_names <- vapply(
  resolved_dependencies,
  function(dependency) {
    if (is.null(dependency$name)) "" else as.character(dependency$name)
  },
  character(1)
)
plotly_main_index <- startsWith(resolved_names, "plotly-main")

if (!any(plotly_main_index)) {
  stop(
    "El diagnóstico no encontró plotly-main entre las dependencias resueltas.",
    call. = FALSE
  )
}

plotly_main <- resolved_dependencies[[which(plotly_main_index)[1]]]
cat("\nPlotly.js resuelto:\n")
cat("  nombre: ", plotly_main$name, "\n", sep = "")
cat("  versión: ", plotly_main$version, "\n", sep = "")
cat("  script: ", paste(plotly_main$script, collapse = ", "), "\n", sep = "")
