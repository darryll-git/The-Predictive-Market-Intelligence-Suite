rem run.bat

@echo off

rem Auto-detect R installation and add to PATH
for /d %%i in ("C:\Program Files\R\R-*") do set "R_HOME=%%i"
set "PATH=%R_HOME%\bin\x64;%R_HOME%\bin;%PATH%"

rem Set the local R library path for all R processes in this script
set R_LIBS_USER=%CD%\.R-libs

rem Run setup script to restore renv environment
Rscript setup.R

rem Run data scripts to generate the cleaned dataset
Rscript scripts\01_data_ingestion.R
Rscript scripts\02_data_cleaning.R

rem Launch Shiny app
R -e "shiny::runApp('dashboard/')"

echo Shiny app should be running at http://localhost:3838
pause
