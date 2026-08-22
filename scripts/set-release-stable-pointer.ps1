[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$CatalogPath,
  [switch]$ValidateOnly,
  [string]$ExpectedCurrentReleaseId,
  [string]$TargetReleaseId,
  [string]$BackupPath,
  [string]$ReceiptPath,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-ExactProperties {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string[]]$Required,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ($null -eq $Value) {
    throw "$Path must be an object."
  }
  $names = @($Value.PSObject.Properties.Name)
  foreach ($name in $Required) {
    if ($names -notcontains $name) {
      throw "$Path is missing required property '$name'."
    }
  }
  foreach ($name in $names) {
    if ($Required -notcontains $name) {
      throw "$Path contains unsupported property '$name'."
    }
  }
}

function Get-NormalizedSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)

  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-HandoffIdentity {
  param([Parameter(Mandatory = $true)][string]$Path)

  $handoff = [IO.File]::ReadAllText($Path) | ConvertFrom-Json
  if ([int]$handoff.schema_version -eq 1) {
    if ([string]::IsNullOrWhiteSpace([string]$handoff.release_id) -or
        [string]::IsNullOrWhiteSpace([string]$handoff.release_version)) {
      throw "Legacy handoff lacks release_id or release_version: $Path"
    }
    return [pscustomobject]@{
      SchemaVersion = 1
      ReleaseId = [string]$handoff.release_id
      ReleaseVersion = [string]$handoff.release_version
    }
  }
  if ([int]$handoff.schema_version -eq 2) {
    if ([string]::IsNullOrWhiteSpace([string]$handoff.release.candidate_label) -or
        [string]::IsNullOrWhiteSpace([string]$handoff.release.version)) {
      throw "Strict-v2 handoff lacks candidate_label or version: $Path"
    }
    return [pscustomobject]@{
      SchemaVersion = 2
      ReleaseId = [string]$handoff.release.candidate_label
      ReleaseVersion = [string]$handoff.release.version
    }
  }
  throw "Unsupported handoff schema_version in $Path"
}

function Resolve-ArtifactPath {
  param(
    [Parameter(Mandatory = $true)][string]$ArtifactRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ([IO.Path]::IsPathRooted($RelativePath)) {
    throw "$Label must be relative to artifact_root."
  }
  $rootFullPath = [IO.Path]::GetFullPath($ArtifactRoot)
  $rootPrefix = $rootFullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
    [IO.Path]::DirectorySeparatorChar
  $resolved = [IO.Path]::GetFullPath((Join-Path $rootFullPath $RelativePath))
  if (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label escapes artifact_root."
  }
  return $resolved
}

function Test-IsUnderRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $rootFullPath = [IO.Path]::GetFullPath($Root)
  $rootPrefix = $rootFullPath.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
    [IO.Path]::DirectorySeparatorChar
  $pathFullPath = [IO.Path]::GetFullPath($Path)
  return $pathFullPath.Equals($rootFullPath, [StringComparison]::OrdinalIgnoreCase) -or
    $pathFullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
}

$catalogFullPath = (Resolve-Path -LiteralPath $CatalogPath).Path
$catalogDirectory = [IO.Path]::GetDirectoryName($catalogFullPath)
$catalog = [IO.File]::ReadAllText($catalogFullPath) | ConvertFrom-Json
Assert-ExactProperties -Value $catalog `
  -Required @(
    "schema_version", "channel", "artifact_root", "stable_pointer",
    "rollback_targets", "mutation_policy"
  ) -Path "rollback catalog"
if ([int]$catalog.schema_version -ne 1 -or [string]$catalog.channel -ne "stable") {
  throw "Rollback catalog must be schema v1 for the stable channel."
}
Assert-ExactProperties -Value $catalog.stable_pointer -Required @("path") `
  -Path "rollback catalog.stable_pointer"
