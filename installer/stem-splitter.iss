; Inno Setup script for stem-splitter.
; Packages the self-contained bundle produced by bundle.bat (must be built
; first) into a wizard installer: pick a destination folder, optionally add
; it to PATH, get a real uninstaller in "Apps & Features".
;
; Build with: .\installer.bat  (or: ISCC installer\stem-splitter.iss)

#define MyAppName "stem-splitter"
#define MyAppVersion "1.0"
#define MyAppPublisher "stem-splitter"
#define BundleDir "..\bundle\dist\stem-splitter"

[Setup]
AppId={{1F324C46-6896-46B2-9301-83CFF69FD081}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=output
OutputBaseFilename=stem-splitter-rocm-install
Compression=lzma2/fast
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\stem-splitter.exe
DisableWelcomePage=no
DisableDirPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "envPath"; Description: "Add {#MyAppName} to my PATH (lets you run ""stem-splitter"" from any terminal)"; Flags: checkedonce

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Excludes: "stem-splitter.ini"; Flags: recursesubdirs ignoreversion
; Installed once and left alone on upgrades, so a user's customized
; audio_dir/video_dir survive reinstalling/upgrading.
Source: "{#BundleDir}\stem-splitter.ini"; DestDir: "{app}"; Flags: onlyifdoesntexist

[Code]
const
  EnvironmentKey = 'Environment';
  MY_HWND_BROADCAST = $FFFF;
  MY_WM_SETTINGCHANGE = $001A;
  MY_SMTO_ABORTIFHUNG = $0002;

function SendMessageTimeoutA(hWnd: Integer; Msg: Integer; wParam: Integer; lParam: string;
  fuFlags: Integer; uTimeout: Integer; var lpdwResult: Integer): Integer;
  external 'SendMessageTimeoutA@user32.dll stdcall';

procedure RefreshEnvironment;
var
  ResultCode: Integer;
begin
  SendMessageTimeoutA(MY_HWND_BROADCAST, MY_WM_SETTINGCHANGE, 0, 'Environment', MY_SMTO_ABORTIFHUNG, 5000, ResultCode);
end;

procedure EnvAddPath(Path: string);
var
  Paths: string;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    Paths := '';

  if Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';') > 0 then
    exit;

  if (Length(Paths) > 0) and (Paths[Length(Paths)] <> ';') then
    Paths := Paths + ';';
  Paths := Paths + Path;

  if not RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    Log('Failed to add to PATH: ' + Path)
  else
    RefreshEnvironment;
end;

procedure EnvRemovePath(Path: string);
var
  Paths: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    exit;

  P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
  if P = 0 then
    exit;

  Delete(Paths, P - 1, Length(Path) + 1);

  if not RegWriteStringValue(HKEY_CURRENT_USER, EnvironmentKey, 'Path', Paths) then
    Log('Failed to remove from PATH: ' + Path)
  else
    RefreshEnvironment;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and IsTaskSelected('envPath') then
    EnvAddPath(ExpandConstant('{app}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
    EnvRemovePath(ExpandConstant('{app}'));
end;
