@echo off
title Foley AI
cd /d "%~dp0"

set "APP_DIR=%~dp0"
set "ENV_DIR=%APP_DIR%env"

:: Find Python
if exist "%ENV_DIR%\python.exe" (
    set "PY=%ENV_DIR%\python.exe"
    if exist "%ENV_DIR%\Library\ssl\cacert.pem" set "SSL_CERT_FILE=%ENV_DIR%\Library\ssl\cacert.pem"
    goto :launch
)

:: Try system conda
call conda activate foley >nul 2>&1
if %errorlevel%==0 (
    set "PY=python"
    for /f "delims=" %%i in ('python -c "import certifi; print(certifi.where())" 2^>nul') do set "SSL_CERT_FILE=%%i"
    goto :launch
)

:: Not set up
echo.
echo  First time? Running setup...
echo.
call "%APP_DIR%setup.bat"
exit /b

:launch
echo.
echo  =============================================
echo      Foley AI - Sound Design Studio
echo  =============================================
echo.
echo  http://127.0.0.1:8079
echo  Browser opens automatically.
echo  Close this window to stop.
echo.

"%PY%" "%APP_DIR%app.py" %*

if %errorlevel% neq 0 (
    echo.
    echo  Something went wrong. Press any key to exit.
    pause >nul
)
