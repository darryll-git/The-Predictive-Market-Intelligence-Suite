@echo off
echo ========================================================
echo Deploying to shinyapps.io...
echo ========================================================
echo Make sure you have pasted your token into deploy_cloud.R!
echo.

rem Auto-detect R installation and add to PATH
for /d %%i in ("C:\Program Files\R\R-*") do set "R_HOME=%%i"
set "PATH=%R_HOME%\bin\x64;%R_HOME%\bin;%PATH%"

rem Set the local R library path to avoid Admin permission errors
set R_LIBS_USER=%CD%\.R-libs

Rscript deploy_cloud.R
echo.
pause
