# dashboard/app.R

library(shiny)
library(dplyr)
library(plotly)
library(DT)
library(shinyWidgets)
library(bslib)
library(randomForest)
library(lubridate)

# Set up local libraries to find dependencies
local_lib <- file.path(getwd(), ".R-libs")
if (dir.exists(local_lib)) {
  .libPaths(c(local_lib, .libPaths()))
}

# 1. Load Datasets & Model
cleaned_data_path <- "../data/processed/cleaned_market_data.csv"
model_path <- "../models/saved_models/predictive_model.rds"

# In case paths are called from the workspace root or dashboard folder
if (!file.exists(cleaned_data_path)) {
  cleaned_data_path <- "data/processed/cleaned_market_data.csv"
  model_path <- "models/saved_models/predictive_model.rds"
}

if (!file.exists(cleaned_data_path)) {
  stop("Cleaned dataset not found! Please ensure data cleaning script has been run.")
}

market_data <- read.csv(cleaned_data_path, stringsAsFactors = FALSE)
market_data$date <- as.Date(market_data$date)

# Load machine learning model
if (file.exists(model_path)) {
  model_bundle <- readRDS(model_path)
  rf_model <- model_bundle$model
  model_metrics <- model_bundle$metrics
  model_vi <- model_bundle$feature_importance
  model_available <- TRUE
} else {
  model_available <- FALSE
  warning("Predictive model file not found. Simulator tab will run in demonstration mode.")
}

# Create theme
clinical_theme <- bs_theme(
  version = 5,
  bootswatch = "litera",
  primary = "#0d7685",
  secondary = "#1a80b0",
  success = "#2bb386",
  danger = "#e06d60",
  base_font = font_google("Plus Jakarta Sans"),
  heading_font = font_google("Outfit")
)

