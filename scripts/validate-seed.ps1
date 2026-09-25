[CmdletBinding()]
param(
  [string]$PlatformRoot,
  [string]$CoreRoot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

foreach ($relativePath in @(
  "config/product-contract.seed.json",
  "config/platform-matrix.seed.json",
  "config/runtime-profile.seed.json",
  "config/runtime-artifacts.seed.json",
  "config/windows-release.seed.json",
  "config/release-handoff.seed.json"
)) {
  $path = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Build contract is missing: $relativePath"
  }
  [IO.File]::ReadAllText($path) | ConvertFrom-Json | Out-Null
}

$parityArguments = @{}
if ($CoreRoot) { $parityArguments.CoreRoot = $CoreRoot }
& (Join-Path $root "scripts/check-client-version-parity.ps1") @parityArguments
if (-not $?) { throw "Client/Core artifact binding failed." }

if ($PlatformRoot) {
  $observabilityArguments = @{ PlatformRoot = $PlatformRoot }
  if ($CoreRoot) { $observabilityArguments.CoreRoot = $CoreRoot }
  & (Join-Path $root "scripts/validate-observability-contracts.ps1") @observabilityArguments
  if (-not $?) { throw "Client/platform contract parity failed." }
}

Write-Host "Client build seed OK." -ForegroundColor Green
