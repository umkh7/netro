; Установщик Netro для Windows (Inno Setup 6)
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{6E3A1C52-9B7D-4F1E-A2C4-7D5B8E0F1A21}
AppName=Netro
AppVersion={#AppVersion}
AppPublisher=Netro
DefaultDirName={autopf}\Netro
DefaultGroupName=Netro
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\out
OutputBaseFilename=Netro-{#AppVersion}-windows-setup
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Netro.exe
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Netro"; Filename: "{app}\Netro.exe"
Name: "{autodesktop}\Netro"; Filename: "{app}\Netro.exe"; Tasks: desktopicon

[Registry]
; Ссылки netro://add?url=... с сайта открывают Netro
Root: HKCR; Subkey: "netro"; ValueType: string; ValueData: "URL:Netro"; Flags: uninsdeletekey
Root: HKCR; Subkey: "netro"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "netro\DefaultIcon"; ValueType: string; ValueData: "{app}\Netro.exe,0"
Root: HKCR; Subkey: "netro\shell\open\command"; ValueType: string; ValueData: """{app}\Netro.exe"" ""%1"""

[Run]
Filename: "{app}\Netro.exe"; Description: "{cm:LaunchProgram,Netro}"; Flags: nowait postinstall skipifsilent shellexec
