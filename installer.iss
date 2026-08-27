#define MyAppName "Doner Kebab POS"
; Версию не совмещаем с backend-installer (там отдельный релиз).
#define MyAppVersion "1.0.80"
#define MyAppPublisher "Doner Kebab"
#define MyAppExeName "dk_pos.exe"
#define BuildDir "build\\windows\\x64\\runner\\Release"

[Setup]
; Новый AppId: отдельная запись в «Установка программ»; старый POS при необходимости удалить вручную.
AppId={{2B9C4E71-F58A-43D9-9B1E-7F6A0C8E5D32}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Doner Kebab POS
DefaultGroupName=Doner Kebab\POS
DisableProgramGroupPage=yes
OutputDir=build\windows_installer
; Имя файла как у бэкенда (doner-kebab-backend-setup), но с префиксом pos — не пересекается.
OutputBaseFilename=doner-kebab-pos-setup-{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
CloseApplications=force
CloseApplicationsFilter=dk_pos.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные задачи:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec(
    ExpandConstant('{cmd}'),
    '/C taskkill /F /IM {#MyAppExeName}',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  Exec(
    ExpandConstant('{cmd}'),
    '/C ping -n 3 127.0.0.1 > nul',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  Result := '';
end;

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Запустить {#MyAppName}"; Flags: nowait postinstall skipifsilent
