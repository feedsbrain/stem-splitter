@echo off
setlocal enabledelayedexpansion

set "PROJECT_DIR=%~dp0"
set "VENV_DIR=%PROJECT_DIR%venv"
set "VENV_PY=%VENV_DIR%\Scripts\python.exe"
set "TOOLS_DIR=%PROJECT_DIR%tools"
set "AUDIO_DIR=%PROJECT_DIR%audio"
set "VIDEO_DIR=%PROJECT_DIR%video"
set "FFMPEG_EXE=%TOOLS_DIR%\ffmpeg.exe"
set "FFPROBE_EXE=%TOOLS_DIR%\ffprobe.exe"

if "%~1"=="" goto :usage
if /i "%~1"=="--setup" goto :setup
if /i "%~1"=="--clean" goto :clean
if /i "%~1"=="--help" goto :usage
if /i "%~1"=="-h" goto :usage
goto :run

REM ============================================================
:usage
REM ============================================================
echo Usage:
echo   run.bat "<YouTube URL>"     Download video, extract audio, separate stems
echo   run.bat --setup             Set up venv, torch/rocm, ffmpeg, and folders
echo   run.bat --clean             Remove downloaded/generated files in audio\, tools\, video\
exit /b 1

REM ============================================================
:run
REM ============================================================
if not exist "%VENV_PY%" (
    echo [ERROR] Environment not set up yet. Run: run.bat --setup
    exit /b 1
)
set "_WAS_ACTIVE=%VIRTUAL_ENV%"
if /i not "%VIRTUAL_ENV%"=="%VENV_DIR%" (
    call "%VENV_DIR%\Scripts\activate.bat"
)
"%VENV_PY%" "%PROJECT_DIR%main.py" %1
set "_RUN_RC=!errorlevel!"
if /i not "%_WAS_ACTIVE%"=="%VENV_DIR%" (
    call "%VENV_DIR%\Scripts\deactivate.bat"
)
exit /b !_RUN_RC!

REM ============================================================
:setup
REM ============================================================
echo ============================================
echo  Demucs + ROCm Environment Setup
echo ============================================

set "PY_CMD="

REM --- Step 1: locate Python 3.12 ---
where py >nul 2>&1
if %errorlevel%==0 (
    py -3.12 --version >nul 2>&1
    if !errorlevel!==0 (
        set "PY_CMD=py -3.12"
    )
)

if not defined PY_CMD (
    python --version 2>nul | findstr /r "3\.12\." >nul 2>&1
    if !errorlevel!==0 (
        set "PY_CMD=python"
    )
)

if not defined PY_CMD (
    echo [ERROR] Python 3.12 was not found on this system.
    echo Install it from https://www.python.org/downloads/ and re-run this script.
    exit /b 1
)

for /f "tokens=*" %%v in ('%PY_CMD% --version') do echo [OK] Found %%v

REM --- Step 2: ensure working folders exist ---
if not exist "%AUDIO_DIR%" mkdir "%AUDIO_DIR%"
if not exist "%TOOLS_DIR%" mkdir "%TOOLS_DIR%"
if not exist "%VIDEO_DIR%" mkdir "%VIDEO_DIR%"
echo [OK] audio\, tools\, video\ folders ready.

REM --- Step 3: create venv if missing ---
if exist "%VENV_PY%" (
    echo [OK] Virtual environment already exists at "%VENV_DIR%"
) else (
    echo [..] Creating virtual environment at "%VENV_DIR%"
    %PY_CMD% -m venv "%VENV_DIR%"
    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        exit /b 1
    )
    echo [OK] Virtual environment created.
)

REM --- Step 4: keep pip current ---
"%VENV_PY%" -m pip install --upgrade pip >nul

REM --- Step 5: torch + rocm ---
"%VENV_PY%" -c "import torch; assert 'rocm' in torch.__version__.lower()" >nul 2>&1
if !errorlevel!==0 (
    echo [OK] torch ^(ROCm build^) already installed.
) else (
    echo [..] Installing torch, torchaudio, torchvision, rocm ^(this may take a while^)...
    "%VENV_PY%" -m pip install --pre torch torchaudio torchvision rocm --index-url https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu/
    if errorlevel 1 (
        echo [ERROR] Failed to install torch/rocm.
        exit /b 1
    )
    echo [OK] torch + rocm installed.
)

