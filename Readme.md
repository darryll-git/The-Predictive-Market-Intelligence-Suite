# The Predictive Market Intelligence Suite

**Focus:** Statistical Theory, Predictive Modeling, and Strategic Communication  
**Tech Stack:** R, Shiny, Tidyverse, Tidymodels/Caret  
**Methodology:** CRISP-DM 

## 📌 Project Overview
The Predictive Market Intelligence Suite is an end-to-end R-based analytics project designed to perform a deep-dive analysis of large-scale datasets, specifically focusing on predicting future outcomes in healthcare market trends. 

This project goes beyond basic analysis by rigorously applying established statistical frameworks and prioritizing actionable visual storytelling for non-technical stakeholders. 

---

## 🔄 Project Flow & Methodology

This project is executed in four distinct phases, bridging raw data ingestion with high-fidelity, interactive deployment.

### Phase 1: Methodology & Data Cleaning
* **Lifecycle:** Guided by the **CRISP-DM** (Cross-Industry Standard Process for Data Mining) framework to ensure business understanding drives the data approach.
* **Execution:** Utilizes principles from *R for Data Science* and strictly adheres to **Tidy Data** standards. Raw market data is ingested, structurally normalized, and cleaned to handle missing values and outliers seamlessly.

### Phase 2: Statistical Foundations & EDA
* **Exploratory Data Analysis (EDA):** Grounded in *Introduction to Statistical Learning (ISL)* and *The Analytics Edge*. 
* **Validation:** Code and logic are continuously validated through an "interactive practice" approach, ensuring robust, error-free pipelines.
* **Communication of Uncertainty:** Applies concepts from *Naked Statistics* to ensure that variance, confidence intervals, and statistical significance are translated into plain, understandable business language rather than just raw p-values.

### Phase 3: Predictive Modeling
* **Framework:** Built heavily on the techniques outlined in *Applied Predictive Modeling*. Models (e.g., Random Forests, Gradient Boosting, or Logistic Regression depending on the target variable) are trained, cross-validated, and tuned.
* **Data Handling:** Ensures data leakage prevention, proper train/test splitting, and feature engineering aligned with the Google Data Analytics Professional Certificate best practices.

### Phase 4: Visual Storytelling & Deployment
* **High-Fidelity Dashboard:** The final output is an interactive dashboard (built via Shiny/Flexdashboard) that allows stakeholders to explore predictions dynamically.
* **Visualization Design:** Complex visualizations are sourced from the R Graph Gallery, but their design—color palettes, annotations, and decluttering—is strictly governed by the principles of *Storytelling with Data*. The goal is to make insights immediately actionable.

---

## 📂 Project Directory Structure

```\n\n## Build & Run Instructions\n\n### Prerequisites\n- R (>= 4.0) installed on your system\n- Docker installed (optional, for containerized run)\n\n### Local Development (R environment)\n1. Open a terminal in the project root.\n2. Run the setup script to install required R packages and restore the renv environment:\n   ```bat\n   Rscript setup.R\n   ```\n3. Launch the Shiny dashboard:\n   ```bat\n   R -e "shiny::runApp('dashboard/')"\n   ```\n   The app will be available at `http://localhost:3838`.\n\n### Docker Container (optional)\n1. Build the Docker image:\n   ```bash\n   docker build -t predictive-suite .\n   ```\n2. Start the container using Docker Compose (exposes port 3838):\n   ```bash\n   docker-compose up\n   ```\n   Access the dashboard at `http://localhost:3838`.\n\n### Windows Shortcut Script\n- A `run.bat` script has been added to the project root. Double‑click it to automatically run the setup script and launch the Shiny app.\n\n---\n*For further customization or deployment, refer to the Dockerfile and docker‑compose configuration.*text
predictive-market-intelligence/
│
├── data/
│   ├── raw/                  # Immutable original market datasets
│   ├── processed/            # Cleaned, tidy datasets ready for modeling
│   └── dictionary.md         # Data dictionary detailing variable definitions
│
├── scripts/
│   ├── 01_data_ingestion.R   # Scripts for API pulls or CSV loading
│   ├── 02_data_cleaning.R    # Tidyverse data wrangling pipelines
│   ├── 03_eda_statistics.R   # Statistical summaries and EDA visualizations
│   └── 04_feature_eng.R      # Feature creation and scaling
│
├── models/
│   ├── model_training.R      # Caret/Tidymodels training scripts
│   ├── model_evaluation.R    # Cross-validation and performance metrics
│   └── saved_models/         # Serialized model objects (.rds)
│
├── dashboard/
│   ├── app.R                 # Main Shiny application script
│   ├── ui.R                  # User Interface layout (if separated)
│   ├── server.R              # Server logic (if separated)
│   └── www/                  # CSS, images, and custom assets for styling
│
├── outputs/
│   ├── figures/              # High-res static plots for reports
│   └── reports/              # RMarkdown/Quarto generated analytical reports
│
├── .gitignore                # Files to ignore (e.g., raw data, .Rhistory)
├── predictive_suite.Rproj    # RStudio Project file
└── README.md                 # Project documentation