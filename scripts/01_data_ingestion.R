# scripts/01_data_ingestion.R

# Setup directories
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

cat("Generating realistic synthetic healthcare market dataset...\n")

set.seed(42)  # For reproducibility

# Define dimensions
weeks <- seq(from = as.Date("2022-01-01"), to = as.Date("2026-04-30"), by = "week")
n_weeks <- length(weeks)

categories <- c("Cardiology Devices", "Oncology Drugs", "Neurology Biologics", "Orthopedic Implants")
regions <- c("North", "South", "East", "West")

# Base parameters per category
base_prices <- c("Cardiology Devices" = 1500, "Oncology Drugs" = 3500, "Neurology Biologics" = 2200, "Orthopedic Implants" = 850)
base_volumes <- c("Cardiology Devices" = 120, "Oncology Drugs" = 45, "Neurology Biologics" = 80, "Orthopedic Implants" = 210)

# Generate raw grid
raw_grid <- expand.grid(
  date = weeks,
  product_category = categories,
  region = regions
)

n_rows <- nrow(raw_grid)

# Add numeric and text details
# Attempt to fetch real CPI inflation data from FRED
api_success <- FALSE
tryCatch({
  if (requireNamespace("quantmod", quietly = TRUE)) {
    # Fetch Consumer Price Index for All Urban Consumers (CPIAUCSL)
    cpi_xts <- suppressWarnings(quantmod::getSymbols("CPIAUCSL", src = "FRED", auto.assign = FALSE))
    cpi_df <- data.frame(date = zoo::index(cpi_xts), cpi = as.numeric(cpi_xts))
    
    # Filter to relevant timeline (start 1 year prior to get YoY)
    cpi_df <- cpi_df[cpi_df$date >= as.Date("2021-01-01"), ]
    
    # Calculate Year-over-Year (YoY) inflation rate
    cpi_df$inflation_rate <- NA
    for (j in 13:nrow(cpi_df)) {
      cpi_df$inflation_rate[j] <- (cpi_df$cpi[j] - cpi_df$cpi[j-12]) / cpi_df$cpi[j-12] * 100
    }
    cpi_df$inflation_rate[is.na(cpi_df$inflation_rate)] <- 2.5
    
    # Interpolate monthly CPI to our weekly grid
    cpi_spline <- spline(x = as.numeric(cpi_df$date), y = cpi_df$inflation_rate, xout = as.numeric(weeks))
    
    date_match_idx <- match(raw_grid$date, weeks)
    raw_grid$inflation_rate <- pmax(1.0, pmin(6.0, cpi_spline$y[date_match_idx]))
    
    api_success <- TRUE
    cat("Successfully fetched and integrated real-world macroeconomic CPI data from FRED.\n")
  } else {
    cat("Package 'quantmod' not installed. Falling back to simulated inflation.\n")
  }
}, error = function(e) {
  cat("Warning: Could not fetch FRED CPI data (", e$message, "). Falling back to simulated inflation.\n", sep="")
})

if (!api_success) {
  # Fallback to mathematical simulation
  raw_grid$inflation_rate <- 2.5 + cumsum(rnorm(n_weeks, 0, 0.05))[as.numeric(raw_grid$date - min(raw_grid$date))/7 + 1]
  # limit inflation between 1% and 6%
  raw_grid$inflation_rate <- pmax(1.0, pmin(6.0, raw_grid$inflation_rate))
}

# Generate prices with minor upward trend
raw_grid$unit_price <- sapply(1:n_rows, function(i) {
  cat_i <- as.character(raw_grid$product_category[i])
  base <- base_prices[cat_i]
  # trend over time
  t_ratio <- as.numeric(raw_grid$date[i] - min(weeks)) / 1500
  price <- base * (1 + t_ratio * 0.08) + rnorm(1, 0, base * 0.03)
  round(price, 2)
})

# Generate competitor prices
raw_grid$competitor_price <- sapply(1:n_rows, function(i) {
  u_price <- raw_grid$unit_price[i]
  # competitor price is unit_price plus/minus a random percent (within 10%)
  comp_price <- u_price * (1 + runif(1, -0.10, 0.08))
  round(comp_price, 2)
})

# Generate marketing spend
raw_grid$marketing_spend <- rlnorm(n_rows, meanlog = 8.5, sdlog = 0.8) # ~$2,000 to ~$25,000
raw_grid$marketing_spend <- round(raw_grid$marketing_spend, 2)

