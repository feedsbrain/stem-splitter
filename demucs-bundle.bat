@echo off
REM Builds bundle\demucs-cxfreeze\demucs-cxfreeze.exe - a standalone Demucs+
REM torch executable, independent of this project's own PyInstaller bundle
REM (bundle.bat). Same idea as stemrollerapp/demucs-cxfreeze
REM (https://github.com/stemrollerapp/demucs-cxfreeze): use cx_Freeze to
REM freeze just Demucs/torch into one exe that can be redistributed and run
REM on its own, without a Python install.
REM
REM Entry point is scripts\run_demucs.py rather than a bare
REM "from demucs.separate import main" - it swaps in a soundfile-based WAV/
REM FLAC writer so the frozen exe doesn't need torchcodec/ffmpeg-codec DLLs
REM (see that file's docstring). Output behaves like the demucs CLI:
REM   demucs-cxfreeze.exe -n htdemucs_ft -d cuda -o <outdir> <input.wav>
REM
REM As with the upstream repo, ffmpeg/ffprobe are NOT bundled here - put
REM this project's tools\ffmpeg.exe/ffprobe.exe's folder on PATH before
REM running the frozen exe if the input isn't already a WAV/FLAC/MP3 that
REM soundfile can read directly.

setlocal enabledelayedexpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "VENV_PY=%ROOT%\venv\Scripts\python.exe"
set "CXFREEZE=%ROOT%\venv\Scripts\cxfreeze.exe"
set "ENTRY=%ROOT%\scripts\run_demucs.py"
set "DIST_DIR=%ROOT%\bundle\demucs-cxfreeze"
set "SOUNDFILE_DATA=%ROOT%\venv\Lib\site-packages\_soundfile_data"
set "OUT_EXE=%DIST_DIR%\demucs-cxfreeze.exe"

if not exist "%VENV_PY%" (
    echo [ERROR] venv not found. Run .\run.ps1 --setup first.
    exit /b 1
)

if not exist "%ENTRY%" (
    echo [ERROR] Entry script not found: %ENTRY%
    exit /b 1
)

"%VENV_PY%" -c "import cx_Freeze" >nul 2>&1
if errorlevel 1 (
    echo [..] Installing cx_Freeze into venv...
    "%VENV_PY%" -m pip install cx_Freeze
    if errorlevel 1 (
        echo [ERROR] Failed to install cx_Freeze.
        exit /b 1
    )
)

if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"

REM rocm_sdk/_rocm_sdk_core/_rocm_sdk_libraries_gfx103X_dgpu hold torch's
REM actual HIP/MIOpen/rocBLAS runtime DLLs, loaded via importlib with a
REM dynamically-computed module name (see rocm_sdk/__init__.py) - invisible
REM to cx_Freeze's static import scanner, so they must be listed explicitly
REM or the frozen exe silently runs CPU-only (same reason bundle.bat's
REM PyInstaller build needs --collect-all for these).
echo [..] Freezing Demucs+torch with cx_Freeze ^(this can take several minutes^)...
"%CXFREEZE%" ^
    --script="%ENTRY%" ^
    --target-dir="%DIST_DIR%" ^
    --target-name=demucs-cxfreeze ^
    build_exe ^
    --packages=torch,demucs,soundfile,rocm_sdk,_rocm_sdk_core,_rocm_sdk_libraries_gfx103X_dgpu ^
    --includes=demucs.htdemucs ^
    --include-msvcr
if errorlevel 1 (
    echo [ERROR] cx_Freeze build failed.
    exit /b 1
)

if exist "%SOUNDFILE_DATA%" (
    echo [..] Copying _soundfile_data...
    xcopy /e /i /y "%SOUNDFILE_DATA%" "%DIST_DIR%\lib\_soundfile_data\" >nul
)

echo.
echo ============================================
echo  Demucs bundle complete
echo  Exe:   %OUT_EXE%
echo  Put ffmpeg/ffprobe ^(e.g. this project's tools\^) on PATH, then run:
echo    demucs-cxfreeze -n htdemucs_ft -d cuda -o "<outdir>" "<input.wav>"
echo ============================================
exit /b 0
