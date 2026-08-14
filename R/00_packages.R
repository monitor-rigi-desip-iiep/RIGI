# Paquetes requeridos ---------------------------------------------------------
# Este script carga las dependencias necesarias para renderizar el informe.
# Si faltan paquetes, los instala automáticamente tanto en ejecución local
# como en GitHub Actions.

required_packages <- c(
  "tidyverse",
  "readxl",
  "janitor",
  "lubridate",
  "plotly",
  "DT",
  "glue",
  "scales",
  "htmltools",
  "htmlwidgets",
  "forcats",
  "writexl",
  "jsonlite"
)

install_if_missing <- function(packages) {
  missing_packages <- packages[!packages %in% rownames(installed.packages())]

  if (length(missing_packages) > 0) {
    message(
      "Instalando paquetes faltantes: ",
      paste(missing_packages, collapse = ", ")
    )

    install.packages(
      missing_packages,
      repos = "https://cloud.r-project.org",
      dependencies = TRUE
    )
  }
}

install_if_missing(required_packages)
invisible(lapply(required_packages, library, character.only = TRUE))
