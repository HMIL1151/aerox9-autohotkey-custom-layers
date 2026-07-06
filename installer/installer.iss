; Inno Setup script for Aerox 9 Layer Manager.
; Built by build-release.ps1, which stages files into ..\dist\stage before invoking ISCC on this script.

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

[Setup]
AppId={{66352349-884F-4174-BFFB-FEB06203AD58}
AppName=Aerox 9 Layer Manager
AppVersion={#MyAppVersion}
AppPublisher=Aerox 9 Layer Manager contributors
DefaultDirName={autopf}\Aerox9 Layer Manager
DefaultGroupName=Aerox 9 Layer Manager
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
OutputDir=..\dist
OutputBaseFilename=Aerox9LayerManagerSetup
Compression=lzma2
SolidCompression=yes
UninstallDisplayIcon={app}\Aerox9_LayerOverlay.exe
WizardStyle=modern
CloseApplications=force
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "startup"; Description: "Start Aerox 9 Layer Manager automatically when Windows starts"; GroupDescription: "Startup:"; Flags: checkedonce

[Files]
Source: "..\dist\stage\Aerox9_LayerOverlay.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\stage\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\stage\Aerox9Layers.default.ini"; DestDir: "{app}"; DestName: "Aerox9Layers.ini"; Flags: onlyifdoesntexist uninsneveruninstall
Source: "..\dist\stage\Thumbnails\*"; DestDir: "{app}\Thumbnails"; Flags: ignoreversion recursesubdirs createallsubdirs onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\Aerox 9 Layer Manager"; Filename: "{app}\Aerox9_LayerOverlay.exe"
Name: "{group}\Uninstall Aerox 9 Layer Manager"; Filename: "{uninstallexe}"
Name: "{commonstartup}\Aerox 9 Layer Manager"; Filename: "{app}\Aerox9_LayerOverlay.exe"; Tasks: startup

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /IM Aerox9_LayerOverlay.exe /F"; Flags: runhidden; RunOnceId: "KillAerox9"

[Run]
Filename: "{app}\Aerox9_LayerOverlay.exe"; Description: "Launch Aerox 9 Layer Manager now"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Answer: Integer;
  AppDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    AppDir := ExpandConstant('{app}');
    if UninstallSilent() then
      Answer := IDNO
    else
      Answer := MsgBox('Also delete your saved layer profile, config backups, and thumbnails?' + #13#10 + #13#10 +
        'Choose No to keep them in place in case you reinstall later.',
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
    if Answer = IDYES then
    begin
      DelTree(AppDir + '\ConfigBackups', True, True, True);
      DelTree(AppDir + '\ThumbnailCache', True, True, True);
      DelTree(AppDir + '\Thumbnails', True, True, True);
      DeleteFile(AppDir + '\Aerox9Layers.ini');
      DeleteFile(AppDir + '\Aerox9Layers-export.ini');
    end;
    RemoveDir(AppDir);
  end;
end;
