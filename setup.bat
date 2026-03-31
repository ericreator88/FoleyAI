@echo off
setlocal enabledelayedexpansion
title Foley AI - Setup
color 0F
cd /d "%~dp0"

set "APP_DIR=%~dp0"
set "REPO_DIR=%APP_DIR%repo"
set "ENV_DIR=%APP_DIR%env"
set "LOCAL_CONDA=%APP_DIR%conda"
set "MODEL_DIR=%APP_DIR%pretrained_models"

echo.
echo  =============================================
echo      Foley AI - Automated Setup
echo  =============================================
echo.
echo  This installs everything you need:
echo    - Python 3.10 environment
echo    - PyTorch + CUDA
echo    - ML dependencies
echo    - Model weights (~18GB download)
echo.
echo  Total disk: ~30GB. Time: 15-30 min.
echo.
echo  Press any key to begin, or close to cancel.
pause >nul
echo.

:: ══════════════════════════════════════
:: Pre-check: NVIDIA GPU
:: ══════════════════════════════════════
nvidia-smi >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] No NVIDIA GPU detected.
    echo          Foley AI requires an NVIDIA GPU with CUDA support.
    echo          Make sure your drivers are up to date:
    echo          https://www.nvidia.com/drivers
    echo.
    pause
    exit /b 1
)
echo  [OK] NVIDIA GPU detected

:: Pre-check: Git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Git is not installed.
    echo          Download from: https://git-scm.com/download/win
    echo          Install it, then re-run this setup.
    echo.
    pause
    exit /b 1
)
echo  [OK] Git found

:: ══════════════════════════════════════
:: Step 1: Clone source repo
:: ══════════════════════════════════════
echo.
echo  [1/5] Getting source code...

if exist "%REPO_DIR%\infer.py" (
    echo         Source code already present.
) else (
    echo         Cloning HunyuanVideo-Foley...
    git clone https://github.com/Tencent-Hunyuan/HunyuanVideo-Foley.git "%REPO_DIR%"
    if not exist "%REPO_DIR%\infer.py" (
        echo  [ERROR] Clone failed. Check your internet connection.
        pause
        exit /b 1
    )
    echo         Done.
)

:: ══════════════════════════════════════
:: Step 2: Python environment
:: ══════════════════════════════════════
echo.
echo  [2/5] Setting up Python...

if exist "%ENV_DIR%\python.exe" (
    echo         Python environment exists.
    goto :step3
)

:: Find or install conda
set "CONDA_EXE="
where conda >nul 2>&1
if %errorlevel%==0 (
    echo         Using system conda.
    set "USE_SYSTEM_CONDA=1"
    goto :make_env
)

if exist "%LOCAL_CONDA%\Scripts\conda.exe" (
    set "CONDA_EXE=%LOCAL_CONDA%\Scripts\conda.exe"
    goto :make_env
)

:: Download Miniconda
echo         Downloading Miniconda (no admin needed)...
set "MC_URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
set "MC_EXE=%TEMP%\miniconda_installer.exe"

curl -L -o "%MC_EXE%" "%MC_URL%" 2>nul
if not exist "%MC_EXE%" (
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%MC_URL%' -OutFile '%MC_EXE%'" 2>nul
)
if not exist "%MC_EXE%" (
    echo  [ERROR] Could not download Miniconda.
    echo          Install manually: https://docs.anaconda.com/miniconda/
    pause
    exit /b 1
)

echo         Installing Miniconda locally...
start /wait "" "%MC_EXE%" /InstallationType=JustMe /RegisterPython=0 /AddToPath=0 /S /D=%LOCAL_CONDA%
del "%MC_EXE%" 2>nul

if not exist "%LOCAL_CONDA%\Scripts\conda.exe" (
    echo  [ERROR] Miniconda install failed.
    pause
    exit /b 1
)
set "CONDA_EXE=%LOCAL_CONDA%\Scripts\conda.exe"

:make_env
echo         Creating Python 3.10 environment...
if defined USE_SYSTEM_CONDA (
    call conda create -p "%ENV_DIR%" python=3.10 -y >nul 2>&1
) else (
    "%CONDA_EXE%" create -p "%ENV_DIR%" python=3.10 -y >nul 2>&1
)

