[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$gitIgnorePath = Join-Path $root ".gitignore"
$artifactBoundaryPath = Join-Path $root "artifacts\README.md"
$releaseHandoffPath = Join-Path $root "config\release-handoff.seed.json"

function Normalize-GitPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  return $Path.Replace([char]92, [char]47)
}

function Read-GitPaths {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  $result = @(& git -C $root -c core.quotepath=false @Arguments 2>$null)
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed."
  }
  return @($result | ForEach-Object { Normalize-GitPath -Path ([string]$_) })
}

$gitIgnore = [IO.File]::ReadAllText($gitIgnorePath)
foreach ($requiredRule in @(
  "build/",
  "dist/",
  ".tmp/",
  "packages/app_shell/test/failures/",
  "artifacts/candidate-staging/"
)) {
  if (-not ($gitIgnore -split "`r?`n").Contains($requiredRule)) {
    throw ".gitignore lacks required generated-output rule: $requiredRule"
  }
}

$tracked = @(Read-GitPaths -Arguments @("ls-files"))
$deleted = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in @(Read-GitPaths -Arguments @("diff", "--name-only", "--diff-filter=D", "--"))) {
  [void]$deleted.Add($path)
}
foreach ($path in @(Read-GitPaths -Arguments @("diff", "--cached", "--name-only", "--diff-filter=D", "--"))) {
  [void]$deleted.Add($path)
}
$effectiveTracked = @($tracked | Where-Object { -not $deleted.Contains($_) })

$forbiddenGeneratedSegment =
  '(^|/)(\.tmp|tmp|temp|build|dist|coverage|outputs|\.dart_tool|\.gradle)(/|$)'
$trackedGenerated = @(
  $effectiveTracked | Where-Object {
    -not $_.StartsWith("artifacts/releases/", [StringComparison]::Ordinal) -and
    ($_ -match $forbiddenGeneratedSegment -or
      $_.StartsWith("packages/app_shell/test/failures/", [StringComparison]::Ordinal))
  }
)
if ($trackedGenerated.Count -gt 0) {
  throw "Generated/temp paths are tracked: $($trackedGenerated -join ', ')"
}

$runtimeBinaryAllowlist = @(
  "apps/android_shell/android/app/libs/pokrov-core.aar",
  "apps/windows_shell/windows/runner/resources/runtime/libcronet.dll",
  "apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll"
)
$trackedCandidateBinaries = @(
  $effectiveTracked | Where-Object {
    -not $_.StartsWith("artifacts/releases/", [StringComparison]::Ordinal) -and
    $_ -match '\.(apk|aab|exe|zip|msix|dll|aar)$' -and
    $runtimeBinaryAllowlist -notcontains $_
  }
)
if ($trackedCandidateBinaries.Count -gt 0) {
  throw "Candidate/build binaries are tracked outside retained history or the runtime allowlist: $($trackedCandidateBinaries -join ', ')"
}

$trackedStaging = @(
  $effectiveTracked | Where-Object {
    $_.StartsWith("artifacts/candidate-staging/", [StringComparison]::Ordinal)
  }
)
if ($trackedStaging.Count -gt 0) {
  throw "Local candidate staging is tracked: $($trackedStaging -join ', ')"
}

$releaseHandoff = [IO.File]::ReadAllText($releaseHandoffPath) | ConvertFrom-Json
$targetVersion = [string]$releaseHandoff.release_truth.development_target.product_version
if ([string]::IsNullOrWhiteSpace($targetVersion)) {
  throw "Development target version is missing from the release handoff."
}
$targetPattern = [regex]::Escape($targetVersion)
$targetInRetainedHistory = @(
  $effectiveTracked | Where-Object {
    $_.StartsWith("artifacts/releases/", [StringComparison]::Ordinal) -and
    $_ -match $targetPattern
  }
)
if ($targetInRetainedHistory.Count -gt 0) {
  throw "Development target $targetVersion was written into retained release history: $($targetInRetainedHistory -join ', ')"
}

$artifactBoundary = [IO.File]::ReadAllText($artifactBoundaryPath)
foreach ($marker in @(
  "HISTORICAL_EVIDENCE_ONLY",
  "LOCAL_CANDIDATE_STAGING",
  "PUBLIC_RELEASE_INDEX",
  "BLOCKED_BY_ACCESS"
)) {
  if (-not $artifactBoundary.Contains($marker)) {
    throw "Artifact boundary lacks required marker: $marker"
  }
}

$rootReadme = [IO.File]::ReadAllText((Join-Path $root "README.md"))
foreach ($fact in @("1.1.6", "1.2.0+36", "PRE_CANDIDATE_LOCAL", "artifacts/candidate-staging")) {
  if (-not $rootReadme.Contains($fact)) {
    throw "Root README lacks current repository/release fact: $fact"
  }
}

$pendingTempDeletes = @(
  $tracked | Where-Object {
    $deleted.Contains($_) -and $_ -match $forbiddenGeneratedSegment
  }
)
Write-Host (
  "Repository hygiene OK: effective_tracked={0} retained_history={1} pending_temp_deletes={2} runtime_binaries={3}" -f
    $effectiveTracked.Count,
    @($effectiveTracked | Where-Object { $_.StartsWith("artifacts/releases/") }).Count,
    $pendingTempDeletes.Count,
    $runtimeBinaryAllowlist.Count
) -ForegroundColor Green
exit 0
