FROM rocker/shiny:latest

# Install system dependencies if needed
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libcurl4-gnutls-dev \
        libssl-dev \
        libxml2-dev \
        libuv1-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . /srv/shiny-server/

# Set working directory
WORKDIR /srv/shiny-server/

# Install R dependencies directly
RUN R -e "install.packages(c('shiny', 'dplyr', 'tidyr', 'ggplot2', 'readr', 'lubridate', 'randomForest', 'plotly', 'bslib', 'DT', 'shinyWidgets'), repos='https://cloud.r-project.org')"

# Run data setup scripts to generate cleaned dataset
RUN Rscript scripts/01_data_ingestion.R && Rscript scripts/02_data_cleaning.R

# Expose Shiny default port
EXPOSE 3838

# Run Shiny app
CMD ["R", "-e", "shiny::runApp('dashboard/', host='0.0.0.0', port=3838)"]
