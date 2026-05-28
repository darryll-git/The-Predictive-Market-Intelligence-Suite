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
    
    # Lagged features for time-series context
    lag_volume_1 = lag(units_sold, 1),
    lag_volume_2 = lag(units_sold, 2)
  ) %>%
  ungroup()

# Report dimension before dropping NAs from lags
n_before <- nrow(model_ready_data)

# Remove rows containing NA from lagged features
model_ready_data <- model_ready_data %>%
  filter(!is.na(lag_volume_1) & !is.na(lag_volume_2))

n_after <- nrow(model_ready_data)
cat(sprintf("Engineered features created. Dropped %d rows containing initial NA lags. Final rows: %d\n", (n_before - n_after), n_after))

# Save the model-ready dataset
write.csv(model_ready_data, "data/processed/model_ready_data.csv", row.names = FALSE)
cat("Feature-engineered dataset saved to data/processed/model_ready_data.csv successfully!\n")