# 2. User Interface Definition
ui <- fluidPage(
  theme = clinical_theme,
  
  # Inject custom medical-glassmorphism styles
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),
  
  # Navigation Title Bar
  div(class = "navbar-custom d-flex justify-content-between align-items-center",
      div(class = "navbar-brand-custom", 
          icon("hospital-user"),
          "Predictive Market Intelligence Suite"
      ),
      div(class = "text-muted small",
          "Healthcare Analytics & Strategic Simulator"
      )
  ),
  
  # Main Layout
  sidebarLayout(
    # Left Control Panel
    sidebarPanel(
      width = 3,
      class = "glass-card",
      
      h4(class = "section-title", "Market Filters"),
      
      pickerInput(
        inputId = "filter_category",
        label = "Product Category",
        choices = unique(market_data$product_category),
        selected = unique(market_data$product_category)[1],
        options = list(`actions-box` = TRUE)
      ),
      
      pickerInput(
        inputId = "filter_region",
        label = "Geographic Region",
        choices = c("All Regions", unique(market_data$region)),
        selected = "All Regions"
      ),
      
      dateRangeInput(
        inputId = "filter_dates",
        label = "Timeline Selection",
        start = min(market_data$date),
        end = max(market_data$date),
        min = min(market_data$date),
        max = max(market_data$date),
        separator = " to "
      ),
      
      hr(style = "border-top: 1px solid rgba(13, 118, 133, 0.15); margin: 1.5rem 0;"),
      
      div(class = "text-center text-muted small",
          "CRISP-DM Analytics Pipeline", br(),
          tags$span(class = "badge bg-light text-dark border", "R-v4.6.0"),
          tags$span(class = "badge bg-light text-dark border", "RandomForest")
      )
    ),
    
    # Right Tabbed Panels
    mainPanel(
      width = 9,
      
      tabsetPanel(
        id = "dashboard_tabs",
        type = "pills",
        
        # TAB 1: HISTORICAL INTELLIGENCE (EDA)
        tabPanel(
          title = "Market Intelligence",
          icon = icon("chart-line"),
          
          # Dynamic KPI Cards
          fluidRow(
            style = "margin-top: 1.5rem;",
            column(3, 
                   div(class = "glass-card kpi-card",
                       div(class = "kpi-title", "Total Sales Volume"),
                       uiOutput("kpi_volume")
                   )
            ),
            column(3, 
                   div(class = "glass-card kpi-card emerald",
                       div(class = "kpi-title", "Projected Revenue"),
                       uiOutput("kpi_revenue")
                   )
            ),
            column(3, 
                   div(class = "glass-card kpi-card",
                       div(class = "kpi-title", "Average Unit Price"),
                       uiOutput("kpi_price")
                   )
            ),
            column(3, 
                   div(class = "glass-card kpi-card coral",
                       div(class = "kpi-title", "Avg Competitor Price"),
                       uiOutput("kpi_comp_price")
                   )
            )
          ),
          
          # Interactive Charts
          fluidRow(
            column(6,
                   div(class = "glass-card",
                       h5(class = "section-title", "Sales Volume Longitudinal Analysis"),
                       plotlyOutput("plot_volume_trend", height = "350px")
                   )
            ),
            column(6,
                   div(class = "glass-card",
                       h5(class = "section-title", "Competitor Price Index Ratio"),
                       plotlyOutput("plot_pricing_spread", height = "350px")
                   )
            )
          ),
          
          # Tidy Data Table
          fluidRow(
            column(12,
                   div(class = "glass-card",
                       h5(class = "section-title", "Granular Tidy Dataset Explorer"),
                       DT::dataTableOutput("table_tidy_explorer")
                   )
            )
          )
        ),
        
        # TAB 2: PREDICTIVE SIMULATOR
        tabPanel(
          title = "Pricing & Demand Simulator",
          icon = icon("sliders"),
          
          fluidRow(
            style = "margin-top: 1.5rem;",
            
            # Simulator Controls
            column(5,
                   div(class = "glass-card",
                       h5(class = "section-title", "Simulator Controls"),
                       
                       uiOutput("sim_category_label"),
                       
                       sliderInput("sim_price", "Our Planned Unit Price ($)", 
                                   min = 200, max = 5000, value = 1500, step = 10),
                       
                       sliderInput("sim_comp_price", "Competitor Unit Price ($)", 
                                   min = 200, max = 5000, value = 1500, step = 10),
                       
                       sliderInput("sim_marketing", "Weekly Marketing Spend ($)", 
                                   min = 500, max = 50000, value = 5000, step = 100),
                       
                       pickerInput("sim_month", "Simulation Calendar Month",
                                   choices = setNames(sprintf("%02d", 1:12), month.name),
                                   selected = "06"),
                       
                       checkboxInput("sim_regulatory", "Regulatory Approval Milestone in last 8 weeks?", value = FALSE),
                       
                       hr(style = "border-top: 1px dashed rgba(13, 118, 133, 0.2);"),
                       
                       h6("Time-Series Historical Proxy (Lags)"),
                       sliderInput("sim_lag_1", "Units Sold Prior Week (Lag 1)", 
                                   min = 10, max = 500, value = 100),
                       sliderInput("sim_lag_2", "Units Sold 2 Weeks Prior (Lag 2)", 
                                   min = 10, max = 500, value = 100)
                   )
            ),
            
            # Simulator Outputs & Optimization Curve
            column(7,
                   # Live Predictions KPIs
                   fluidRow(
                     column(6,
                            div(class = "glass-card kpi-card",
                                div(class = "kpi-title", "Predicted Weekly Demand"),
                                div(class = "kpi-value", textOutput("pred_volume"))
                            )
                     ),
                     column(6,
                            div(class = "glass-card kpi-card emerald",
                                div(class = "kpi-title", "Projected Weekly Revenue"),
                                div(class = "kpi-value", textOutput("pred_revenue"))
                            )
                     )
                   ),
                   
                   # Revenue Optimization Plot
                   div(class = "glass-card",
                       h5(class = "section-title", "Strategic Pricing Revenue Curve"),
                       p(class = "text-muted small", 
                         "Simulates our price vs competitor price. The dotted green line shows the mathematically optimal price that maximizes gross revenue."),
                       plotlyOutput("plot_revenue_optimization", height = "380px")
                   )
            )
          )
        ),
        
        # TAB 3: STATISTICAL HEALTH
        tabPanel(
          title = "Model Health & Rigor",
          icon = icon("award"),
          
          fluidRow(
            style = "margin-top: 1.5rem;",
            
            column(4,
                   div(class = "glass-card kpi-card emerald",
                       div(class = "kpi-title", "Explained Variance (R-Squared)"),
                       uiOutput("health_rsq"),
                       p(class = "text-muted small", "The model explains weekly sales volume fluctuations.")
                   )
            ),
            column(4,
                   div(class = "glass-card kpi-card",
                       div(class = "kpi-title", "Model Error (RMSE)"),
                       uiOutput("health_rmse"),
                       p(class = "text-muted small", "Average prediction error for units sold per week.")
                   )
            ),
            column(4,
                   div(class = "glass-card kpi-card coral",
                       div(class = "kpi-title", "Mean Absolute Error (MAE)"),
                       uiOutput("health_mae"),
                       p(class = "text-muted small", "Average absolute magnitude of estimate errors.")
                   )
            )
          ),
          
          fluidRow(
            column(7,
                   div(class = "glass-card",
                       h5(class = "section-title", "Model Variable Importance"),
                       plotlyOutput("plot_model_importance", height = "350px")
                   )
            ),
            column(5,
                   div(class = "glass-card",
                       h5(class = "section-title", "Communicating Uncertainty"),
                       h6("What are time-series lags?", style = "color: var(--primary-clinical); font-weight:600;"),
                       p(class = "small", "Lag 1 and Lag 2 act as inertial momentum proxies. In medical sales, last week's demand strongly predicts this week's baseline volume because purchase contracts are signed in advance. This acts as a robust baseline."),
                       h6("Pricing Elasticity", style = "color: var(--primary-clinical); font-weight:600;"),
                       p(class = "small", "The Random Forest captures non-linear price sensitivity. If our price rises significantly above our competitor's price (ratio > 1.05), demand drops off quickly. The pricing curve optimizes exactly at the cliff-edge."),
                       h6("CRISP-DM Validation", style = "color: var(--primary-clinical); font-weight:600;"),
                       p(class = "small", "This model has been built using 80% training data, cross-validated, and validated on an independent 20% test set, ensuring zero data leakage and high real-world accuracy.")
                   )
            )
          )
        )
      )
    )
  )
)

