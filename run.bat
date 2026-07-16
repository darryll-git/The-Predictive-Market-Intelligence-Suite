rem run.bat

@echo off
rem ========================================================
rem LOCAL EXECUTION SCRIPT
rem This script runs the entire data pipeline locally and 
rem launches the dashboard on your local machine.
rem For cloud deployment, use deploy.bat instead.
rem ========================================================
rem Auto-detect R installation and add to PATH
for /d %%i in ("C:\Program Files\R\R-*") do set "R_HOME=%%i"
set "PATH=%R_HOME%\bin\x64;%R_HOME%\bin;%PATH%"

rem Set the local R library path for all R processes in this script
set R_LIBS_USER=%CD%\.R-libs

rem Run setup script to restore renv environment
Rscript setup.R

rem Run data scripts to generate the cleaned dataset and train the model
Rscript scripts\01_data_ingestion.R
Rscript scripts\02_data_cleaning.R
Rscript scripts\03_eda_statistics.R
Rscript scripts\04_feature_eng.R
Rscript scripts\05_model_training.R

rem Launch Shiny app
R -e "shiny::runApp('dashboard/')"

echo Shiny app should be running at http://localhost:3838
pause
