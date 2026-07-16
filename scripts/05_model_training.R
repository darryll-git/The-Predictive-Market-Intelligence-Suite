# scripts/05_model_training.R

library(dplyr)
library(tidymodels)
library(glmnet)

cat("Starting model training with rolling-origin cross-validation...\n")

# 1. Load Data
model_ready_path <- "data/processed/model_ready_data.csv"
if (!file.exists(model_ready_path)) {
  stop("Model-ready dataset not found! Run scripts 01 through 04 first.")
}

data <- read.csv(model_ready_path, stringsAsFactors = TRUE)
data$date <- as.Date(data$date)
data <- data %>% arrange(date)

# 2. Time-Series Validation Split
# Expanding window cross-validation to prevent time-series leakage
# We have 16 series (4 categories * 4 regions) per week.
# Train on ~1.5 years initially, validate on 12-week rolling windows.
n_series <- 16
initial_rows <- round((52 * 1.5) * n_series)
assess_rows <- 12 * n_series
skip_rows <- 4 * n_series # Slide window forward by 4 weeks at a time

ts_folds <- rsample::rolling_origin(
  data,
  initial = initial_rows,
  assess = assess_rows,
  cumulative = TRUE,
  skip = skip_rows
)

# 3. Model Definition
# Lightweight Elastic Net Linear Regression (minimal RAM, high interpretability)
elastic_net_spec <- parsnip::linear_reg(penalty = 0.01, mixture = 0.5) %>%
  set_engine("glmnet") %>%
  set_mode("regression")

# 4. Recipe Definition
model_rec <- recipes::recipe(units_sold ~ product_category + region + unit_price + 
                      competitor_price + price_ratio + marketing_log + 
                      month_factor + fourier_sin + fourier_cos + 
                      roll_mean_vol_4 + roll_mean_vol_12 + 
                      roll_mean_price_ratio_4 + shock_decay + 
                      lag_volume_1 + lag_volume_2, 
                    data = data) %>%
  recipes::step_dummy(recipes::all_nominal_predictors()) %>%
  recipes::step_normalize(recipes::all_numeric_predictors())

# 5. Workflow
workflow <- workflows::workflow() %>%
  workflows::add_model(elastic_net_spec) %>%
  workflows::add_recipe(model_rec)

# 6. Evaluate via Cross-Validation
cat("Evaluating model via expanding-window time-series CV...\n")
# suppress warnings from glmnet convergence on small CV chunks
suppressWarnings({
  cv_results <- tune::fit_resamples(
    workflow,
    resamples = ts_folds,
    metrics = yardstick::metric_set(yardstick::rmse, yardstick::rsq, yardstick::mae)
  )
})

metrics_df <- tune::collect_metrics(cv_results)
cat("\n--- Out-Of-Sample Validation Metrics ---\n")
print(metrics_df)

# 7. Final Fit on All Data
cat("\nFitting final global model...\n")
final_fit <- parsnip::fit(workflow, data = data)

# 8. Variable Importance
if (requireNamespace("vip", quietly = TRUE)) {
  importance_df <- final_fit %>%
    workflows::extract_fit_parsnip() %>%
    vip::vi()
} else {
  importance_df <- final_fit %>%
    workflows::extract_fit_parsnip() %>%
    broom::tidy() %>%
    dplyr::filter(term != "(Intercept)") %>%
    dplyr::mutate(Importance = abs(estimate)) %>%
    dplyr::rename(Variable = term) %>%
    dplyr::arrange(dplyr::desc(Importance)) %>%
    dplyr::select(Variable, Importance)
}

# 9. Bundle and Save Artifact
artifact_path <- "data/processed/predictive_model.rds"

bundled_artifact <- list(
  model = final_fit,
  metrics = metrics_df,
  feature_importance = importance_df,
  training_timestamp = Sys.time()
)

saveRDS(bundled_artifact, artifact_path)
cat(sprintf("\nModel artifact successfully bundled and saved to %s\n", artifact_path))

# Copy the model into the dashboard folder for self-contained shinyapps.io deployment
if (!dir.exists("dashboard/app_data")) {
  dir.create("dashboard/app_data", recursive = TRUE)
}
file.copy(artifact_path, "dashboard/app_data/predictive_model.rds", overwrite = TRUE)
cat("Model artifact mirrored to dashboard/app_data/ for UI deployment.\n")

cat(sprintf("Memory Size of Artifact: %.2f MB\n", as.numeric(object.size(bundled_artifact)) / (1024^2)))

