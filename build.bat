@echo off
REM Builds build\stem-splitter.exe - a thin launcher you can add to PATH.
REM It forwards to this project's existing venv\Scripts\python.exe + main.py,
REM so the venv itself is never copied/bundled (still requires run.ps1 --setup
REM to have been run first). Compiles launcher\Launcher.cs with csc.exe, the
REM C# compiler that ships with the .NET Framework on Windows - no extra
REM tooling to install.

setlocal enabledelayedexpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "VENV_PY=%ROOT%\venv\Scripts\python.exe"
set "SRC=%ROOT%\launcher\Launcher.cs"
set "BUILD_DIR=%ROOT%\build"
set "OUT_EXE=%BUILD_DIR%\stem-splitter.exe"
set "ROOT_FILE=%BUILD_DIR%\stem-splitter.root.txt"

if not exist "%VENV_PY%" (
    echo [ERROR] venv not found. Run .\run.ps1 --setup first.
    exit /b 1
)

if not exist "%SRC%" (
    echo [ERROR] Launcher source not found: %SRC%
    exit /b 1
)

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

set "CSC="
for /f "delims=" %%I in ('where csc 2^>nul') do (
    if not defined CSC set "CSC=%%I"
)
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not defined CSC (
    echo [ERROR] csc.exe ^(.NET Framework C# compiler^) not found.
    exit /b 1
)

echo [..] Compiling launcher with "%CSC%"...
"%CSC%" /nologo /optimize+ /target:exe /out:"%OUT_EXE%" "%SRC%"
if errorlevel 1 (
    echo [ERROR] Compilation failed.
    exit /b 1
)

echo %ROOT%> "%ROOT_FILE%"

echo.
echo ============================================
echo  Build complete
echo  Exe:   %OUT_EXE%
echo  Add "%BUILD_DIR%" to your PATH, then run:
echo    stem-splitter "<YouTube URL>"
echo ============================================
exit /b 0
