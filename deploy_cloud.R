# deploy_cloud.R
# This script deploys the dashboard to shinyapps.io

# 1. Install rsconnect if missing
if (!requireNamespace("rsconnect", quietly = TRUE)) {
  install.packages("rsconnect", repos = "https://cran.rstudio.com/")
}
library(rsconnect)

# -------------------------------------------------------------------------
# AUTHENTICATION
# -------------------------------------------------------------------------
# Check for GitHub Actions Environment Variables
shinyapps_name <- Sys.getenv("SHINYAPPS_NAME")
shinyapps_token <- Sys.getenv("SHINYAPPS_TOKEN")
shinyapps_secret <- Sys.getenv("SHINYAPPS_SECRET")

if (shinyapps_name != "" && shinyapps_token != "" && shinyapps_secret != "") {
  cat("Authenticating with shinyapps.io using GitHub Secrets...\n")
  rsconnect::setAccountInfo(name = shinyapps_name,
                            token = shinyapps_token,
                            secret = shinyapps_secret)
} else {
  cat("No environment variables found. Relying on local computer's cached rsconnect authentication.\n")
}

# -------------------------------------------------------------------------
# DEPLOYMENT
# -------------------------------------------------------------------------
cat("Preparing to deploy to shinyapps.io...\n")

# Verify that app_data is populated (run the pipeline locally first if it isn't!)
if (!file.exists("dashboard/app_data/predictive_model.rds")) {
  stop("ERROR: The dashboard/app_data folder is missing the model! Please run 'run.bat' locally first to build the pipeline artifacts.")
}

rsconnect::deployApp(
  appDir = "dashboard",
  appName = "Predictive-Market-Intelligence",
  forceUpdate = TRUE
)

cat("Deployment complete!\n")
