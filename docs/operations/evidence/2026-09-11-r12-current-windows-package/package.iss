#pragma code_page 65001
[Setup]
AppId={{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}
AppName=POKROV VPN
AppVersion=1.2.0+4053
AppPublisher=POKROV
AppPublisherURL=https://pokrov.space/
AppSupportURL=https://pokrov.space/support/
DefaultDirName={autopf}\POKROV
DefaultGroupName=POKROV
DisableDirPage=no
DisableProgramGroupPage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=P:\apps\windows_shell\build\release_bundle
OutputBaseFilename=pokrov-windows-x64-1.2.0+4053-setup
SetupIconFile=P:\apps\\windows_shell\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\pokrov_windows.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SignedUninstaller=no
CloseApplications=yes
RestartApplications=no
AppMutex=POKROV.Windows.Shell

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"; Flags: unchecked

[InstallDelete]
Type: files; Name: "{app}\pokrov_activation_protocol_test.exe"

[Files]
Source: "P:\apps\windows_shell\build\release_bundle\pokrov-windows-x64-1.2.0+4053\*"; Excludes: "\pokrov_service.exe"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "P:\apps\windows_shell\build\release_bundle\pokrov-windows-x64-1.2.0+4053\pokrov_service.exe"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: InstallAndStartService

[Icons]
Name: "{group}\POKROV"; Filename: "{app}\pokrov_windows.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\POKROV"; Filename: "{app}\pokrov_windows.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKLM64; Subkey: "Software\space.pokrov\POKROV\Service"; ValueType: string; ValueName: "InstallOwnerSid"; ValueData: "{code:GetInstallOwnerSid}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\pokrov_windows.exe"; WorkingDir: "{app}"; Description: "Запустить POKROV"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ""$ErrorActionPreference='Stop'; $service=Get-Service -Name 'POKROVService' -ErrorAction SilentlyContinue; if ($null -ne $service -and $service.Status -ne 'Stopped') {{ Stop-Service -InputObject $service -Force -ErrorAction Stop; $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30)) }"""; Flags: runhidden waituntilterminated; RunOnceId: "StopPOKROVService"
Filename: "{sys}\sc.exe"; Parameters: "delete POKROVService"; Flags: runhidden waituntilterminated; RunOnceId: "DeletePOKROVService"

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
var
  InstallOwnerSid: String;
  SetupFailureExitCode: Integer;
  InstallOwnerRegistryKeyExisted: Boolean;
  InstallOwnerRegistryValueExisted: Boolean;
  InstallOwnerPreviousSid: String;
  LegacyPerUserInstallDetected: Boolean;
  LegacyPerUserInstallDirectory: String;
  LegacyPerUserUninstaller: String;

function InitializeUninstall: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(
    ExpandConstant('{sys}\taskkill.exe'),
    '/IM "pokrov_windows.exe" /T /F',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  if not Result then
  begin
    Log('POKROV_UI_CLOSE_FAILED: taskkill could not be started');
    Exit;
  end;
  if (ResultCode <> 0) and (ResultCode <> 128) then
  begin
    Log(Format('POKROV_UI_CLOSE_FAILED: taskkill exit %d', [ResultCode]));
    Result := False;
    Exit;
  end;
  Result := True;
end;

function IsSidCharacter(Value: Char): Boolean;
begin
  Result := ((Value >= '0') and (Value <= '9')) or (Value = '-');
end;

function ExtractOwnerSid(const Value: String): String;
var
  StartAt: Integer;
  EndAt: Integer;
begin
  Result := '';
  StartAt := Pos('S-1-5-21-', Value);
  if StartAt = 0 then
    exit;
  EndAt := StartAt + Length('S-1-5-21-');
  while (EndAt <= Length(Value)) and IsSidCharacter(Value[EndAt]) do
    EndAt := EndAt + 1;
  Result := Copy(Value, StartAt, EndAt - StartAt);
  if (Length(Result) < 16) or (Length(Result) > 184) then
    Result := '';
end;

function TryReuseExistingInstallOwnerSid(): Boolean;
var
  ExistingOwnerSid: String;
begin
  Result := RegQueryStringValue(HKLM64,
    'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
    ExistingOwnerSid);
  if Result then
  begin
    Result := (ExistingOwnerSid <> '') and
      (ExtractOwnerSid(ExistingOwnerSid) = ExistingOwnerSid);
    if Result then
    begin
      InstallOwnerSid := ExistingOwnerSid;
      Log('POKROV_INSTALL_OWNER_REUSED_FOR_UPGRADE');
    end;
  end;
end;

function QueryOriginalInstallOwnerSid(var OwnerSid: String): Boolean;
var
  PartIndex: Integer;
  HalfIndex: Integer;
  SubAuthority: Int64;
  CommandLine: String;
  ResultCode: Integer;
begin
  Result := False;
  OwnerSid := 'S-1-5-21';
  { Elevated Setup's protected temp directory is not writable by the original
    user. Return tagged 16-bit pieces through ExecAsOriginalUser's exit code:
    no shared writable file, and shell failures cannot become SID components. }
  for PartIndex := 4 to 7 do
  begin
    SubAuthority := 0;
    for HalfIndex := 0 to 1 do
    begin
      CommandLine := '-NoProfile -NonInteractive -Command "' +
        '$ErrorActionPreference=''Stop''; try { ' +
        '$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value; ' +
        'if ($sid -notmatch ''^S-1-5-21-([0-9]+-){3}[0-9]+$'') { exit 1 }; ' +
        '$part=[uint32]($sid.Split(''-'')[' + IntToStr(PartIndex) + ']); ' +
        'exit (65536 + (($part -shr ' + IntToStr(HalfIndex * 16) +
        ') -band 65535)) } catch { exit 1 }"';
      if not ExecAsOriginalUser(
        ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
        CommandLine, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        exit;
      if (ResultCode < 65536) or (ResultCode > 131071) then
        exit;
      if HalfIndex = 0 then
        SubAuthority := ResultCode - 65536
      else
        SubAuthority := SubAuthority + Int64(ResultCode - 65536) * 65536;
    end;
    OwnerSid := OwnerSid + '-' + IntToStr(SubAuthority);
  end;
  Result := ExtractOwnerSid(OwnerSid) = OwnerSid;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  OwnerQuerySucceeded: Boolean;
begin
  Result := '';
  LegacyPerUserInstallDirectory :=
    ExpandConstant('{localappdata}\Programs\POKROV');
  LegacyPerUserUninstaller :=
    AddBackslash(LegacyPerUserInstallDirectory) + 'unins000.exe';
  LegacyPerUserInstallDetected := RegKeyExists(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}_is1');
  if LegacyPerUserInstallDetected and
      not FileExists(LegacyPerUserUninstaller) then
  begin
    Result := 'Старая пользовательская установка POKROV повреждена: ' +
      'не найден её деинсталлятор. Удалите POKROV 1.1.6 вручную и ' +
      'повторите установку.';
    exit;
  end;
  OwnerQuerySucceeded := QueryOriginalInstallOwnerSid(InstallOwnerSid);
  if not OwnerQuerySucceeded then
    InstallOwnerSid := '';
  if InstallOwnerSid = '' then
  begin
    if not TryReuseExistingInstallOwnerSid() then
    begin
      if OwnerQuerySucceeded then
        Result := 'Windows вернула некорректный SID владельца установки POKROV.'
      else
        Result := 'Не удалось определить владельца установки POKROV.';
      exit;
    end;
  end;
  Exec(ExpandConstant('{sys}\net.exe'), 'stop POKROVService /y', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
end;

function GetInstallOwnerSid(Param: String): String;
begin
  Result := InstallOwnerSid;
end;

function ServiceExists(): Boolean;
begin
  Result := RegKeyExists(HKLM64,
    'SYSTEM\CurrentControlSet\Services\POKROVService');
end;

function ExecuteServiceCommand(const Parameters: String;
  var ResultCode: Integer): Boolean;
begin
  ResultCode := -1;
  Result := Exec(ExpandConstant('{sys}\sc.exe'), Parameters, '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

procedure AbortServiceSetup(const FailureCode: String;
  const CreatedBySetup: Boolean; const ResultCode: Integer);
var
  CleanupCode: Integer;
begin
  SetupFailureExitCode := 4;
  if CreatedBySetup then
  begin
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop POKROVService', '', SW_HIDE,
      ewWaitUntilTerminated, CleanupCode);
    Exec(ExpandConstant('{sys}\sc.exe'), 'delete POKROVService', '', SW_HIDE,
      ewWaitUntilTerminated, CleanupCode);
  end;
  if InstallOwnerRegistryValueExisted then
    RegWriteStringValue(HKLM64,
      'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
      InstallOwnerPreviousSid)
  else if InstallOwnerRegistryKeyExisted then
    RegDeleteValue(HKLM64, 'Software\space.pokrov\POKROV\Service',
      'InstallOwnerSid')
  else
    RegDeleteKeyIncludingSubkeys(HKLM64,
      'Software\space.pokrov\POKROV\Service');
  RaiseException(FailureCode + ' (SCM exit ' + IntToStr(ResultCode) + ').');
end;

procedure MigrateLegacyPerUserInstall(const CreatedBySetup: Boolean);
var
  ResultCode: Integer;
  LegacyBinary: String;
  LegacyUninstallRegistryKey: String;
begin
  if not LegacyPerUserInstallDetected then
    exit;
  LegacyBinary := AddBackslash(LegacyPerUserInstallDirectory) +
    'pokrov_windows.exe';
  LegacyUninstallRegistryKey :=
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}_is1';
  if not Exec(LegacyPerUserUninstaller,
      '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
    AbortServiceSetup('POKROV_LEGACY_PER_USER_UNINSTALL_FAILED',
      CreatedBySetup, ResultCode);
  if RegKeyExists(HKCU, LegacyUninstallRegistryKey) or
      FileExists(LegacyBinary) then
    AbortServiceSetup('POKROV_LEGACY_PER_USER_RESIDUAL_FOUND',
      CreatedBySetup, -1);
  Log('POKROV_LEGACY_PER_USER_MIGRATION_COMPLETE');
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := SetupFailureExitCode;
end;

procedure DeinitializeSetup;
var
  CleanupCode: Integer;
  UninstallerPath: String;
begin
  if SetupFailureExitCode = 0 then
    exit;
  UninstallerPath := ExpandConstant('{uninstallexe}');
  if FileExists(UninstallerPath) then
  begin
    if not Exec(UninstallerPath,
        '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
        ewWaitUntilTerminated, CleanupCode) or (CleanupCode <> 0) then
      Log('POKROV_SERVICE_FAILURE_UNINSTALL_CLEANUP_FAILED exit=' +
        IntToStr(CleanupCode));
  end
  else
    Log('POKROV_SERVICE_FAILURE_UNINSTALLER_MISSING');
end;

procedure InstallAndStartService;
var
  CreatedBySetup: Boolean;
  ResultCode: Integer;
  ServiceBinary: String;
begin
  CreatedBySetup := not ServiceExists();
  InstallOwnerRegistryKeyExisted := RegKeyExists(HKLM64,
    'Software\space.pokrov\POKROV\Service');
  InstallOwnerRegistryValueExisted := RegQueryStringValue(HKLM64,
    'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
    InstallOwnerPreviousSid);
  if not RegWriteStringValue(HKLM64,
      'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
      InstallOwnerSid) then
    AbortServiceSetup('POKROV_SERVICE_OWNER_BINDING_FAILED', CreatedBySetup,
      -1);
  ServiceBinary := ExpandConstant('{app}\pokrov_service.exe');
  if CreatedBySetup then
  begin
    if not ExecuteServiceCommand(
      'create POKROVService binPath= "' + ServiceBinary +
      '" start= auto DisplayName= "POKROV Service"', ResultCode) then
      AbortServiceSetup('POKROV_SERVICE_CREATE_FAILED', CreatedBySetup,
        ResultCode);
  end
  else
  begin
    if not ExecuteServiceCommand(
      'config POKROVService binPath= "' + ServiceBinary +
      '" start= auto DisplayName= "POKROV Service"', ResultCode) then
      AbortServiceSetup('POKROV_SERVICE_CONFIG_FAILED', CreatedBySetup,
        ResultCode);
  end;

  if not ExecuteServiceCommand(
    'description POKROVService "POKROV privileged runtime service"',
    ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_DESCRIPTION_FAILED', CreatedBySetup,
      ResultCode);
  if not ExecuteServiceCommand(
    'failure POKROVService reset= 86400 actions= restart/5000/restart/15000',
    ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_RECOVERY_FAILED', CreatedBySetup,
      ResultCode);
  if not ExecuteServiceCommand('start POKROVService', ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_START_FAILED', CreatedBySetup,
      ResultCode);
  MigrateLegacyPerUserInstall(CreatedBySetup);
end;