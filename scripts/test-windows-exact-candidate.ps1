[CmdletBinding()]
param(
  [string]$CandidatePath = "build/private-candidate/pokrov-windows-setup-x64.exe",
  [string]$GateInputPath = "config/windows-clean-host-gate.candidate-3.json",
  [string]$EvidencePath = "build/evidence/windows-exact-candidate-clean-host.json",
  [switch]$RunCleanHostSmoke,
  [switch]$RunOwnerCurrentHostSmoke,
  [string]$OwnerCurrentHostConfirmation = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepositoryPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $Path))
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory = $true)][string[]]$Lines)

  $text = [string]::Join("`n", $Lines)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
  return [Convert]::ToHexString(
    [System.Security.Cryptography.SHA256]::HashData($bytes)
  ).ToLowerInvariant()
}

function Add-Check {
  param(
    [AllowEmptyCollection()]
    [Parameter(Mandatory = $true)][System.Collections.Generic.List[object]]$Checks,
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$Detail
  )

  $Checks.Add([ordered]@{
      id = $Id
      status = $Status
      detail = $Detail
    })
}

function Assert-Gate {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Code
  )

  if (-not $Condition) {
    throw $Code
  }
}

function Get-NetworkFingerprint {
  $routes = @(
    Get-NetRoute -PolicyStore ActiveStore -ErrorAction Stop |
      Sort-Object AddressFamily, DestinationPrefix, InterfaceIndex, NextHop, RouteMetric, Protocol |
      ForEach-Object {
        "$($_.AddressFamily)|$($_.DestinationPrefix)|$($_.InterfaceIndex)|$($_.NextHop)|$($_.RouteMetric)|$($_.Protocol)"
      }
  )
  $dns = @(
    Get-DnsClientServerAddress -ErrorAction Stop |
      Sort-Object InterfaceIndex, AddressFamily |
      ForEach-Object {
        "$($_.InterfaceIndex)|$($_.AddressFamily)|$([string]::Join(',', @($_.ServerAddresses)))"
      }
  )
  $tunnelAdapters = @(
    Get-NetAdapter -IncludeHidden -ErrorAction Stop |
      Where-Object {
        $_.Name -match '(?i)pokrov|wintun' -or
        $_.InterfaceDescription -match '(?i)pokrov|wintun'
      }
  )

  return [ordered]@{
    route_sha256 = Get-TextSha256 -Lines $routes
    dns_sha256 = Get-TextSha256 -Lines $dns
    tunnel_adapter_count = $tunnelAdapters.Count
  }
}

function Wait-ServiceState {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$State,
    [int]$TimeoutSeconds = 30
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $service) {
      $service.Refresh()
      if ([string]$service.Status -eq $State) {
        return $true
      }
    } elseif ($State -eq "Absent") {
      return $true
    }
    Start-Sleep -Milliseconds 500
  } while ((Get-Date) -lt $deadline)

  return $false
}

