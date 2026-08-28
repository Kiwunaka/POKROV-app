[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$PlatformRoot,
  [Parameter(Mandatory = $true)][string]$CoreRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $root "scripts\new-release-handoff-v2.ps1"
$parity = Join-Path $root "scripts\check-client-version-parity.ps1"
$fixture = Join-Path $root "test\fixtures\release-handoff-v2\synthetic-candidate-input.json"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("pokrov-release-v2-{0}" -f [guid]::NewGuid().ToString("N"))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$powerShell = Join-Path $PSHOME "powershell.exe"
if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) {
  $powerShell = (Get-Process -Id $PID).Path
}

function Invoke-ChildScript {
  param([Parameter(Mandatory = $true)][string]$Script, [string[]]$Arguments = @())

  $commandArguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $Script
  ) + $Arguments
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $lines = @(& $powerShell @commandArguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = ($lines | Out-String).Trim()
  }
}

function Assert-Success {
  param([Parameter(Mandatory = $true)]$Result, [Parameter(Mandatory = $true)][string]$Case)

  if ($Result.ExitCode -ne 0) {
    throw "$Case failed unexpectedly: $($Result.Output)"
  }
}

function Assert-Failure {
  param([Parameter(Mandatory = $true)]$Result, [Parameter(Mandatory = $true)][string]$Case)

  if ($Result.ExitCode -eq 0) {
    throw "$Case succeeded unexpectedly."
  }
}

function Write-MutatedInput {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Mutation
  )

  $payload = [IO.File]::ReadAllText($fixture) | ConvertFrom-Json
  & $Mutation $payload
  $path = Join-Path $temporaryRoot "$Name.json"
  $json = ConvertTo-Json -InputObject $payload -Depth 20
  $json = ($json -replace "`r`n", "`n").TrimEnd() + "`n"
  [IO.File]::WriteAllText($path, $json, $utf8NoBom)
  return $path
}

