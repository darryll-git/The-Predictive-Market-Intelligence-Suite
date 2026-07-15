# scripts/02_data_cleaning.R

library(dplyr)
library(tidyr)
library(lubridate)

# Ensure processed folder exists
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

cat("Starting data cleaning pipeline...\n")

# Load raw data
raw_path <- "data/raw/healthcare_market_data.csv"
if (!file.exists(raw_path)) {
  stop("Raw dataset not found! Please run scripts/01_data_ingestion.R first.")
}

raw_data <- read.csv(raw_path, stringsAsFactors = FALSE)
cat(sprintf("Loaded raw dataset. Rows: %d, Columns: %d\n", nrow(raw_data), ncol(raw_data)))

# 1. Parse dates and convert characters to factors
cleaned_data <- raw_data %>%
  mutate(
    date = as.Date(date),
    product_category = factor(product_category),
    region = factor(region)
  )

# Report missing values
missing_price <- sum(is.na(cleaned_data$unit_price))
missing_vol <- sum(is.na(cleaned_data$units_sold))
cat(sprintf("Missing values detected - Unit Price: %d, Units Sold: %d\n", missing_price, missing_vol))

# 2. Impute missing prices
# Since price changes slowly, we'll group by category and region, sort by date,
# and use tidyr::fill to perform a last-observation-carried-forward (LOCF) and next-observation-carried-backward (NOCB)
cleaned_data <- cleaned_data %>%
  group_by(product_category, region) %>%
  arrange(date) %>%
  fill(unit_price, .direction = "downup") %>%
  ungroup()

# 3. Impute missing volume (units_sold)
# Since sales volume fluctuates with seasonal cosine waves, we use linear interpolation 
# to preserve the structural shape instead of flattening variance with the median.
cleaned_data <- cleaned_data %>%
  group_by(product_category, region) %>%
  arrange(date) %>%
  mutate(
    units_sold = round(zoo::na.approx(units_sold, na.rm = FALSE, rule = 2))
  ) %>%
  ungroup()

# Verify no remaining missing values in core columns
any_nas <- any(is.na(cleaned_data$unit_price)) || any(is.na(cleaned_data$units_sold))
if (any_nas) {
  warning("There are still missing values in the dataset!")
} else {
  cat("All missing values successfully imputed.\n")
}

# 4. Standardize column order and sorting
cleaned_data <- cleaned_data %>%
  arrange(product_category, region, date)

# Save cleaned dataset
write.csv(cleaned_data, "data/processed/cleaned_market_data.csv", row.names = FALSE)
cat("Cleaned dataset saved successfully to data/processed/cleaned_market_data.csv\n")
