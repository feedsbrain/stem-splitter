@echo off
REM Builds bundle\dist\stem-splitter\stem-splitter.exe - a self-contained
REM PyInstaller --onedir bundle (Python + torch/rocm + demucs + yt-dlp +
REM ffmpeg, all included). Unlike build.bat's thin launcher, this does NOT
REM need venv\ to exist alongside it afterwards - the whole folder can be
REM copied elsewhere (same machine/GPU) and added to PATH.
REM
REM Note: torch/rocm here is a nightly build pinned to a specific AMD GPU
REM architecture (gfx103X-dgpu, see requirements.txt) - the bundle is only
REM portable to machines with a matching GPU.

setlocal enabledelayedexpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "VENV_PY=%ROOT%\venv\Scripts\python.exe"
set "BUNDLE_DIR=%ROOT%\bundle"
set "DIST_DIR=%BUNDLE_DIR%\dist"
set "WORK_DIR=%BUNDLE_DIR%\work"
set "OUT_EXE=%DIST_DIR%\stem-splitter\stem-splitter.exe"

if not exist "%VENV_PY%" (
    echo [ERROR] venv not found. Run .\run.ps1 --setup first.
    exit /b 1
)

if not exist "%ROOT%\tools\ffmpeg.exe" (
    echo [ERROR] tools\ffmpeg.exe not found. Run .\run.ps1 --setup first.
    exit /b 1
)

"%VENV_PY%" -c "import PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo [..] Installing PyInstaller into venv...
    "%VENV_PY%" -m pip install pyinstaller
    if errorlevel 1 (
        echo [ERROR] Failed to install PyInstaller.
        exit /b 1
    )
)

echo [..] Running PyInstaller ^(this bundles ~3-4 GB of torch/rocm - can take several minutes^)...
"%VENV_PY%" -m PyInstaller ^
    --name stem-splitter ^
    --onedir ^
    --console ^
    --noconfirm ^
    --clean ^
    --distpath "%DIST_DIR%" ^
    --workpath "%WORK_DIR%" ^
    --specpath "%BUNDLE_DIR%" ^
    --contents-directory . ^
    --add-binary "%ROOT%\tools\ffmpeg.exe;tools" ^
    --add-binary "%ROOT%\tools\ffprobe.exe;tools" ^
    --add-data "%ROOT%\stem-splitter.ini;." ^
    --collect-all torch ^
    --collect-all torchaudio ^
    --collect-all torchvision ^
    --collect-all rocm ^
    --collect-all rocm_sdk ^
    --collect-all _rocm_sdk_core ^
    --collect-all _rocm_sdk_libraries_gfx103X_dgpu ^
    --collect-all demucs ^
    --collect-all dora ^
    --collect-all julius ^
    --collect-all openunmix ^
    --collect-all omegaconf ^
    "%ROOT%\main.py"
if errorlevel 1 (
    echo [ERROR] PyInstaller build failed.
    exit /b 1
)

echo.
echo ============================================
echo  Bundle complete
echo  Exe:   %OUT_EXE%
echo  Add "%DIST_DIR%\stem-splitter" to your PATH, then run:
echo    stem-splitter "<YouTube URL>"
echo ============================================
exit /b 0
