FROM rocker/shiny:latest

# Install system dependencies if needed
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libcurl4-gnutls-dev \
        libssl-dev \
        libxml2-dev && \
    rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . /srv/shiny-server/

# Set working directory
WORKDIR /srv/shiny-server/

# Install R packages via renv (if renv.lock exists) or install dependencies manually
RUN R -e "if (!requireNamespace('renv')) install.packages('renv', repos='https://cloud.r-project.org'); renv::restore(prompt=FALSE)"

# Expose Shiny default port
EXPOSE 3838

# Run Shiny app
CMD ["R", "-e", "shiny::runApp('dashboard/', host='0.0.0.0', port=3838)"]