if not exist "%ENV_DIR%\python.exe" (
    echo  [ERROR] Failed to create Python environment.
    pause
    exit /b 1
)
echo         Python 3.10 ready.

:: ══════════════════════════════════════
:: Step 3: Install dependencies
:: ══════════════════════════════════════
:step3
echo.
echo  [3/5] Installing dependencies...

set "PY=%ENV_DIR%\python.exe"
set "PIP=%ENV_DIR%\Scripts\pip.exe"

:: Quick check if already done
"%PY%" -c "import torch; import flask; import hunyuanvideo_foley" >nul 2>&1
if %errorlevel%==0 (
    echo         All dependencies present.
    goto :step4
)

echo         Installing PyTorch + CUDA (this is the big one)...
"%PIP%" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
if %errorlevel% neq 0 (
    echo         Trying CUDA 11.8 fallback...
    "%PIP%" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    if %errorlevel% neq 0 (
        echo  [ERROR] PyTorch installation failed.
        pause
        exit /b 1
    )
)

echo         Installing ML libraries...
"%PIP%" install --upgrade setuptools >nul 2>&1
"%PIP%" install "git+https://github.com/huggingface/transformers@v4.49.0-SigLIP-2"
if %errorlevel% neq 0 (
    echo  [ERROR] Transformers install failed.
    pause
    exit /b 1
)

"%PIP%" install "git+https://github.com/descriptinc/audiotools"
if %errorlevel% neq 0 (
    echo  [ERROR] Audiotools install failed.
    pause
    exit /b 1
)

echo         Installing remaining packages...
"%PIP%" install flask >nul 2>&1
"%PIP%" install -e "%REPO_DIR%" >nul 2>&1

:: Verify everything works
"%PY%" -c "import torch; import flask; from hunyuanvideo_foley.utils.model_utils import load_model; print('OK')" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Dependency verification failed. Check errors above.
    pause
    exit /b 1
)
echo         Dependencies installed.

:: ══════════════════════════════════════
:: Step 4: Download models
:: ══════════════════════════════════════
:step4
echo.
echo  [4/5] Checking model weights...

if exist "%MODEL_DIR%\hunyuanvideo_foley.pth" (
    echo         Models found (skipping download).
    goto :step5
)

echo         Downloading model weights (~18GB)...
echo         This is a one-time download. Grab a coffee.
echo.

"%PIP%" install huggingface_hub >nul 2>&1
"%PY%" -c "from huggingface_hub import snapshot_download; snapshot_download('tencent/HunyuanVideo-Foley', local_dir=r'%MODEL_DIR%', local_dir_use_symlinks=False)"

if not exist "%MODEL_DIR%\hunyuanvideo_foley.pth" (
    echo.
    echo  [ERROR] Model download incomplete.
    echo          Re-run setup.bat to resume, or download manually:
    echo          https://huggingface.co/tencent/HunyuanVideo-Foley
    echo          Place .pth files in: %MODEL_DIR%
    pause
    exit /b 1
)
echo         Models downloaded.

:: ══════════════════════════════════════
:: Step 5: Desktop shortcut
:: ══════════════════════════════════════
:step5
echo.
echo  [5/5] Creating desktop shortcut...

set "SHORTCUT=%USERPROFILE%\Desktop\Foley AI.lnk"
powershell -Command "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath='%APP_DIR%foley-app.bat'; $s.WorkingDirectory='%APP_DIR%'; $s.Description='Foley AI'; $s.Save()" 2>nul

if exist "%SHORTCUT%" (
    echo         Desktop shortcut created.
) else (
    echo         Shortcut skipped (not critical).
)

:: ══════════════════════════════════════
:: Done
:: ══════════════════════════════════════
echo.
echo  =============================================
echo      Setup complete!
echo  =============================================
echo.
echo  Launch: double-click "Foley AI" on desktop
echo          or run foley-app.bat
echo.
echo  Press any key to launch now...
pause >nul

call "%APP_DIR%foley-app.bat"