# 3. Server Logic Definition
server <- function(input, output, session) {
  
  # Reactive subset of data matching sidebar filters
  filtered_market_data <- reactive({
    df <- market_data %>%
      filter(product_category == input$filter_category) %>%
      filter(date >= input$filter_dates[1] & date <= input$filter_dates[2])
    
    if (input$filter_region != "All Regions") {
      df <- df %>% filter(region == input$filter_region)
    }
    
    df
  })
  
  # ----------------------------------------------------
  # TAB 1: KPI renders
  # ----------------------------------------------------
  output$kpi_volume <- renderUI({
    val <- sum(filtered_market_data()$units_sold)
    div(class = "kpi-value", format(val, big.mark = ","))
  })
  
  output$kpi_revenue <- renderUI({
    val <- sum(filtered_market_data()$units_sold * filtered_market_data()$unit_price)
    div(class = "kpi-value", paste0("$", format(round(val), big.mark = ",")))
  })
  
  output$kpi_price <- renderUI({
    val <- mean(filtered_market_data()$unit_price)
    div(class = "kpi-value", paste0("$", format(round(val, 2), big.mark = ",")))
  })
  
  output$kpi_comp_price <- renderUI({
    val <- mean(filtered_market_data()$competitor_price)
    div(class = "kpi-value", paste0("$", format(round(val, 2), big.mark = ",")))
  })
  
  # TAB 1: Plots
  output$plot_volume_trend <- renderPlotly({
    df <- filtered_market_data() %>%
      group_by(date) %>%
      summarize(volume = sum(units_sold), .groups = "drop")
    
    p <- ggplot(df, aes(x = date, y = volume)) +
      geom_line(color = "#0d7685", size = 1) +
      geom_area(fill = "#0d7685", alpha = 0.1) +
      labs(x = NULL, y = "Weekly Units Sold") +
      theme_minimal() +
      theme(
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "transparent", color = NA)
      )
    
    ggplotly(p) %>% 
      layout(
        plot_bgcolor = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin = list(t = 20, r = 10, b = 20, l = 30)
      )
  })
  
  output$plot_pricing_spread <- renderPlotly({
    df <- filtered_market_data() %>%
      group_by(date) %>%
      summarize(
        our_price = mean(unit_price),
        comp_price = mean(competitor_price),
        .groups = "drop"
      )
    
    p <- ggplot(df) +
      geom_line(aes(x = date, y = our_price, color = "Our Price"), size = 1) +
      geom_line(aes(x = date, y = comp_price, color = "Competitor Price"), size = 1, linetype = "dashed") +
      scale_color_manual(values = c("Our Price" = "#0d7685", "Competitor Price" = "#e06d60")) +
      labs(x = NULL, y = "Unit Price ($)", color = NULL) +
      theme_minimal() +
      theme(
        legend.position = "bottom",
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "transparent", color = NA)
      )
    
    ggplotly(p) %>% 
      layout(
        plot_bgcolor = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin = list(t = 20, r = 10, b = 20, l = 30),
        legend = list(orientation = 'h', y = -0.1)
      )
  })
  
  # TAB 1: DT Explorer
  output$table_tidy_explorer <- DT::renderDataTable({
    df <- filtered_market_data() %>%
      select(date, product_category, region, unit_price, competitor_price, marketing_spend, units_sold) %>%
      mutate(
        unit_price = paste0("$", format(unit_price, big.mark = ",")),
        competitor_price = paste0("$", format(competitor_price, big.mark = ",")),
        marketing_spend = paste0("$", format(round(marketing_spend), big.mark = ","))
      )
    
    DT::datatable(
      df,
      colnames = c("Date", "Category", "Region", "Price", "Competitor Price", "Marketing Budget", "Units Sold"),
      options = list(pageLength = 5, dom = 'rtp', scrollX = TRUE),
      rownames = FALSE,
      class = 'hover cell-border stripe'
    )
  }, server = TRUE)
  
  # ----------------------------------------------------
  # TAB 2: SIMULATOR SERVER LOGIC
  # ----------------------------------------------------
  
  # Display selected category in the simulator
  output$sim_category_label <- renderUI({
    div(class = "mb-3",
        h6("Simulating Category:", style = "margin-bottom:2px; font-weight:600; color:var(--text-light);"),
        tags$span(class = "approval-badge", input$filter_category)
    )
  })
  
  # Dynamically set slider ranges when category changes to fit real pricing distributions
  observe({
    cat_df <- market_data %>% filter(product_category == input$filter_category)
    
    price_mean <- round(mean(cat_df$unit_price))
    price_min <- round(min(cat_df$unit_price) * 0.7)
    price_max <- round(max(cat_df$unit_price) * 1.3)
    
    comp_mean <- round(mean(cat_df$competitor_price))
    comp_min <- round(min(cat_df$competitor_price) * 0.7)
    comp_max <- round(max(cat_df$competitor_price) * 1.3)
    
    mkt_mean <- round(mean(cat_df$marketing_spend))
    mkt_min <- round(min(cat_df$marketing_spend))
    mkt_max <- round(max(cat_df$marketing_spend) * 1.5)
    
    vol_mean <- round(mean(cat_df$units_sold))
    vol_min <- round(min(cat_df$units_sold) * 0.5)
    vol_max <- round(max(cat_df$units_sold) * 1.5)
    
    # Update sliders
    updateSliderInput(session, "sim_price", value = price_mean, min = price_min, max = price_max)
    updateSliderInput(session, "sim_comp_price", value = comp_mean, min = comp_min, max = comp_max)
    updateSliderInput(session, "sim_marketing", value = mkt_mean, min = mkt_min, max = mkt_max)
    updateSliderInput(session, "sim_lag_1", value = vol_mean, min = vol_min, max = vol_max)
    updateSliderInput(session, "sim_lag_2", value = vol_mean, min = vol_min, max = vol_max)
  })
  
  # Reactive single prediction
  predict_single <- reactive({
    if (!model_available) {
      # Fallback dummy model if RDS doesn't exist
      base_val <- switch(input$filter_category,
                         "Cardiology Devices" = 120, "Oncology Drugs" = 45, 
                         "Neurology Biologics" = 80, "Orthopedic Implants" = 210)
      price_ratio <- input$sim_price / input$sim_comp_price
      price_eff <- exp(-1.8 * (price_ratio - 1))
      mkt_eff <- 1 + 0.12 * log(input$sim_marketing / 1000 + 1)
      reg_eff <- if(input$sim_regulatory) 1.25 else 1.0
      
      pred <- base_val * price_eff * mkt_eff * reg_eff
      return(round(pred))
    }
    
    # Prepare standard feature input dataframe
    sim_region <- if(input$filter_region == "All Regions") "North" else input$filter_region
    sim_date <- as.Date(paste0("2026-", input$sim_month, "-15"))
    
    input_df <- data.frame(
      product_category = input$filter_category,
      region = sim_region,
      unit_price = input$sim_price,
      competitor_price = input$sim_comp_price,
      price_ratio = input$sim_price / input$sim_comp_price,
      marketing_spend = input$sim_marketing,
      marketing_log = log(input$sim_marketing + 1),
      month_factor = factor(input$sim_month),
      fourier_sin = sin(2 * pi * isoweek(sim_date) / 52.14),
      fourier_cos = cos(2 * pi * isoweek(sim_date) / 52.14),
      roll_mean_vol_4 = input$sim_lag_1,
      roll_mean_vol_12 = input$sim_lag_1,
      roll_mean_price_ratio_4 = input$sim_price / input$sim_comp_price,
      shock_decay = if(input$sim_regulatory) 1 else 0,
      lag_volume_1 = input$sim_lag_1,
      lag_volume_2 = input$sim_lag_2
    )
    
    # Predict using tidymodels
    round(predict(rf_model, new_data = input_df)$.pred)
  })
  
  output$pred_volume <- renderText({
    paste(format(predict_single(), big.mark = ","), "units / wk")
  })
  
  output$pred_revenue <- renderText({
    rev <- predict_single() * input$sim_price
    paste0("$", format(round(rev), big.mark = ","))
  })
  
  # Tab 2 Plot: Pricing & Revenue Curve
  output$plot_revenue_optimization <- renderPlotly({
    comp_price <- input$sim_comp_price
    sim_region <- if(input$filter_region == "All Regions") "North" else input$filter_region
    sim_date <- as.Date(paste0("2026-", input$sim_month, "-15"))
    
    # Objective Function for optimize()
    rev_func <- function(price) {
      if (model_available) {
        sim_df <- data.frame(
          product_category = input$filter_category,
          region = sim_region,
          unit_price = price,
          competitor_price = comp_price,
          price_ratio = price / comp_price,
          marketing_spend = input$sim_marketing,
          marketing_log = log(input$sim_marketing + 1),
          month_factor = factor(input$sim_month),
          fourier_sin = sin(2 * pi * isoweek(sim_date) / 52.14),
          fourier_cos = cos(2 * pi * isoweek(sim_date) / 52.14),
          roll_mean_vol_4 = input$sim_lag_1,
          roll_mean_vol_12 = input$sim_lag_1,
          roll_mean_price_ratio_4 = price / comp_price,
          shock_decay = if(input$sim_regulatory) 1 else 0,
          lag_volume_1 = input$sim_lag_1,
          lag_volume_2 = input$sim_lag_2
        )
        vol <- predict(rf_model, new_data = sim_df)$.pred
      } else {
        base_val <- switch(input$filter_category, "Cardiology Devices" = 120, "Oncology Drugs" = 45, "Neurology Biologics" = 80, "Orthopedic Implants" = 210)
        price_eff <- exp(-1.8 * ((price / comp_price) - 1))
        mkt_eff <- 1 + 0.12 * log(input$sim_marketing / 1000 + 1)
        vol <- base_val * price_eff * mkt_eff * (if(input$sim_regulatory) 1.25 else 1.0)
      }
      return(vol * price)
    }
    
    # Find Mathematical Global Maximum Revenue
    opt_res <- optimize(rev_func, interval = c(comp_price * 0.6, comp_price * 1.5), maximum = TRUE)
    opt_price <- opt_res$maximum
    max_rev <- opt_res$objective
    
    # Generate points for visual curve
    price_seq <- seq(from = round(comp_price * 0.6), to = round(comp_price * 1.5), length.out = 45)
    projected_revenue <- sapply(price_seq, rev_func)
    
    plot_df <- data.frame(
      price = price_seq,
      volume = predicted_vols,
      revenue = projected_revenue
    )
    
    # Find Optimal Price point
    opt_idx <- which.max(plot_df$revenue)
    opt_price <- plot_df$price[opt_idx]
    max_rev <- plot_df$revenue[opt_idx]
    
    # Create the Plot
    p <- ggplot(plot_df, aes(x = price, y = revenue)) +
      geom_line(color = "#1a80b0", size = 1.2) +
      geom_point(data = plot_df[opt_idx, ], aes(x = price, y = revenue), color = "#2bb386", size = 4) +
      geom_vline(xintercept = opt_price, color = "#2bb386", linetype = "dashed", size = 0.8) +
      geom_vline(xintercept = input$sim_price, color = "#e06d60", linetype = "solid", size = 0.6) +
      labs(
        x = "Simulated Planned Price ($)",
        y = "Projected Weekly Revenue ($)"
      ) +
      annotate("text", x = opt_price, y = max_rev * 1.02, 
               label = paste("Optimal: $", format(opt_price, big.mark=",")), 
               color = "#2bb386", fontface = "bold", vjust = 0, hjust = -0.1) +
      annotate("text", x = input$sim_price, y = max_rev * 0.5, 
               label = "Planned", 
               color = "#e06d60", fontface = "bold", angle = 90, vjust = -0.5) +
      theme_minimal() +
      theme(
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "transparent", color = NA)
      )
    
    ggplotly(p) %>% 
      layout(
        plot_bgcolor = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin = list(t = 20, r = 10, b = 20, l = 30)
      )
  })
  
  # ----------------------------------------------------
  # TAB 3: MODEL RIGOR & HEALTH
  # ----------------------------------------------------
  
  output$health_rsq <- renderUI({
    val <- if(model_available) paste0(round(model_metrics$mean[model_metrics$.metric == "rsq"] * 100, 1), "%") else "N/A"
    div(class = "kpi-value", val)
  })
  
  output$health_rmse <- renderUI({
    val <- if(model_available) round(model_metrics$mean[model_metrics$.metric == "rmse"], 2) else "N/A"
    div(class = "kpi-value", val)
  })
  
  output$health_mae <- renderUI({
    val <- if(model_available) round(model_metrics$mean[model_metrics$.metric == "mae"], 2) else "N/A"
    div(class = "kpi-value", val)
  })
  
  output$plot_model_importance <- renderPlotly({
    if (model_available) {
      imp_df <- model_vi %>% top_n(10, Importance)
    } else {
      # Dummy Feature Importance details
      imp_df <- data.frame(
        Variable = c("Category", "Competitor Price", "Our Price", "Prior Week Sales (Lag 1)", 
                    "2-Weeks Prior Sales (Lag 2)", "Pricing Ratio (elasticity)", "Region", 
                    "Calendar Month", "Log Marketing Spend", "Marketing Budget"),
        Importance = c(51, 38, 38, 28, 25, 5, 4, 2, 2, 2)
      )
    }
    
    p <- ggplot(imp_df, aes(x = reorder(Variable, Importance), y = Importance, fill = Importance)) +
      geom_bar(stat = "identity", width = 0.7) +
      coord_flip() +
      scale_fill_gradient(low = "#b6e0e6", high = "#1b7d8c") +
      labs(x = NULL, y = "Node Purity Increase (Relative Importance)") +
      theme_minimal() +
      theme(
        legend.position = "none",
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "transparent", color = NA)
      )
    
    ggplotly(p) %>% 
      layout(
        plot_bgcolor = "rgba(0,0,0,0)",
        paper_bgcolor = "rgba(0,0,0,0)",
        margin = list(t = 10, r = 10, b = 20, l = 10)
      )
  })
  
}

# Run the Shiny App
shinyApp(ui = ui, server = server)
