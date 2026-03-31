@echo off
setlocal enabledelayedexpansion

set "APP_DIR=%~dp0"
set "REPO_DIR=%APP_DIR%repo"
set "ENV_DIR=%APP_DIR%env"
set "MODEL_PATH=%APP_DIR%pretrained_models"
set "OUTPUT_DIR=%APP_DIR%output"
set "MODEL_SIZE=xxl"
set "EXTRA_ARGS="

:: Find Python
set "PY="
if exist "%ENV_DIR%\python.exe" (
    set "PY=%ENV_DIR%\python.exe"
    if exist "%ENV_DIR%\Library\ssl\cacert.pem" set "SSL_CERT_FILE=%ENV_DIR%\Library\ssl\cacert.pem"
) else (
    call conda activate foley >nul 2>&1
    if !errorlevel!==0 ( set "PY=python" ) else (
        echo  Run setup.bat first. & exit /b 1
    )
)

if "%~1"=="" goto :help
if "%~1"=="--help" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="--app" ( call "%APP_DIR%foley-app.bat" & exit /b )

:parse
if "%~1"=="--xl" ( set "MODEL_SIZE=xl" & shift & goto :parse )
if "%~1"=="--xxl" ( set "MODEL_SIZE=xxl" & shift & goto :parse )
if "%~1"=="--offload" ( set "EXTRA_ARGS=!EXTRA_ARGS! --enable_offload" & shift & goto :parse )
if "%~1"=="--steps" ( set "EXTRA_ARGS=!EXTRA_ARGS! --num_inference_steps %~2" & shift & shift & goto :parse )
if "%~1"=="--cfg" ( set "EXTRA_ARGS=!EXTRA_ARGS! --guidance_scale %~2" & shift & shift & goto :parse )
if "%~1"=="--out" ( set "OUTPUT_DIR=%~2" & shift & shift & goto :parse )
if "%~1"=="--batch" ( goto :batch )

set "VIDEO=%~1"
set "PROMPT=%~2"
if not exist "%VIDEO%" ( echo  Error: %VIDEO% not found & exit /b 1 )

cd /d "%REPO_DIR%"
echo  Foley [%MODEL_SIZE%] ^> %~nx1
if defined PROMPT (
    "%PY%" infer.py --model_path "%MODEL_PATH%" --model_size %MODEL_SIZE% --single_video "%VIDEO%" --single_prompt "%PROMPT%" --output_dir "%OUTPUT_DIR%" %EXTRA_ARGS%
) else (
    "%PY%" infer.py --model_path "%MODEL_PATH%" --model_size %MODEL_SIZE% --single_video "%VIDEO%" --single_prompt "" --output_dir "%OUTPUT_DIR%" %EXTRA_ARGS%
)
if %errorlevel%==0 explorer "%OUTPUT_DIR%"
goto :eof

:batch
shift
cd /d "%REPO_DIR%"
"%PY%" infer.py --model_path "%MODEL_PATH%" --model_size %MODEL_SIZE% --csv_path "%~1" --output_dir "%OUTPUT_DIR%" %EXTRA_ARGS%
if %errorlevel%==0 explorer "%OUTPUT_DIR%"
goto :eof

:help
echo.
echo  Foley AI - Video to Audio
echo.
echo  foley video.mp4 "describe the sound"
echo  foley video.mp4
echo  foley --app                  (web UI)
echo  foley --xl video.mp4         (lighter model)
echo  foley --batch videos.csv
echo.
echo  Options: --xl --xxl --offload --steps N --cfg N --out DIR
goto :eof
