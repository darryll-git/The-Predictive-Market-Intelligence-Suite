# setup.R

# Create a local library folder in the project to avoid Windows Admin permission issues
local_lib <- file.path(getwd(), ".R-libs")
if (!dir.exists(local_lib)) {
  dir.create(local_lib, showWarnings = FALSE)
}
.libPaths(c(local_lib, .libPaths()))

# Ensure renv is installed
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org", lib = local_lib)
}

library(renv)

# Restore the environment if renv.lock is present
if (file.exists("renv.lock")) {
  renv::restore(prompt = FALSE)
  cat("renv environment restored.\n")
} else {
  cat("No renv.lock found; proceeding without restoration.\n")
  
  # Packages required for the Predictive Market Intelligence Suite
  required_packages <- c(
    "shiny", "dplyr", "tidyr", "ggplot2", "readr", "lubridate",
    "randomForest", "plotly", "bslib", "DT", "shinyWidgets"
  )
  
  for (pkg in required_packages) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      cat(sprintf("Installing '%s' to local library...\n", pkg))
      install.packages(pkg, repos = "https://cloud.r-project.org", lib = local_lib)
    }
  }
}

