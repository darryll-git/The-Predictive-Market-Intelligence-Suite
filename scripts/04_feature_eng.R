# scripts/04_feature_eng.R

library(dplyr)
library(lubridate)

cat("Starting feature engineering process...\n")

# Load cleaned data
processed_path <- "data/processed/cleaned_market_data.csv"
if (!file.exists(processed_path)) {
  stop("Cleaned dataset not found! Please run scripts/02_data_cleaning.R first.")
}

cleaned_data <- read.csv(processed_path, stringsAsFactors = TRUE)
cleaned_data$date <- as.Date(cleaned_data$date)

# 1. Engineer Features
# - price_ratio: relative price comparison vs competitor
# - marketing_log: log-transform of marketing budget (captures diminishing returns)
# - month: seasonal indicator
# - lag_volume_1: units sold from the prior week
# - lag_volume_2: units sold from two weeks ago

model_ready_data <- cleaned_data %>%
  group_by(product_category, region) %>%
  arrange(date) %>%
  mutate(
    price_ratio = unit_price / competitor_price,
    marketing_log = log(marketing_spend + 1),
    month_factor = factor(format(date, "%m")),
    
    # Fourier Terms for Cyclical Seasonality (Period = 52.14 weeks)
    week_num = isoweek(date),
    fourier_sin = sin(2 * pi * week_num / 52.14),
    fourier_cos = cos(2 * pi * week_num / 52.14),
    
    # Rolling Window Features (4-week and 12-week momentum)
    # Using zoo::rollmean with align='right' ensures no future data leakage
    roll_mean_vol_4 = zoo::rollmean(units_sold, k = 4, fill = NA, align = "right"),
    roll_mean_vol_12 = zoo::rollmean(units_sold, k = 12, fill = NA, align = "right"),
    roll_mean_price_ratio_4 = zoo::rollmean(price_ratio, k = 4, fill = NA, align = "right"),
    
    # Explicit Regulatory Shock Decay (e^-0.2t)
    last_approval_date = cummax(ifelse(regulatory_approval == 1, as.numeric(date), 0)),
    weeks_since_shock = ifelse(last_approval_date > 0, (as.numeric(date) - last_approval_date) / 7, Inf),
    shock_decay = ifelse(weeks_since_shock <= 10, exp(-0.2 * weeks_since_shock), 0),
    
    # Lagged features for time-series context
    lag_volume_1 = lag(units_sold, 1),
    lag_volume_2 = lag(units_sold, 2)
  ) %>%
  ungroup() %>%
  # Clean up temporary calculation columns
  select(-week_num, -last_approval_date, -weeks_since_shock)

# Report dimension before dropping NAs from lags
n_before <- nrow(model_ready_data)

# Remove rows containing NA from lagged and rolling features
model_ready_data <- model_ready_data %>%
  filter(!is.na(lag_volume_1) & !is.na(lag_volume_2) & !is.na(roll_mean_vol_12) & !is.na(roll_mean_price_ratio_4))

n_after <- nrow(model_ready_data)
cat(sprintf("Engineered features created. Dropped %d rows containing initial NA lags/windows. Final rows: %d\n", (n_before - n_after), n_after))

# Save the model-ready dataset
write.csv(model_ready_data, "data/processed/model_ready_data.csv", row.names = FALSE)
cat("Feature-engineered dataset saved to data/processed/model_ready_data.csv successfully!\n")

# Copy the dataset into the dashboard folder for self-contained shinyapps.io deployment
if (!dir.exists("dashboard/app_data")) {
  dir.create("dashboard/app_data", recursive = TRUE)
}
# We need the original cleaned market data for the UI
file.copy("data/processed/cleaned_market_data.csv", "dashboard/app_data/cleaned_market_data.csv", overwrite = TRUE)
cat("Dataset mirrored to dashboard/app_data/ for UI deployment.\n")

