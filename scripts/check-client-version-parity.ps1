[CmdletBinding()]
param(
  [string]$CandidateVersion,
  [string]$RuntimeArtifactsPath,
  [string]$ReleaseHandoffPath,
  [string]$WindowsReleasePath,
  [string]$CoreRoot
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot

function Read-PackageVersion {
  param([Parameter(Mandatory = $true)][string]$Path)

  $text = [IO.File]::ReadAllText($Path)
  $match = [regex]::Match($text, '(?m)^version:\s*([^\s]+)\s*$')
  if (-not $match.Success) {
    throw "Could not read package version from $Path"
  }
  return $match.Groups[1].Value.Trim()
}

function Get-PublicVersion {
  param([Parameter(Mandatory = $true)][string]$PackageVersion)

  $match = [regex]::Match(
    $PackageVersion,
    '^(?<public>[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?)(?:\+[A-Za-z0-9.-]+)?$'
  )
  if (-not $match.Success) {
    throw "Client package version is not a supported semantic version."
  }
  return $match.Groups['public'].Value
}

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required JSON contract is missing: $Path"
  }
  return [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Assert-SameStringSet {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][object[]]$Actual,
    [Parameter(Mandatory = $true)][object[]]$Expected
  )

  $actualValues = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive -Unique)
  $expectedValues = @($Expected | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive -Unique)
  $difference = @(Compare-Object -ReferenceObject $expectedValues -DifferenceObject $actualValues -CaseSensitive)
  if ($difference.Count -ne 0 -or $actualValues.Count -ne $expectedValues.Count) {
    throw "$Label disagrees with the active client runtime contract."
  }
}

function Assert-ArtifactIdentity {
  param(
    [Parameter(Mandatory = $true)][string]$Platform,
    [Parameter(Mandatory = $true)]$Asset
  )

  $artifactPath = Join-Path $root $Asset.sync_destination
  $artifactPath = Join-Path $artifactPath $Asset.entry
  if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
    throw "Pinned $Platform Core artifact is missing from the client checkout."
  }

  $file = Get-Item -LiteralPath $artifactPath
  $actualHash = (
    Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  if ([int64]$file.Length -ne [int64]$Asset.size) {
    throw "Pinned $Platform Core artifact size does not match runtime-artifacts.seed.json."
  }
  if ($actualHash -ne ([string]$Asset.sha256).ToLowerInvariant()) {
    throw "Pinned $Platform Core artifact SHA-256 does not match runtime-artifacts.seed.json."
  }
}