function Get-SanitizedServiceFailureDiagnostics {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$RegistryPath,
    [Parameter(Mandatory = $true)][string]$ExpectedBinaryPath,
    [Parameter(Mandatory = $true)][string]$JournalPath,
    [Parameter(Mandatory = $true)][datetime]$SinceUtc
  )

  $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
  $ownerSid = $null
  try {
    $ownerSid = [string](Get-ItemProperty -LiteralPath $RegistryPath -Name InstallOwnerSid -ErrorAction Stop).InstallOwnerSid
  } catch {
    $ownerSid = $null
  }
  $currentSid = [string][Security.Principal.WindowsIdentity]::GetCurrent().User.Value

  $journalSummary = @()
  if (Test-Path -LiteralPath $JournalPath -PathType Leaf) {
    $journalSummary = @(
      Get-Content -LiteralPath $JournalPath -ErrorAction SilentlyContinue |
        Select-Object -Last 32 |
        ForEach-Object {
          $fields = @(([string]$_).Split('|'))
          if ($fields.Count -ge 8 -and $fields[0] -eq 'POKROV_SERVICE_EVENT_V1') {
            [ordered]@{
              event = $fields[3]
              outcome = $fields[4]
              command = $fields[5]
              status = $fields[6]
            }
          }
        }
    )
  }

  $scmEventIds = @(
    Get-WinEvent -FilterHashtable @{
      LogName = 'System'
      ProviderName = 'Service Control Manager'
      StartTime = $SinceUtc.ToLocalTime()
    } -ErrorAction SilentlyContinue |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_.Message) -and $_.Message.Contains($Name) } |
      ForEach-Object { [int]$_.Id } |
      Sort-Object -Unique
  )

  return [ordered]@{
    scm_record_present = $null -ne $service
    scm_state = if ($null -ne $service) { [string]$service.State } else { 'Absent' }
    scm_status = if ($null -ne $service) { [string]$service.Status } else { 'Absent' }
    scm_start_mode = if ($null -ne $service) { [string]$service.StartMode } else { $null }
    scm_exit_code = if ($null -ne $service) { [uint32]$service.ExitCode } else { $null }
    service_specific_exit_code = if ($null -ne $service) { [uint32]$service.ServiceSpecificExitCode } else { $null }
    process_running = $null -ne $service -and [uint32]$service.ProcessId -ne 0
    binary_path_matches_expected = $null -ne $service -and
      ([string]$service.PathName).Contains($ExpectedBinaryPath, [StringComparison]::OrdinalIgnoreCase)
    owner_sid_present = -not [string]::IsNullOrWhiteSpace($ownerSid)
    owner_sid_matches_runner = -not [string]::IsNullOrWhiteSpace($ownerSid) -and
      $ownerSid -eq $currentSid
    event_journal_present = Test-Path -LiteralPath $JournalPath -PathType Leaf
    event_journal_summary = $journalSummary
    scm_event_ids = $scmEventIds
  }
}

