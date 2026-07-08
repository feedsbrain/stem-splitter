# PowerShell entry point for this project.
#
# Calling run.bat directly from PowerShell (e.g. `.\run.bat "<url>"`) silently
# truncates URLs: cmd.exe's own %1 argument tokenizer splits unquoted batch
# arguments on "=" (and "&", ",", ";") the same way it splits on whitespace.
# PowerShell only quotes arguments passed to .bat/.cmd files when they contain
# whitespace, so a URL like "...watch?v=xyz" arrives at run.bat unquoted and
# gets cut down to "...watch?v" before main.py ever sees it. Routing through
# cmd.exe at all is unsafe for URL arguments, so for the run case this script
# invokes the venv's python.exe directly instead of going through run.bat.
# --setup/--clean/--help take no such argument, so those are simply forwarded.

param(
    [Parameter(Position = 0)]
    [string]$Url
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RunBat = Join-Path $ScriptDir "run.bat"
$VenvPy = Join-Path $ScriptDir "venv\Scripts\python.exe"
$MainPy = Join-Path $ScriptDir "main.py"

switch ($Url) {
    "" { & $RunBat; exit $LASTEXITCODE }
    "--setup" { & $RunBat --setup; exit $LASTEXITCODE }
    "--clean" { & $RunBat --clean; exit $LASTEXITCODE }
    "--help" { & $RunBat --help; exit $LASTEXITCODE }
    "-h" { & $RunBat -h; exit $LASTEXITCODE }
}

if (-not (Test-Path $VenvPy)) {
    Write-Host "[ERROR] Environment not set up yet. Run: .\run.ps1 --setup"
    exit 1
}

& $VenvPy $MainPy $Url
exit $LASTEXITCODE