function Assert-CoreAuthority {
  param(
    [Parameter(Mandatory = $true)][string]$CorePath,
    [Parameter(Mandatory = $true)]$RuntimeCore
  )

  $resolvedCorePath = (Resolve-Path -LiteralPath $CorePath).Path
  $release = Read-JsonFile (Join-Path $resolvedCorePath "config\release.json")
  if ([string]::IsNullOrWhiteSpace([string]$release.abi_contract)) {
    throw "POKROV Core release metadata does not name an ABI contract."
  }
  $abiContractPath = Join-Path $resolvedCorePath ([string]$release.abi_contract).Replace('/', '\')
  $abiContract = Read-JsonFile $abiContractPath
  $revisionLines = @(& git.exe -C $resolvedCorePath rev-parse HEAD 2>&1)
  $revisionExitCode = $LASTEXITCODE
  if ($revisionExitCode -ne 0 -or $revisionLines.Count -eq 0) {
    throw "Could not resolve the exact POKROV Core Git revision."
  }
  $revision = ([string]$revisionLines[0]).Trim().ToLowerInvariant()

  $coreTarget = $RuntimeCore.development_target
  $retainedRelease = $release.retained_public_release
  if ($release.version -ne $coreTarget.version -or
      $release.state -ne $coreTarget.state -or
      $release.candidate_created -ne $coreTarget.candidate_created -or
      [int]$release.desktop_abi -ne [int]$RuntimeCore.desktop_abi.version -or
      $release.android_package -ne $RuntimeCore.android_package -or
      $release.engine.sing_box -ne $RuntimeCore.sing_box_version -or
      "v$($release.engine.sing)" -ne $RuntimeCore.sing_dependency) {
    throw "POKROV Core checkout target disagrees with the client development contract."
  }
  $retainedEvidence = $retainedRelease.local_build_evidence
  if ($retainedRelease.version -ne $RuntimeCore.version -or
      $retainedRelease.release_tag -ne $RuntimeCore.release_tag -or
      $retainedRelease.source_commit -ne $RuntimeCore.source_commit) {
    throw "POKROV Core retained release identity disagrees with the client runtime contract."
  }
  if ($release.artifacts.android -ne $RuntimeCore.assets.android.entry -or
      [int64]$retainedEvidence.android.size -ne
        [int64]$RuntimeCore.assets.android.size -or
      $retainedEvidence.android.sha256 -ne $RuntimeCore.assets.android.sha256 -or
      $release.artifacts.windows -ne $RuntimeCore.assets.windows.entry -or
      [int64]$retainedEvidence.windows.size -ne
        [int64]$RuntimeCore.assets.windows.size -or
      $retainedEvidence.windows.sha256 -ne $RuntimeCore.assets.windows.sha256) {
    throw "POKROV Core release artifact evidence disagrees with the client runtime contract."
  }

  $runtimeAbi = $RuntimeCore.desktop_abi
  if ($coreTarget.required_for_product -ne "1.2.0" -or
      $coreTarget.version -ne "1.1.0" -or
      $coreTarget.release_tag -ne "v1.1.0" -or
      $coreTarget.state -ne "PRE_CANDIDATE_LOCAL" -or
      $coreTarget.candidate_created -ne $false -or
      $coreTarget.artifact_state -ne "pending") {
    throw "Core development target must be 1.1.0 PRE_CANDIDATE_LOCAL for product 1.2.0."
  }
  if ([int]$abiContract.schema_version -ne 1 -or
      [int]$abiContract.desktop_abi.version -ne [int]$runtimeAbi.version -or
      $abiContract.desktop_abi.marker_symbol -ne $runtimeAbi.required_symbol -or
      $abiContract.desktop_abi.capabilities_symbol -ne $runtimeAbi.optional_capabilities_symbol -or
      [int]$abiContract.descriptor.schema_version -ne [int]$runtimeAbi.capability_schema -or
      [int]$abiContract.descriptor.event_abi -ne [int]$runtimeAbi.event_abi) {
    throw "POKROV Core ABI descriptor disagrees with the client runtime contract."
  }
  Assert-SameStringSet -Label "POKROV Core legacy ABI compatibility" `
    -Actual @($abiContract.desktop_abi.legacy_compatible_without_capabilities_symbol) `
    -Expected @($runtimeAbi.legacy_without_capabilities_symbol)
  Assert-SameStringSet -Label "POKROV Core capabilities" `
    -Actual @($abiContract.descriptor.capabilities) `
    -Expected @($runtimeAbi.required_capabilities)
  Assert-SameStringSet -Label "POKROV Core lifecycle events" `
    -Actual @($abiContract.descriptor.lifecycle_events) `
    -Expected @($runtimeAbi.lifecycle_events)

  $replacementPending =
    $runtimeAbi.structured_events.retained_v1_0_3_artifact_mode -eq
      "legacy_without_structured_events" -and
    $runtimeAbi.structured_events.exact_replacement_artifact -eq "pending"
  $exactSourceIdentity =
    $revision -eq ([string]$RuntimeCore.source_commit).ToLowerInvariant() -and
    $release.go_toolchain -eq $RuntimeCore.go_toolchain
  $dirtyLines = @(& git.exe -C $resolvedCorePath status --porcelain 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "Could not inspect the POKROV Core checkout state."
  }
  $isDirty = $dirtyLines.Count -gt 0

  if (-not $exactSourceIdentity -or $isDirty) {
    if (-not $replacementPending) {
      throw "POKROV Core checkout is not the clean exact source authority for the pinned artifacts."
    }
    if ([string]$release.go_toolchain -notmatch '^go1\.[0-9]+\.[0-9]+$') {
      throw "Pending POKROV Core replacement does not pin a valid Go toolchain."
    }
    if ($isDirty) {
      return "DIRTY_DEVELOPMENT_REPLACEMENT_PENDING"
    }
    return "DEVELOPMENT_REPLACEMENT_PENDING"
  }

  return "PASS"
}

if ([string]::IsNullOrWhiteSpace($RuntimeArtifactsPath)) {
  $RuntimeArtifactsPath = Join-Path $root "config\runtime-artifacts.seed.json"
}
if ([string]::IsNullOrWhiteSpace($ReleaseHandoffPath)) {
  $ReleaseHandoffPath = Join-Path $root "config\release-handoff.seed.json"
}
if ([string]::IsNullOrWhiteSpace($WindowsReleasePath)) {
  $WindowsReleasePath = Join-Path $root "config\windows-release.seed.json"
}

$android = Read-PackageVersion (Join-Path $root "apps\android_shell\pubspec.yaml")
$windows = Read-PackageVersion (Join-Path $root "apps\windows_shell\pubspec.yaml")
$appShell = Read-PackageVersion (Join-Path $root "packages\app_shell\pubspec.yaml")
if ($android -ne $windows) {
  throw "Android and Windows release versions must match exactly."
}
$publicVersion = Get-PublicVersion $android
$appShellPublicVersion = Get-PublicVersion $appShell

$releaseHandoff = Read-JsonFile $ReleaseHandoffPath
$developmentTarget = $releaseHandoff.release_truth.development_target
if ($null -eq $developmentTarget) {
  throw "The release-handoff seed must name the active development target."
}
$targetPackageVersion = [string]$developmentTarget.package_version
$targetProductVersion = [string]$developmentTarget.product_version
$expectedTargetPackageVersion = "$targetProductVersion+$([int]$developmentTarget.platform_build)"
if ($targetPackageVersion -ne $expectedTargetPackageVersion -or
    $developmentTarget.state -ne "PRE_CANDIDATE_LOCAL" -or
    $developmentTarget.candidate_created -ne $false) {
  throw "The active development target must remain an uncreated pre-candidate."
}
if ($android -ne $targetPackageVersion -or
    $publicVersion -ne $targetProductVersion -or
    $appShellPublicVersion -ne $targetProductVersion) {
  throw "Android, Windows and app-shell versions must match the development target."
}
if ($releaseHandoff.latest_repo_backed_release.reuse_for_new_promotion -ne $false) {
  throw "The historical public handoff cannot be reused for the development target."
}
if (-not [string]::IsNullOrWhiteSpace($CandidateVersion) -and
    $CandidateVersion -ne $publicVersion) {
  throw "The generated candidate version must match the Android and Windows public version."
}

$runtimeArtifacts = Read-JsonFile $RuntimeArtifactsPath
$windowsRelease = Read-JsonFile $WindowsReleasePath
$core = $runtimeArtifacts.core
if ([string]::IsNullOrWhiteSpace([string]$core.version) -or
    $core.release_tag -ne "v$($core.version)") {
  throw "Runtime Core version and release tag must agree."
}
if ([string]$core.source_commit -notmatch '^[A-Fa-f0-9]{40}$') {
  throw "Runtime Core source commit must be an exact 40-character Git revision."
}
if ($core.android_package -ne "space.pokrov.core") {
  throw "Runtime Core Android package must be space.pokrov.core."
}
if ([int]$core.desktop_abi.version -ne [int]$windowsRelease.runtime.desktop_abi) {
  throw "Runtime Core desktop ABI must match the Windows release contract."
}
if ($windowsRelease.runtime.release_tag -ne $core.release_tag) {
  throw "Runtime Core release tag must match the Windows release contract."
}

Assert-ArtifactIdentity -Platform "Android" -Asset $core.assets.android
Assert-ArtifactIdentity -Platform "Windows" -Asset $core.assets.windows

$coreAuthorityState = "NOT_REQUESTED"
if (-not [string]::IsNullOrWhiteSpace($CoreRoot)) {
  $coreAuthorityState = Assert-CoreAuthority -CorePath $CoreRoot -RuntimeCore $core
}

$paritySummary = "app=$android public=$($releaseHandoff.latest_repo_backed_release.version) " +
  "target_state=$($developmentTarget.state) core_public=$($core.version) " +
  "core_target=$($core.development_target.version) " +
  "desktop_abi=$($core.desktop_abi.version) core_checkout=$coreAuthorityState"
Write-Host "Client/Core version parity OK: $paritySummary" -ForegroundColor Green