function Write-Evidence {
  param(
    [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Evidence,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $directory = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $Evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

$candidate = Resolve-RepositoryPath -Path $CandidatePath
$gateInputFile = Resolve-RepositoryPath -Path $GateInputPath
$evidenceFile = Resolve-RepositoryPath -Path $EvidencePath
$runSmoke = $RunCleanHostSmoke -or $RunOwnerCurrentHostSmoke

Assert-Gate -Condition (-not ($RunCleanHostSmoke -and $RunOwnerCurrentHostSmoke)) -Code "smoke_mode_conflict"

Assert-Gate -Condition (Test-Path -LiteralPath $candidate -PathType Leaf) -Code "candidate_missing"
Assert-Gate -Condition (Test-Path -LiteralPath $gateInputFile -PathType Leaf) -Code "gate_input_missing"

$gateInput = Get-Content -LiteralPath $gateInputFile -Raw | ConvertFrom-Json -Depth 20
Assert-Gate -Condition ($gateInput.schema -eq "pokrov.windows-clean-host-gate-input/v1") -Code "gate_input_schema_invalid"
$knownCandidates = @{
  "pokrov-1.2.0-candidate.3" = [ordered]@{
    manifest = "a2752b6a3b95faacf13a68edb708c560966a0f5eb8727e109d7f1603fdc81090"
    signature = "926f0b4667a58ba9cc5ace5c4e6c3c8129d1ec3d4d449b3f0831a8c527cd7121"
    client = "ac22825e857a313c9e4eba61030eb548d6346ead"
    core = "344b317a7a09eca7943a93866b193553538bd8f6"
    platform = "eafaca3e64c0619dea7f58fc9c430682b4520559"
    release_index = "6a1afa95fe52da2d559ba7b1da88715cd0344bb2"
  }
  "pokrov-1.2.0-candidate.8" = [ordered]@{
    manifest = "f0006cec90c84e401e9920d9098102c7f50ab5ace5242e0d7683c3df709a6fbc"
    signature = "5fcae0675ea45e79baf495859fd170661f5d6dd3a8535275acd4d62680d324f6"
    client = "3459438f02bd774e722b1b858e7f7f16d57a9f5c"
    core = "a45d69e40ed7d892619a2b5c4592a527f630665e"
    platform = "241a83b4dca00799b39696a4ae0c3c97e087ec39"
    release_index = "b242e0a3060b04f9b71641a0524bf251a75ce2a8"
  }
  "pokrov-1.2.0-candidate.16" = [ordered]@{
    manifest = "ae1906e68df755b1e0ce6a77d6ede8256f923e72fe11da57f1cae89a82c4ffe6"
    signature = "f5df63578d56db84a48eac1c68f1192e81462e8b407b1b6ff877c2b415507a9a"
    client = "75ba7e721cfee486f7189edd51de97aba2746722"
    core = "cd8f0f4169d570d693992a959d81d17c2c44884d"
    platform = "719e23dc49407beb9ae30d98d17d4b73d18ae37c"
    release_index = "54cfa03502ffafa5e4fb230a2cbdb0c0572c429f"
  }
}
$candidateLabel = [string]$gateInput.candidate_label
Assert-Gate -Condition $knownCandidates.ContainsKey($candidateLabel) -Code "candidate_label_invalid"
$knownCandidate = $knownCandidates[$candidateLabel]
Assert-Gate -Condition ($gateInput.candidate_manifest_sha256 -eq $knownCandidate.manifest) -Code "candidate_manifest_identity_invalid"
Assert-Gate -Condition ($gateInput.candidate_manifest_signature_sha256 -eq $knownCandidate.signature) -Code "candidate_manifest_signature_identity_invalid"
Assert-Gate -Condition ($gateInput.source_tuple.client -eq $knownCandidate.client) -Code "candidate_client_source_invalid"
Assert-Gate -Condition ($gateInput.source_tuple.core -eq $knownCandidate.core) -Code "candidate_core_source_invalid"
Assert-Gate -Condition ($gateInput.source_tuple.platform -eq $knownCandidate.platform) -Code "candidate_platform_source_invalid"
Assert-Gate -Condition ($gateInput.source_tuple.release_index -eq $knownCandidate.release_index) -Code "candidate_release_index_source_invalid"

$candidateSha256 = Get-Sha256 -Path $candidate
$candidateSize = (Get-Item -LiteralPath $candidate).Length
Assert-Gate -Condition ($candidateSha256 -eq [string]$gateInput.artifact.sha256) -Code "candidate_sha256_mismatch"
Assert-Gate -Condition ($candidateSize -eq [int64]$gateInput.artifact.size_bytes) -Code "candidate_size_mismatch"
Assert-Gate -Condition ($gateInput.artifact.signing_status -eq "SKIPPED_BY_OWNER") -Code "owner_exception_missing"
Assert-Gate -Condition ($gateInput.artifact.owner_exception -eq "OWNER_ACCEPTED_UNSIGNED_WINDOWS_BETA_1_2_0") -Code "owner_exception_scope_invalid"
Assert-Gate -Condition ($gateInput.artifact.smartscreen_warning_required -eq $true) -Code "smartscreen_warning_contract_missing"

$authenticode = Get-AuthenticodeSignature -LiteralPath $candidate
Assert-Gate -Condition ([string]$authenticode.Status -eq "NotSigned") -Code "unexpected_authenticode_state"

$checks = [System.Collections.Generic.List[object]]::new()
Add-Check -Checks $checks -Id "exact_candidate_identity" -Status "PASS" -Detail "$candidateLabel SHA-256, byte size, signed-manifest identity, and source tuple match the reviewed input"
Add-Check -Checks $checks -Id "unsigned_owner_exception" -Status "SKIPPED_BY_OWNER" -Detail "direct-download 1.2.0 beta only; SmartScreen warning remains mandatory"

$evidence = [ordered]@{
  schema = "pokrov.windows-exact-candidate-clean-host-evidence/v1"
  status = if ($runSmoke) { "RUNNING" } else { "PASS_VALIDATION_ONLY" }
  recorded_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  candidate_label = [string]$gateInput.candidate_label
  candidate_manifest_sha256 = [string]$gateInput.candidate_manifest_sha256
  candidate_manifest_signature_sha256 = [string]$gateInput.candidate_manifest_signature_sha256
  candidate_sha256 = $candidateSha256
  candidate_size_bytes = $candidateSize
  candidate_authenticode = [string]$authenticode.Status
  owner_exception = [string]$gateInput.artifact.owner_exception
  source_tuple = [ordered]@{
    client = [string]$gateInput.source_tuple.client
    core = [string]$gateInput.source_tuple.core
    platform = [string]$gateInput.source_tuple.platform
    release_index = [string]$gateInput.source_tuple.release_index
  }
  runner = [ordered]@{
    environment = if ($RunCleanHostSmoke) { "github-hosted" } elseif ($RunOwnerCurrentHostSmoke) { "owner-current-host" } else { "local_validation" }
    host_cleanliness_claim = if ($RunCleanHostSmoke) { "github_hosted_ephemeral_runner" } elseif ($RunOwnerCurrentHostSmoke) { "clean_app_state_only_not_clean_os_or_vm" } else { "not_observed" }
    os = if ($RunCleanHostSmoke) { [string]$env:RUNNER_OS } else { "Windows" }
    image_os = if ($RunCleanHostSmoke) { [string]$env:ImageOS } else { $null }
    image_version = if ($RunCleanHostSmoke) { [string]$env:ImageVersion } else { $null }
    github_run_id = if ($RunCleanHostSmoke) { [string]$env:GITHUB_RUN_ID } else { $null }
    github_run_attempt = if ($RunCleanHostSmoke) { [string]$env:GITHUB_RUN_ATTEMPT } else { $null }
    workflow_commit = if ($RunCleanHostSmoke) { [string]$env:GITHUB_SHA } else { $null }
  }
  checks = $checks
  evidence_ceiling = [string]$gateInput.evidence_ceiling
  manual_or_blocked_checks = @(
    "MANUAL_OWNER_TEST: live TUN and full-tunnel traffic",
    "MANUAL_OWNER_TEST: DNS capture and leak protection while connected",
    "MANUAL_OWNER_TEST: authenticated egress through an owned profile",
    "MANUAL_OWNER_TEST: sleep, reboot, and crash recovery",
    "MANUAL_OWNER_TEST: uninstall while connected",
    "MANUAL_OWNER_TEST: interactive SmartScreen reputation observation"
  )
  production_mutation_performed = $false
  current_host_mutation_performed = $false
  public_release_created = $false
  stable_pointer_mutated = $false
}

if (-not $runSmoke) {
  Write-Evidence -Evidence $evidence -Path $evidenceFile
  Write-Host "Exact Windows candidate validation passed: $candidateSha256"
  exit 0
}

if ($RunCleanHostSmoke) {
  Assert-Gate -Condition ($env:GITHUB_ACTIONS -eq "true") -Code "clean_host_gate_requires_github_actions"
  Assert-Gate -Condition ($env:RUNNER_ENVIRONMENT -eq "github-hosted") -Code "clean_host_gate_requires_github_hosted_runner"
  Assert-Gate -Condition ($env:RUNNER_OS -eq "Windows") -Code "clean_host_gate_requires_windows"
} else {
  $currentHostConfirmations = @{
    "pokrov-1.2.0-candidate.8" = "OWNER_AUTHORIZED_CURRENT_HOST_CANDIDATE8_SMOKE"
    "pokrov-1.2.0-candidate.16" = "OWNER_AUTHORIZED_CURRENT_HOST_CANDIDATE16_SMOKE"
  }
  Assert-Gate -Condition $currentHostConfirmations.ContainsKey($candidateLabel) -Code "owner_current_host_mode_candidate_scope_invalid"
  Assert-Gate -Condition ($OwnerCurrentHostConfirmation -ceq $currentHostConfirmations[$candidateLabel]) -Code "owner_current_host_confirmation_invalid"
  Assert-Gate -Condition ($env:GITHUB_ACTIONS -ne "true") -Code "owner_current_host_mode_rejects_github_actions"
}

$principal = [Security.Principal.WindowsPrincipal]::new(
  [Security.Principal.WindowsIdentity]::GetCurrent()
)
Assert-Gate -Condition $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -Code "clean_host_gate_requires_administrator"

$serviceName = [string]$gateInput.installation.service_name
$installRoot = Join-Path $env:ProgramFiles ([string]$gateInput.installation.directory)
$serviceRegistryPath = [string]$gateInput.installation.registry_path
$runtimeRoot = Join-Path $env:ProgramData "POKROV\ServiceRuntime"
$eventJournal = Join-Path $runtimeRoot "service-events.v1.log"
$runnerTemp = if ([string]::IsNullOrWhiteSpace([string]$env:RUNNER_TEMP)) { [System.IO.Path]::GetTempPath() } else { [string]$env:RUNNER_TEMP }
$safeCandidateLabel = $candidateLabel.Replace("pokrov-1.2.0-", "pokrov-")
$installerLog = Join-Path $runnerTemp "$safeCandidateLabel-install.log"
$uninstallerLog = Join-Path $runnerTemp "$safeCandidateLabel-uninstall.log"
$uiProcess = $null
$installed = $false
$uninstalled = $false
$failureStage = $null
$failure = $null
$baselineNetwork = $null
$afterNetwork = $null
$currentHostMutationPerformed = $false

try {
  $failureStage = "clean_baseline"
  Assert-Gate -Condition ($null -eq (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) -Code "baseline_service_present"
  Assert-Gate -Condition (-not (Test-Path -LiteralPath $installRoot)) -Code "baseline_install_directory_present"
  Assert-Gate -Condition (-not (Test-Path -LiteralPath $serviceRegistryPath)) -Code "baseline_service_registry_present"
  $baselineNetwork = Get-NetworkFingerprint
  Assert-Gate -Condition ($baselineNetwork.tunnel_adapter_count -eq 0) -Code "baseline_tunnel_adapter_present"
  if ($RunCleanHostSmoke) {
    Add-Check -Checks $checks -Id "clean_host_baseline" -Status "PASS" -Detail "service, install directory, registry owner record, and POKROV/Wintun adapter were absent on the ephemeral runner"
  } else {
    Add-Check -Checks $checks -Id "current_host_clean_app_state_baseline" -Status "PASS" -Detail "service, install directory, registry owner record, and POKROV/Wintun adapter were absent; this does not claim a clean OS or VM"
  }

  $failureStage = "install"
  $installStartedAtUtc = (Get-Date).ToUniversalTime()
  $installArguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG=`"$installerLog`""
  $currentHostMutationPerformed = $RunOwnerCurrentHostSmoke.IsPresent
  $install = Start-Process -FilePath $candidate -ArgumentList $installArguments -Wait -PassThru
  Assert-Gate -Condition ($install.ExitCode -eq 0) -Code "installer_exit_nonzero"
  $installed = $true
  Assert-Gate -Condition (Test-Path -LiteralPath $installRoot -PathType Container) -Code "install_directory_missing"
  Add-Check -Checks $checks -Id "machine_wide_install" -Status "PASS" -Detail "exact installer completed silently with exit code 0"

  $failureStage = "installed_bytes"
  foreach ($required in @($gateInput.installation.required_files)) {
    $relativePath = ([string]$required.path).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $installedPath = Join-Path $installRoot $relativePath
    Assert-Gate -Condition (Test-Path -LiteralPath $installedPath -PathType Leaf) -Code "installed_required_file_missing"
    Assert-Gate -Condition ((Get-Item -LiteralPath $installedPath).Length -eq [int64]$required.size_bytes) -Code "installed_required_file_size_mismatch"
    Assert-Gate -Condition ((Get-Sha256 -Path $installedPath) -eq ([string]$required.sha256).ToLowerInvariant()) -Code "installed_required_file_sha256_mismatch"
  }
  Add-Check -Checks $checks -Id "installed_file_identity" -Status "PASS" -Detail "all 8 manifest-bound installed files match size and SHA-256"

  $failureStage = "service_contract"
  $serviceRunning = Wait-ServiceState -Name $serviceName -State "Running"
  if (-not $serviceRunning) {
    $evidence.service_failure_diagnostics = Get-SanitizedServiceFailureDiagnostics `
      -Name $serviceName `
      -RegistryPath $serviceRegistryPath `
      -ExpectedBinaryPath (Join-Path $installRoot "pokrov_service.exe") `
      -JournalPath $eventJournal `
      -SinceUtc $installStartedAtUtc
  }
  Assert-Gate -Condition $serviceRunning -Code "service_not_running"
  $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'"
  Assert-Gate -Condition ($null -ne $service) -Code "service_cim_missing"
  Assert-Gate -Condition ($service.StartMode -eq "Auto") -Code "service_start_mode_invalid"
  Assert-Gate -Condition ($service.StartName -eq "LocalSystem") -Code "service_identity_invalid"
  Assert-Gate -Condition ($service.PathName -match [regex]::Escape((Join-Path $installRoot "pokrov_service.exe"))) -Code "service_binary_path_invalid"
  $ownerSid = (Get-ItemProperty -LiteralPath $serviceRegistryPath -Name InstallOwnerSid).InstallOwnerSid
  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  Assert-Gate -Condition ($ownerSid -eq $currentSid) -Code "install_owner_sid_mismatch"
  Add-Check -Checks $checks -Id "service_install_and_identity" -Status "PASS" -Detail "automatic LocalSystem service runs exact installed binary and is bound to the install owner"

  $failureStage = "ui_authenticated_ipc"
  $uiPath = Join-Path $installRoot "pokrov_windows.exe"
  $uiProcess = Start-Process -FilePath $uiPath -WorkingDirectory $installRoot -PassThru
  Start-Sleep -Seconds 5
  Assert-Gate -Condition (-not $uiProcess.HasExited) -Code "ui_process_exited_early"
  $ipcDeadline = (Get-Date).AddSeconds(30)
  $ipcAccepted = $false
  $statusRequested = $false
  do {
    if (Test-Path -LiteralPath $eventJournal -PathType Leaf) {
      $journalText = Get-Content -LiteralPath $eventJournal -Raw -ErrorAction SilentlyContinue
      $ipcAccepted = $journalText -match '\|ipc_session_accepted\|accepted\|'
      $statusRequested = $journalText -match '\|ipc_request\|attempted\|status\|'
    }
    if (-not ($ipcAccepted -and $statusRequested)) {
      Start-Sleep -Milliseconds 500
    }
  } while (-not ($ipcAccepted -and $statusRequested) -and (Get-Date) -lt $ipcDeadline)
  Assert-Gate -Condition ($ipcAccepted -and $statusRequested) -Code "authenticated_ipc_evidence_missing"
  Add-Check -Checks $checks -Id "ui_service_authenticated_ipc" -Status "PASS" -Detail "installed UI stayed alive and the protected service journal recorded an accepted IPC session plus status request"

  $failureStage = "service_restart"
  if ($null -ne $uiProcess -and -not $uiProcess.HasExited) {
    Stop-Process -Id $uiProcess.Id -Force
    $uiProcess.WaitForExit(10000) | Out-Null
  }
  $uiProcess = $null
  Stop-Service -Name $serviceName -Force
  Assert-Gate -Condition (Wait-ServiceState -Name $serviceName -State "Stopped") -Code "service_stop_failed"
  Start-Service -Name $serviceName
  Assert-Gate -Condition (Wait-ServiceState -Name $serviceName -State "Running") -Code "service_restart_failed"
  Add-Check -Checks $checks -Id "service_stop_restart" -Status "PASS" -Detail $(
    if ($RunCleanHostSmoke) {
      "SCM stop and restart completed on the ephemeral runner"
    } else {
      "SCM stop and restart completed on the owner current host"
    }
  )

  $failureStage = "uninstall"
  $uninstaller = Join-Path $installRoot "unins000.exe"
  Assert-Gate -Condition (Test-Path -LiteralPath $uninstaller -PathType Leaf) -Code "uninstaller_missing"
  $uninstallArguments = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG=`"$uninstallerLog`""
  $uninstall = Start-Process -FilePath $uninstaller -ArgumentList $uninstallArguments -Wait -PassThru
  Assert-Gate -Condition ($uninstall.ExitCode -eq 0) -Code "uninstaller_exit_nonzero"
  $uninstalled = $true
  Assert-Gate -Condition (Wait-ServiceState -Name $serviceName -State "Absent") -Code "service_residual_after_uninstall"
  Assert-Gate -Condition (-not (Test-Path -LiteralPath $installRoot)) -Code "install_directory_residual_after_uninstall"
  Assert-Gate -Condition (-not (Test-Path -LiteralPath $serviceRegistryPath)) -Code "service_registry_residual_after_uninstall"
  Add-Check -Checks $checks -Id "clean_uninstall" -Status "PASS" -Detail "uninstaller exited 0 and removed the service, installed files, and owner registry record"

  $failureStage = "network_restoration"
  Start-Sleep -Seconds 3
  $afterNetwork = Get-NetworkFingerprint
  Assert-Gate -Condition ($afterNetwork.route_sha256 -eq $baselineNetwork.route_sha256) -Code "route_fingerprint_changed"
  Assert-Gate -Condition ($afterNetwork.dns_sha256 -eq $baselineNetwork.dns_sha256) -Code "dns_fingerprint_changed"
  Assert-Gate -Condition ($afterNetwork.tunnel_adapter_count -eq 0) -Code "tunnel_adapter_residual"
  Add-Check -Checks $checks -Id "idle_network_restoration" -Status "PASS" -Detail "route and DNS fingerprints are unchanged and no POKROV/Wintun adapter remains"

  Add-Check -Checks $checks -Id "service_runtime_data" -Status "OBSERVED" -Detail $(
    if (Test-Path -LiteralPath $runtimeRoot) {
      "bounded service runtime evidence remains under ProgramData; no raw content is exported"
    } else {
      "no service runtime directory remained"
    }
  )
} catch {
  $failure = $_
} finally {
  if ($null -ne $uiProcess -and -not $uiProcess.HasExited) {
    Stop-Process -Id $uiProcess.Id -Force -ErrorAction SilentlyContinue
  }
  if ($installed -and -not $uninstalled) {
    $fallbackUninstaller = Join-Path $installRoot "unins000.exe"
    if (Test-Path -LiteralPath $fallbackUninstaller -PathType Leaf) {
      Start-Process -FilePath $fallbackUninstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait -ErrorAction SilentlyContinue | Out-Null
    } else {
      Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
      & sc.exe delete $serviceName | Out-Null
    }
  }
}

if ($null -ne $failure) {
  $evidence.status = "FAIL"
  $evidence.failure_stage = $failureStage
  $evidence.failure_code = [string]$failure.Exception.Message
} else {
  $evidence.status = if ($RunCleanHostSmoke) {
    "PASS_EXACT_PRIVATE_CI_INSTALL_SERVICE_IPC_RESTART_UNINSTALL_IDLE_NETWORK"
  } else {
    "PASS_EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE_INSTALL_SERVICE_IPC_RESTART_UNINSTALL_IDLE_NETWORK"
  }
  $evidence.failure_stage = $null
  $evidence.failure_code = $null
}
$evidence.current_host_mutation_performed = $currentHostMutationPerformed
$evidence.recorded_at_utc = (Get-Date).ToUniversalTime().ToString("o")
Write-Evidence -Evidence $evidence -Path $evidenceFile

if ($null -ne $failure) {
  throw "Exact Windows candidate clean-host gate failed at $failureStage."
}

Write-Host "Exact Windows candidate clean-host gate passed: $candidateSha256"
