[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot

function Read-PackageVersion {
  param([Parameter(Mandatory = $true)][string]$Path)

  $text = Get-Content -Raw -LiteralPath $Path
  $match = [regex]::Match($text, '(?m)^version:\s*([^\s]+)\s*$')
  if (-not $match.Success) {
    throw "Could not read package version from $Path"
  }
  return $match.Groups[1].Value.Trim()
}

$android = Read-PackageVersion (Join-Path $root "apps\android_shell\pubspec.yaml")
$windows = Read-PackageVersion (Join-Path $root "apps\windows_shell\pubspec.yaml")
if ($android -ne $windows) {
  throw "Android and Windows release versions must match exactly (Android=$android, Windows=$windows)."
}

Write-Host "Client version parity OK: $android" -ForegroundColor Green
