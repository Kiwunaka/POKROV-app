[CmdletBinding()]
param(
  [string]$PlatformRoot,
  [string]$CoreRoot
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

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
