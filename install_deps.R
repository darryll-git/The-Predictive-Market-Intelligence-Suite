local_lib <- file.path(getwd(), ".R-libs")
dir.create(local_lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(local_lib, .libPaths()))
install.packages(c("dplyr", "tidyr", "lubridate", "ggplot2", "plotly", "DT", "shinyWidgets", "bslib", "quantmod", "zoo", "tseries", "tidymodels", "glmnet", "vip"), lib = local_lib, repos="https://cloud.r-project.org/")