# Generate occasional regulatory approvals (binary shock)
# 1.5% chance per week per product category. Shocks are national, so if approved, it's approved in all regions on that date.
reg_shocks <- expand.grid(date = weeks, product_category = categories)
reg_shocks$regulatory_approval <- rbinom(nrow(reg_shocks), 1, 0.015)

# Merge regulatory approvals back into grid
raw_grid <- merge(raw_grid, reg_shocks, by = c("date", "product_category"), all.x = TRUE)

# Calculate dynamic Units Sold (Volume) incorporating:
# 1. Base category demand
# 2. Regional multipliers (North +15%, South -10%, East +5%, West -10%)
# 3. Price elasticity (if our price > competitor, demand drops; if our price < competitor, demand rises)
# 4. Marketing spend (log-linear effect: more marketing = more sales)
# 5. Seasonal factor (sine wave: peak in December/January, dip in June/July)
# 6. Regulatory approval shock (positive sales bump that decays over 8 weeks)

regional_multipliers <- c("North" = 1.15, "South" = 0.90, "East" = 1.05, "West" = 0.90)

# Pre-calculate weeks since last regulatory approval per category to inject realistic decay curves
raw_grid <- raw_grid[order(raw_grid$product_category, raw_grid$region, raw_grid$date), ]

# Compute a decay helper
raw_grid$weeks_since_approval <- Inf
for (cat in categories) {
  for (reg in regions) {
    idx <- which(raw_grid$product_category == cat & raw_grid$region == reg)
    app_dates <- raw_grid$date[idx[which(raw_grid$regulatory_approval[idx] == 1)]]
    if (length(app_dates) > 0) {
      for (i in idx) {
        past_apps <- app_dates[app_dates <= raw_grid$date[i]]
        if (length(past_apps) > 0) {
          raw_grid$weeks_since_approval[i] <- as.numeric(raw_grid$date[i] - max(past_apps)) / 7
        }
      }
    }
  }
}

# Calculate the actual volumes sold
raw_grid$units_sold <- sapply(1:nrow(raw_grid), function(i) {
  cat_i <- as.character(raw_grid$product_category[i])
  reg_i <- as.character(raw_grid$region[i])
  
  # Base volume
  vol <- base_volumes[cat_i]
  
  # Region multiplier
  vol <- vol * regional_multipliers[reg_i]
  
  # Price elasticity (coefficient of -1.5 on relative price diff)
  price_ratio <- raw_grid$unit_price[i] / raw_grid$competitor_price[i]
  price_effect <- exp(-1.8 * (price_ratio - 1))
  vol <- vol * price_effect
  
  # Marketing spend effect (diminishing returns, log scale)
  mkt_effect <- 1 + 0.12 * log(raw_grid$marketing_spend[i] / 1000 + 1)
  vol <- vol * mkt_effect
  
  # Seasonality (peaks in Jan/Dec, dips in July)
  month_num <- as.numeric(format(raw_grid$date[i], "%m"))
  season_effect <- 1 + 0.08 * cos(2 * pi * (month_num - 1) / 12)
  vol <- vol * season_effect
  
  # Regulatory Shock (decays: +35% in week 0, down to 0 over 10 weeks)
  weeks_since <- raw_grid$weeks_since_approval[i]
  if (weeks_since <= 10) {
    shock_effect <- 1 + 0.35 * exp(-weeks_since / 4)
    vol <- vol * shock_effect
  }
  
  # Add normal multiplicative error and round to integer
  vol <- vol * rlnorm(1, meanlog = 0, sdlog = 0.06)
  
  pmax(5, round(vol))
})

# Clean up temporary column
raw_grid$weeks_since_approval <- NULL

# Inject 1.5% random missingness in raw unit_price and units_sold to simulate real data cleaning requirements
missing_price_idx <- sample(1:nrow(raw_grid), round(nrow(raw_grid) * 0.015))
missing_vol_idx <- sample(1:nrow(raw_grid), round(nrow(raw_grid) * 0.015))

raw_grid$unit_price[missing_price_idx] <- NA
raw_grid$units_sold[missing_vol_idx] <- NA

# Save as raw CSV
write.csv(raw_grid, "data/raw/healthcare_market_data.csv", row.names = FALSE)
cat("Raw dataset saved to data/raw/healthcare_market_data.csv successfully! Total rows:", nrow(raw_grid), "\n")
