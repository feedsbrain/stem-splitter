@echo off
REM Compiles installer\stem-splitter.iss (Inno Setup) into
REM installer\output\stem-splitter-amd-rocm-gfx1030-install.exe - a wizard
REM installer that copies the bundle.bat output to a user-chosen folder and
REM optionally adds it to PATH. Requires bundle.bat to have been run first,
REM and Inno Setup installed (winget install JRSoftware.InnoSetup).

setlocal enabledelayedexpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "BUNDLE_EXE=%ROOT%\bundle\dist\stem-splitter\stem-splitter.exe"
set "ISS=%ROOT%\installer\stem-splitter.iss"

if not exist "%BUNDLE_EXE%" (
    echo [ERROR] Bundle not found. Run .\bundle.bat first.
    exit /b 1
)

set "PF86=%ProgramFiles(x86)%"
set "PF64=%ProgramFiles%"
set "LAP=%LOCALAPPDATA%"

set "ISCC="
if exist "%PF86%\Inno Setup 6\ISCC.exe" set "ISCC=%PF86%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%PF64%\Inno Setup 6\ISCC.exe" set "ISCC=%PF64%\Inno Setup 6\ISCC.exe"
if not defined ISCC if exist "%LAP%\Programs\Inno Setup 6\ISCC.exe" set "ISCC=%LAP%\Programs\Inno Setup 6\ISCC.exe"
if not defined ISCC (
    for /f "delims=" %%I in ('where ISCC 2^>nul') do if not defined ISCC set "ISCC=%%I"
)

if not defined ISCC (
    echo [ERROR] Inno Setup ^(ISCC.exe^) not found.
    echo Install it with: winget install JRSoftware.InnoSetup
    exit /b 1
)

echo [..] Compiling installer with "%ISCC%"...
"%ISCC%" /Q "%ISS%"
if errorlevel 1 (
    echo [ERROR] Installer build failed.
    exit /b 1
)

echo.
echo ============================================
echo  Installer complete
echo  See: %ROOT%\installer\output\
echo ============================================
exit /b 0