REM --- Step 6: yt-dlp, demucs, soundfile (requirements.txt) ---
"%VENV_PY%" -c "import yt_dlp, demucs, soundfile" >nul 2>&1
if !errorlevel!==0 (
    echo [OK] yt-dlp, demucs, soundfile already installed.
) else (
    echo [..] Installing yt-dlp, demucs, soundfile from requirements.txt...
    "%VENV_PY%" -m pip install -r "%PROJECT_DIR%requirements.txt"
    if errorlevel 1 (
        echo [ERROR] Failed to install requirements.txt.
        exit /b 1
    )
    echo [OK] requirements.txt installed.
)

REM --- Step 7: ffmpeg (portable) ---
if exist "%FFMPEG_EXE%" (
    echo [OK] ffmpeg already present in tools\
) else (
    echo [..] Downloading ffmpeg ^(portable, Windows x64^)...
    set "FFMPEG_ZIP=%TEMP%\ffmpeg-download.zip"
    set "FFMPEG_TMP=%TEMP%\ffmpeg-extract"

    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest -Uri 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' -OutFile '!FFMPEG_ZIP!'"
    if errorlevel 1 (
        echo [ERROR] Failed to download ffmpeg.
        exit /b 1
    )

    if exist "!FFMPEG_TMP!" rmdir /s /q "!FFMPEG_TMP!"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Expand-Archive -Path '!FFMPEG_ZIP!' -DestinationPath '!FFMPEG_TMP!' -Force"
    if errorlevel 1 (
        echo [ERROR] Failed to extract ffmpeg archive.
        exit /b 1
    )

    for /f "delims=" %%d in ('dir /b /ad "!FFMPEG_TMP!"') do set "FFMPEG_SRC=!FFMPEG_TMP!\%%d\bin"
    copy /y "!FFMPEG_SRC!\ffmpeg.exe" "%FFMPEG_EXE%" >nul
    copy /y "!FFMPEG_SRC!\ffprobe.exe" "%FFPROBE_EXE%" >nul

    del /q "!FFMPEG_ZIP!" >nul 2>&1
    rmdir /s /q "!FFMPEG_TMP!" >nul 2>&1

    if not exist "%FFMPEG_EXE%" (
        echo [ERROR] ffmpeg.exe not found after extraction.
        exit /b 1
    )
    echo [OK] ffmpeg downloaded to tools\ffmpeg.exe
)

echo.
echo ============================================
echo  Setup complete
echo  Run with: run.bat "<YouTube URL>"
echo ============================================
exit /b 0

REM ============================================================
:clean
REM ============================================================
echo ============================================
echo  Cleaning working folder
echo  (audio\, tools\, video\)
echo ============================================

where git >nul 2>&1
if %errorlevel%==0 (
    git -C "%PROJECT_DIR%" rev-parse --is-inside-work-tree >nul 2>&1
    if !errorlevel!==0 (
        git -C "%PROJECT_DIR%" clean -fdX -e tools/ffmpeg.exe -e tools/ffprobe.exe -- audio tools video
        goto :clean_done
    )
)

echo [..] git not available here, removing contents manually ^(keeping .gitkeep, ffmpeg.exe, ffprobe.exe^)...
for %%D in (audio tools video) do (
    if exist "%PROJECT_DIR%%%D" (
        for %%F in ("%PROJECT_DIR%%%D\*") do (
            if /i not "%%~nxF"==".gitkeep" if /i not "%%~nxF"=="ffmpeg.exe" if /i not "%%~nxF"=="ffprobe.exe" del /f /q "%%F" >nul 2>&1
        )
        for /d %%F in ("%PROJECT_DIR%%%D\*") do rmdir /s /q "%%F" >nul 2>&1
        echo [OK] Cleaned %%D\
    )
)

:clean_done
echo.
echo ============================================
echo  Clean complete
echo ============================================
exit /b 0
