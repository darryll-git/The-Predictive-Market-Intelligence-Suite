# scripts/03_eda_statistics.R

library(dplyr)
library(ggplot2)
library(tidyr)
library(lubridate)

# Ensure outputs directories exist
dir.create("outputs/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/reports", recursive = TRUE, showWarnings = FALSE)

cat("Starting exploratory data analysis and statistical validation...\n")

# Load cleaned data
processed_path <- "data/processed/cleaned_market_data.csv"
if (!file.exists(processed_path)) {
  stop("Cleaned dataset not found! Please run scripts/02_data_cleaning.R first.")
}

cleaned_data <- read.csv(processed_path, stringsAsFactors = TRUE)
cleaned_data$date <- as.Date(cleaned_data$date)

# 1. Summary Statistics Table
summary_stats <- cleaned_data %>%
  group_by(product_category) %>%
  summarize(
    total_volume = sum(units_sold),
    avg_price = mean(unit_price),
    avg_competitor_price = mean(competitor_price),
    total_marketing_spend = sum(marketing_spend),
    n_observations = n(),
    .groups = "drop"
  )

print(summary_stats)

# Save statistical summary to output folder
write.csv(summary_stats, "outputs/reports/summary_statistics.csv", row.names = FALSE)

# 2. ANOVA Test (Is there a significant difference in sales volume between regions?)
anova_region <- aov(units_sold ~ region, data = cleaned_data)
cat("\n--- ANOVA: Units Sold by Region ---\n")
print(summary(anova_region))

# 3. Correlation Analysis (Marketing & Pricing effects per Category)
cor_analysis <- cleaned_data %>%
  group_by(product_category) %>%
  summarize(
    price_correlation = cor(units_sold, unit_price, use = "complete.obs"),
    marketing_correlation = cor(units_sold, marketing_spend, use = "complete.obs"),
    .groups = "drop"
  )

cat("\n--- Correlations with Units Sold ---\n")
print(cor_analysis)
write.csv(cor_analysis, "outputs/reports/correlation_metrics.csv", row.names = FALSE)

# 4. Time-Series Diagnostics (ACF, PACF, ADF)
cat("\n--- Time-Series Diagnostics ---\n")

# We test the first product-region combination as a proxy for the tests
sample_ts <- cleaned_data %>% 
  filter(product_category == "Cardiology Devices", region == "North") %>%
  arrange(date)

# ADF Test on Unit Prices (Check for stationarity/inflation drift)
if (requireNamespace("tseries", quietly = TRUE)) {
  # suppressWarnings because adf.test can warn about p-value interpolations
  adf_res <- suppressWarnings(tseries::adf.test(sample_ts$unit_price))
  cat(sprintf("ADF Test for Unit Price (Cardiology, North): p-value = %.4f (non-stationary if > 0.05)\n", adf_res$p.value))
} else {
  cat("Package 'tseries' not installed. Skipping ADF test.\n")
}

# ACF / PACF for Sales Volume Memory Decay
png("outputs/figures/volume_acf_pacf.png", width = 800, height = 400, res = 100)
par(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
acf(sample_ts$units_sold, main = "ACF of Sales Volume", lag.max = 24)
pacf(sample_ts$units_sold, main = "PACF of Sales Volume", lag.max = 24)
dev.off()
cat("ACF and PACF plots saved to outputs/figures/volume_acf_pacf.png\n")

# 5. Generate Visualizations (Storytelling with Data principles)

# Visualization A: Regional Sales Volume Boxplot
p_box <- ggplot(cleaned_data, aes(x = region, y = units_sold, fill = region)) +
  geom_boxplot(alpha = 0.7, outlier.size = 1, outlier.colour = "grey50") +
  scale_fill_brewer(palette = "Blues") +
  labs(
    title = "Healthcare Product Sales Distribution by Geographic Region",
    subtitle = "Analysis showing variance and range across clinical markets",
    x = "Geographic Region",
    y = "Units Sold (Weekly)",
    caption = "Source: Healthcare Market Intelligence Suite"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 14),
    panel.grid.minor = element_blank()
  )

ggsave("outputs/figures/regional_sales_volume.png", plot = p_box, width = 8, height = 5, dpi = 300)

# Visualization B: Sales Volume Over Time (Category-wise)
monthly_trends <- cleaned_data %>%
  mutate(month_year = floor_date(date, "month")) %>%
  group_by(product_category, month_year) %>%
  summarize(monthly_units = sum(units_sold), .groups = "drop")

p_trend <- ggplot(monthly_trends, aes(x = month_year, y = monthly_units, color = product_category)) +
  geom_line(size = 1.2) +
  scale_color_brewer(palette = "Set2") +
  labs(
    title = "Historical Monthly Sales Trends by Product Category",
    subtitle = "Observed seasonal patterns and market trajectories (2022-2026)",
    x = "Timeline",
    y = "Total Monthly Units Sold",
    color = "Product Category"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave("outputs/figures/category_sales_trends.png", plot = p_trend, width = 10, height = 5, dpi = 300)

# Visualization C: Price vs Volume Elasticity Scatter plot
p_scatter <- ggplot(cleaned_data, aes(x = unit_price / competitor_price, y = units_sold, color = product_category)) +
  geom_point(alpha = 0.3) +
  geom_smooth(method = "lm", se = TRUE, color = "darkred", size = 1.2) +
  facet_wrap(~product_category, scales = "free") +
  scale_color_brewer(palette = "Set2") +
  labs(
    title = "Market Demand Price Elasticity",
    subtitle = "Relationship of sales volume relative to competitor pricing ratios (our price / competitor price)",
    x = "Relative Pricing Ratio (Values > 1 indicate we are more expensive)",
    y = "Units Sold (Weekly)",
    color = "Product Category"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "none",
    plot.title = element_text(face = "bold", size = 13),
    strip.text = element_text(face = "bold")
  )

ggsave("outputs/figures/price_elasticity.png", plot = p_scatter, width = 10, height = 6, dpi = 300)

cat("EDA and statistical graphics successfully generated under outputs/figures/.\n")
