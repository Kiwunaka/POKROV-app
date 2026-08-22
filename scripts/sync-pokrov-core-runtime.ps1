param(
  [string]$CoreRoot,
  [ValidateSet("android", "windows")]
  [string[]]$Platforms = @("android", "windows")
)

$ErrorActionPreference = "Stop"

$clientRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $clientRoot "config\runtime-artifacts.seed.json"
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$runtime = $config.core

if (-not $CoreRoot) {
  $cursor = Get-Item -LiteralPath $clientRoot
  while ($cursor) {
    $candidate = Join-Path $cursor.FullName "POKROV-core"
    if (Test-Path -LiteralPath (Join-Path $candidate ".git")) {
      $CoreRoot = $candidate
      break
    }
    $cursor = $cursor.Parent
  }
}

if (-not $CoreRoot) {
  throw "POKROV Core checkout was not found. Pass -CoreRoot explicitly."
}

$CoreRoot = (Resolve-Path -LiteralPath $CoreRoot).Path
$coreCommit = (& git -C $CoreRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $coreCommit -ne $runtime.source_commit) {
  throw "POKROV Core must be checked out at $($runtime.source_commit); found '$coreCommit'."
}
$coreStatus = @(& git -C $CoreRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $coreStatus.Count -ne 0) {
  throw "POKROV Core must be clean before exact runtime artifacts are synchronized."
}

$version = [System.IO.File]::ReadAllText((Join-Path $CoreRoot "VERSION")).Trim()
if ("v$version" -ne $runtime.release_tag) {
  throw "POKROV Core VERSION '$version' does not match $($runtime.release_tag)."
}

function Assert-FileIdentity {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][int64]$ExpectedSize,
    [Parameter(Mandatory)][string]$ExpectedSha256
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required POKROV Core artifact is missing: $Path"
  }

  $file = Get-Item -LiteralPath $Path
  if ($file.Length -ne $ExpectedSize) {
    throw "Size mismatch for $Path. Expected $ExpectedSize, got $($file.Length)."
  }

  $actualSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
  if ($actualSha256 -ne $ExpectedSha256) {
    throw "SHA-256 mismatch for $Path."
  }
}

foreach ($platform in $Platforms) {
  $asset = $runtime.assets.$platform
  if ($asset.sync_policy -ne "exact_pre_candidate_build") {
    throw "POKROV Core $platform sync policy is not exact_pre_candidate_build."
  }
  $sourceRoot = Join-Path $CoreRoot "dist\$platform"
  $sourceEntry = Join-Path $sourceRoot $asset.entry
  Assert-FileIdentity `
    -Path $sourceEntry `
    -ExpectedSize ([int64]$asset.size) `
    -ExpectedSha256 ([string]$asset.sha256)

  $dependencies = @($asset.runtime_dependencies | Where-Object {
    -not [string]::IsNullOrWhiteSpace([string]$_)
  })
  foreach ($dependency in $dependencies) {
    $dependencySize = $asset.runtime_dependency_size.PSObject.Properties[$dependency].Value
    $dependencySha256 = $asset.runtime_dependency_sha256.PSObject.Properties[$dependency].Value
    Assert-FileIdentity `
      -Path (Join-Path $sourceRoot $dependency) `
      -ExpectedSize ([int64]$dependencySize) `
      -ExpectedSha256 ([string]$dependencySha256)
  }

  $destination = Join-Path $clientRoot $asset.sync_destination
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  Copy-Item -Force -LiteralPath $sourceEntry -Destination $destination
  foreach ($dependency in $dependencies) {
    Copy-Item -Force -LiteralPath (Join-Path $sourceRoot $dependency) -Destination $destination
  }

  Assert-FileIdentity `
    -Path (Join-Path $destination $asset.entry) `
    -ExpectedSize ([int64]$asset.size) `
    -ExpectedSha256 ([string]$asset.sha256)
  foreach ($dependency in $dependencies) {
    $dependencySize = $asset.runtime_dependency_size.PSObject.Properties[$dependency].Value
    $dependencySha256 = $asset.runtime_dependency_sha256.PSObject.Properties[$dependency].Value
    Assert-FileIdentity `
      -Path (Join-Path $destination $dependency) `
      -ExpectedSize ([int64]$dependencySize) `
      -ExpectedSha256 ([string]$dependencySha256)
  }

  Write-Host "Synced exact POKROV Core $($runtime.release_tag) PRE_CANDIDATE_LOCAL bytes for $platform." -ForegroundColor Green
}