Assert-ExactProperties -Value $catalog.mutation_policy `
  -Required @(
    "atomic_replace_required", "optimistic_lock_required", "backup_required",
    "same_byte_target_required", "exact_candidate_gate_required"
  ) -Path "rollback catalog.mutation_policy"
foreach ($property in @(
  "atomic_replace_required", "optimistic_lock_required", "backup_required",
  "same_byte_target_required", "exact_candidate_gate_required"
)) {
  if ($catalog.mutation_policy.$property -ne $true) {
    throw "Rollback catalog mutation policy must require $property."
  }
}

if ([IO.Path]::IsPathRooted([string]$catalog.artifact_root)) {
  throw "rollback catalog.artifact_root must be relative to the catalog."
}
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $catalogDirectory ([string]$catalog.artifact_root)))
if (-not (Test-Path -LiteralPath $artifactRoot -PathType Container)) {
  throw "Rollback artifact_root is missing: $artifactRoot"
}
$pointerPath = Resolve-ArtifactPath -ArtifactRoot $artifactRoot `
  -RelativePath ([string]$catalog.stable_pointer.path) -Label "stable_pointer.path"
if (-not (Test-Path -LiteralPath $pointerPath -PathType Leaf)) {
  throw "Stable release pointer is missing: $pointerPath"
}

$targets = @{}
foreach ($target in @($catalog.rollback_targets)) {
  Assert-ExactProperties -Value $target `
    -Required @(
      "release_id", "release_version", "handoff_schema_version", "handoff_path",
      "handoff_sha256", "eligibility", "platforms"
    ) -Path "rollback catalog.rollback_targets"
  $releaseId = [string]$target.release_id
  if ([string]::IsNullOrWhiteSpace($releaseId) -or $targets.ContainsKey($releaseId)) {
    throw "Rollback target release_id must be non-empty and unique: $releaseId"
  }
  if ([string]$target.eligibility -ne "ROLLBACK_ELIGIBLE") {
    throw "Rollback target $releaseId is not ROLLBACK_ELIGIBLE."
  }
  $platforms = @($target.platforms)
  if ($platforms.Count -ne 2 -or $platforms[0] -ne "android" -or $platforms[1] -ne "windows") {
    throw "Rollback target $releaseId must cover ordered Android and Windows surfaces."
  }
  $handoffPath = Resolve-ArtifactPath -ArtifactRoot $artifactRoot `
    -RelativePath ([string]$target.handoff_path) -Label "rollback target $releaseId handoff_path"
  if (-not (Test-Path -LiteralPath $handoffPath -PathType Leaf)) {
    throw "Rollback target handoff is missing: $handoffPath"
  }
  $actualHash = Get-NormalizedSha256 -Path $handoffPath
  if ($actualHash -ne ([string]$target.handoff_sha256).ToLowerInvariant()) {
    throw "Rollback target $releaseId SHA-256 does not match its catalog entry."
  }
  $identity = Get-HandoffIdentity -Path $handoffPath
  if ($identity.ReleaseId -ne $releaseId -or
      $identity.ReleaseVersion -ne [string]$target.release_version -or
      $identity.SchemaVersion -ne [int]$target.handoff_schema_version) {
    throw "Rollback target $releaseId metadata identity does not match its catalog entry."
  }
  $targets[$releaseId] = [pscustomobject]@{
    Catalog = $target
    Path = $handoffPath
    Hash = $actualHash
    Identity = $identity
  }
}
if ($targets.Count -lt 1) {
  throw "Rollback catalog must retain at least one target."
}

$pointerIdentity = Get-HandoffIdentity -Path $pointerPath
$pointerHash = Get-NormalizedSha256 -Path $pointerPath
if (-not $targets.ContainsKey($pointerIdentity.ReleaseId)) {
  throw "Stable pointer release $($pointerIdentity.ReleaseId) is absent from the rollback catalog."
}
$currentTarget = $targets[$pointerIdentity.ReleaseId]
if ($pointerHash -ne $currentTarget.Hash -or
    $pointerIdentity.ReleaseVersion -ne $currentTarget.Identity.ReleaseVersion) {
  throw "Stable pointer bytes do not match its versioned rollback target."
}

if ($ValidateOnly) {
  [pscustomobject]@{
    status = "PASS"
    stable_release_id = $pointerIdentity.ReleaseId
    stable_release_version = $pointerIdentity.ReleaseVersion
    stable_handoff_sha256 = $pointerHash
    rollback_target_count = $targets.Count
    applied = $false
  } | ConvertTo-Json -Compress | Write-Output
  exit 0
}

