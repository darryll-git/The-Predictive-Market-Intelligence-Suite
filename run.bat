rem run.bat

@echo off

rem Set the local R library path for all R processes in this script
set R_LIBS_USER=%CD%\.R-libs

rem Run setup script to restore renv environment
Rscript setup.R

rem Launch Shiny app
R -e "shiny::runApp('dashboard/')"

echo Shiny app should be running at http://localhost:3838
pause