function New-GeneratorArguments {
  param([string]$InputPath, [string]$OutputPath, [switch]$AllowDirty)

  $arguments = @(
    "-CandidateInputPath", $InputPath,
    "-OutputPath", $OutputPath,
    "-PlatformRoot", $PlatformRoot,
    "-CoreRoot", $CoreRoot
  )
  if ($AllowDirty) {
    $arguments += "-AllowDirtySynthetic"
  }
  return $arguments
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
  $firstOutput = Join-Path $temporaryRoot "generated-first.json"
  $secondOutput = Join-Path $temporaryRoot "generated-second.json"
  $first = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $fixture -OutputPath $firstOutput -AllowDirty)
  Assert-Success -Result $first -Case "first synthetic generation"
  $second = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $fixture -OutputPath $secondOutput -AllowDirty)
  Assert-Success -Result $second -Case "second synthetic generation"

  $firstHash = (Get-FileHash -LiteralPath $firstOutput -Algorithm SHA256).Hash
  $secondHash = (Get-FileHash -LiteralPath $secondOutput -Algorithm SHA256).Hash
  if ($firstHash -ne $secondHash) {
    throw "Repeated generation did not produce byte-identical metadata."
  }

  $generated = [IO.File]::ReadAllText($firstOutput) | ConvertFrom-Json
  if ([string]$generated.release.release_notes.summary -ne
        "POKROV 1.2.0 alpha: synthetic contract candidate." -or
      [string]$generated.release.release_notes.url -ne
        "https://github.com/Kiwunaka/pokrov/releases/tag/v1.2.0") {
    throw "Generated release notes are not derived from candidate input."
  }
  $androidBuildSource = [IO.File]::ReadAllText(
    (Join-Path $root "scripts\build-android-production.ps1")
  )
  $androidGradleSource = [IO.File]::ReadAllText(
    (Join-Path $root "apps\android_shell\android\app\build.gradle")
  )
  $windowsBuildSource = [IO.File]::ReadAllText(
    (Join-Path $root "scripts\build-windows-release.ps1")
  )
  $identitySource = [IO.File]::ReadAllText(
    (Join-Path $root "packages\app_shell\lib\app_first_runtime_bootstrap.dart")
  )
  $profileSource = [IO.File]::ReadAllText(
    (Join-Path $root "packages\app_shell\lib\src\features\profile\profile_surface.dart")
  )
  $navigationSource = [IO.File]::ReadAllText(
    (Join-Path $root "packages\app_shell\lib\src\shell\navigation_shell.dart")
  )
  if (-not $androidBuildSource.Contains(
        '--dart-define=POKROV_APP_VERSION=$declaredVersionName') -or
      -not $androidBuildSource.Contains(
        'if ($versionCode -ne $declaredVersionCode)') -or
      $androidBuildSource.Contains('"--split-per-abi"') -or
      -not $androidBuildSource.Contains(
        '--android-project-arg=pokrov.singleVersionSplitApks=true') -or
      -not $androidGradleSource.Contains(
        'gradleProperty("pokrov.singleVersionSplitApks")') -or
      -not $androidGradleSource.Contains('universalApk = singleVersionSplitApks') -or
      -not $androidBuildSource.Contains(
        'A production APK native ABI set does not match its artifact label.') -or
      -not $windowsBuildSource.Contains(
        '--dart-define=POKROV_APP_VERSION=$version') -or
      -not $identitySource.Contains(
        "const pokrovClientVersion = String.fromEnvironment(") -or
      -not $profileSource.Contains("pokrovClientVersion") -or
      -not $navigationSource.Contains("pokrovClientVersion")) {
    throw "Client version is not wired through one manifest-validated package identity."
  }
  $android = @($generated.artifacts | Where-Object { $_.platform -eq "android" })[0]
  $windows = @($generated.artifacts | Where-Object { $_.platform -eq "windows" })[0]
  if ($null -ne $android.core_abi -or [int]$windows.core_abi -ne 2 -or
      $generated.compatibility.core_abi.android_package -ne "space.pokrov.core") {
    throw "Generated Core ABI/package binding is incorrect."
  }
  $generatedContracts = @{}
  foreach ($contract in @($generated.compatibility.contracts)) {
    $generatedContracts[[string]$contract.id] = $contract
  }
  $expectedObservability = [IO.File]::ReadAllText(
    (Join-Path $root "config\observability-contracts.seed.json")
  ) | ConvertFrom-Json
  foreach ($expectedContract in @($expectedObservability.contracts)) {
    $generatedContract = $generatedContracts[[string]$expectedContract.id]
    if ($null -eq $generatedContract -or
        [string]$generatedContract.version -ne [string]$expectedContract.version -or
        [string]$generatedContract.sha256 -ne [string]$expectedContract.sha256) {
      throw "Generated observability release binding is incorrect."
    }
  }

  $dirtyDefaultOutput = Join-Path $temporaryRoot "dirty-default.json"
  $dirtySentinel = Join-Path $root (
    "release-v2-dirty-sentinel-{0}.txt" -f [guid]::NewGuid().ToString("N")
  )
  try {
    [IO.File]::WriteAllText($dirtySentinel, "synthetic dirty-worktree proof", $utf8NoBom)
    $dirtyDefault = Invoke-ChildScript -Script $generator `
      -Arguments (New-GeneratorArguments -InputPath $fixture -OutputPath $dirtyDefaultOutput)
    Assert-Failure -Result $dirtyDefault -Case "dirty worktree without synthetic bypass"
  } finally {
    if (Test-Path -LiteralPath $dirtySentinel -PathType Leaf) {
      Remove-Item -LiteralPath $dirtySentinel -Force
    }
  }

  $stableInput = Write-MutatedInput -Name "stable" -Mutation {
    param($payload)
    $payload.release.channel = "stable"
    $payload.promotion.target_channel = "stable"
  }
  $stableResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $stableInput `
      -OutputPath (Join-Path $temporaryRoot "stable.json") -AllowDirty)
  Assert-Failure -Result $stableResult -Case "dirty stable generation"

  $versionInput = Write-MutatedInput -Name "wrong-version" -Mutation {
    param($payload)
    $payload.release.version = "1.2.1"
    $payload.release.candidate_label = "pokrov-1.2.1"
  }
  $versionResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $versionInput `
      -OutputPath (Join-Path $temporaryRoot "wrong-version-output.json") -AllowDirty)
  Assert-Failure -Result $versionResult -Case "shell-version mismatch"

  $releaseNotesInput = Write-MutatedInput -Name "wrong-release-notes-url" -Mutation {
    param($payload)
    $payload.release.release_notes.url =
      "https://github.com/Kiwunaka/pokrov/releases/tag/v1.2.1"
  }
  $releaseNotesResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $releaseNotesInput `
      -OutputPath (Join-Path $temporaryRoot "wrong-release-notes-output.json") -AllowDirty)
  Assert-Failure -Result $releaseNotesResult -Case "release-notes version mismatch"

  $coreSourceInput = Write-MutatedInput -Name "wrong-core-source" -Mutation {
    param($payload)
    $payload.sources.core.revision = "cccccccccccccccccccccccccccccccccccccccc"
  }
  $coreSourceResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $coreSourceInput `
      -OutputPath (Join-Path $temporaryRoot "wrong-core-source-output.json") -AllowDirty)
  Assert-Failure -Result $coreSourceResult -Case "Core source mismatch"

  $androidAbiInput = Write-MutatedInput -Name "invented-android-abi" -Mutation {
    param($payload)
    $payload.artifacts[0] | Add-Member -NotePropertyName "core_abi" -NotePropertyValue 2
  }
  $androidAbiResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $androidAbiInput `
      -OutputPath (Join-Path $temporaryRoot "invented-android-abi-output.json") -AllowDirty)
  Assert-Failure -Result $androidAbiResult -Case "invented Android integer ABI"

  $derivedContractInput = Write-MutatedInput -Name "caller-observability-contract" -Mutation {
    param($payload)
    $payload.compatibility.contracts += [pscustomobject]@{
      id = "observability-event"
      version = "1.0.0"
      sha256 = "0" * 64
    }
  }
  $derivedContractResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $derivedContractInput `
      -OutputPath (Join-Path $temporaryRoot "caller-observability-output.json") -AllowDirty)
  Assert-Failure -Result $derivedContractResult -Case "caller-supplied observability contract"

  $evidenceInput = Write-MutatedInput -Name "invalid-evidence" -Mutation {
    param($payload)
    $payload.artifacts[0].signing.status = "PASS"
  }
  $evidenceResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $evidenceInput `
      -OutputPath (Join-Path $temporaryRoot "invalid-evidence-output.json") -AllowDirty)
  Assert-Failure -Result $evidenceResult -Case "invalid evidence"

  foreach ($platformName in @("android", "windows")) {
    $runtimeMutation = [IO.File]::ReadAllText(
      (Join-Path $root "config\runtime-artifacts.seed.json")
    ) | ConvertFrom-Json
    $runtimeMutation.core.assets.$platformName.sha256 = "0" * 64
    $runtimeMutationPath = Join-Path $temporaryRoot "runtime-$platformName.json"
    $runtimeMutationJson = ConvertTo-Json -InputObject $runtimeMutation -Depth 20
    [IO.File]::WriteAllText($runtimeMutationPath, $runtimeMutationJson, $utf8NoBom)
    $parityResult = Invoke-ChildScript -Script $parity `
      -Arguments @("-RuntimeArtifactsPath", $runtimeMutationPath, "-CoreRoot", $CoreRoot)
    Assert-Failure -Result $parityResult -Case "$platformName Core artifact digest mismatch"
  }

  $forbiddenName = "wo003-forbidden-{0}.json" -f [guid]::NewGuid().ToString("N")
  $forbiddenOutput = Join-Path $root "artifacts\releases\$forbiddenName"
  $forbiddenResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $fixture `
      -OutputPath $forbiddenOutput -AllowDirty)
  Assert-Failure -Result $forbiddenResult -Case "retained release destination"
  if (Test-Path -LiteralPath $forbiddenOutput) {
    throw "Generator wrote to the forbidden retained release destination."
  }

  $trackedSourceOutput = Join-Path $root ("wo003-tracked-source-{0}.json" -f [guid]::NewGuid().ToString("N"))
  $trackedSourceResult = Invoke-ChildScript -Script $generator `
    -Arguments (New-GeneratorArguments -InputPath $fixture `
      -OutputPath $trackedSourceOutput -AllowDirty)
  Assert-Failure -Result $trackedSourceResult -Case "tracked client source destination"
  if (Test-Path -LiteralPath $trackedSourceOutput) {
    throw "Generator wrote candidate metadata into the tracked client source tree."
  }

  Write-Host "Release-handoff v2 client contract OK: 16 cases." -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