if ([string]::IsNullOrWhiteSpace($ExpectedCurrentReleaseId) -or
    [string]::IsNullOrWhiteSpace($TargetReleaseId)) {
  throw "ExpectedCurrentReleaseId and TargetReleaseId are required for a pointer switch."
}
if ($pointerIdentity.ReleaseId -ne $ExpectedCurrentReleaseId) {
  throw "Optimistic lock failed: stable pointer is $($pointerIdentity.ReleaseId), expected $ExpectedCurrentReleaseId."
}
if ($TargetReleaseId -eq $ExpectedCurrentReleaseId) {
  throw "TargetReleaseId must differ from ExpectedCurrentReleaseId."
}
if (-not $targets.ContainsKey($TargetReleaseId)) {
  throw "Target release is absent from the rollback catalog: $TargetReleaseId"
}
$targetRecord = $targets[$TargetReleaseId]

$plan = [ordered]@{
  status = "PASS"
  from_release_id = $pointerIdentity.ReleaseId
  from_handoff_sha256 = $pointerHash
  to_release_id = $targetRecord.Identity.ReleaseId
  to_handoff_sha256 = $targetRecord.Hash
  pointer_path = $pointerPath
  applied = [bool]$Apply
}
if (-not $Apply) {
  [pscustomobject]$plan | ConvertTo-Json -Compress | Write-Output
  exit 0
}

if ([string]::IsNullOrWhiteSpace($BackupPath) -or [string]::IsNullOrWhiteSpace($ReceiptPath)) {
  throw "BackupPath and ReceiptPath are required with -Apply."
}
$backupFullPath = [IO.Path]::GetFullPath($BackupPath)
$receiptFullPath = [IO.Path]::GetFullPath($ReceiptPath)
foreach ($output in @($backupFullPath, $receiptFullPath)) {
  if (Test-IsUnderRoot -Root $artifactRoot -Path $output) {
    throw "Backup and receipt must stay outside artifacts/releases."
  }
  if (Test-Path -LiteralPath $output) {
    throw "Refusing to overwrite rollback evidence: $output"
  }
  $outputDirectory = [IO.Path]::GetDirectoryName($output)
  if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    throw "Rollback evidence directory is missing: $outputDirectory"
  }
}
if ([IO.Path]::GetPathRoot($backupFullPath) -ne [IO.Path]::GetPathRoot($pointerPath)) {
  throw "BackupPath must use the same filesystem root as the stable pointer."
}

$pointerDirectory = [IO.Path]::GetDirectoryName($pointerPath)
$pointerTempPath = Join-Path $pointerDirectory (".release-pointer.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
try {
  [IO.File]::Copy($targetRecord.Path, $pointerTempPath, $false)
  if ((Get-NormalizedSha256 -Path $pointerTempPath) -ne $targetRecord.Hash) {
    throw "Prepared stable pointer is not byte-identical to the catalog target."
  }
  [IO.File]::Replace($pointerTempPath, $pointerPath, $backupFullPath, $true)
} finally {
  if (Test-Path -LiteralPath $pointerTempPath -PathType Leaf) {
    Remove-Item -LiteralPath $pointerTempPath -Force
  }
}

if ((Get-NormalizedSha256 -Path $backupFullPath) -ne $pointerHash) {
  throw "Rollback backup is not byte-identical to the previous stable pointer."
}

$observedIdentity = Get-HandoffIdentity -Path $pointerPath
$observedHash = Get-NormalizedSha256 -Path $pointerPath
if ($observedIdentity.ReleaseId -ne $targetRecord.Identity.ReleaseId -or
    $observedHash -ne $targetRecord.Hash) {
  throw "Stable pointer readback does not match the requested target."
}

$plan["observed_release_id"] = $observedIdentity.ReleaseId
$plan["observed_handoff_sha256"] = $observedHash
$plan["backup_sha256"] = Get-NormalizedSha256 -Path $backupFullPath
$plan["applied_at_utc"] = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
$receiptJson = ConvertTo-Json -InputObject ([pscustomobject]$plan) -Depth 5
$receiptJson = ($receiptJson -replace "`r`n", "`n").TrimEnd() + "`n"
$receiptTempPath = Join-Path ([IO.Path]::GetDirectoryName($receiptFullPath)) `
  (".release-pointer-receipt.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
try {
  [IO.File]::WriteAllText($receiptTempPath, $receiptJson, $utf8NoBom)
  [IO.File]::Move($receiptTempPath, $receiptFullPath)
} finally {
  if (Test-Path -LiteralPath $receiptTempPath -PathType Leaf) {
    Remove-Item -LiteralPath $receiptTempPath -Force
  }
}

[pscustomobject]$plan | ConvertTo-Json -Compress | Write-Output
