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

function Read-Json([string]$Path) {
  return [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Read-Version([string]$Path) {
  $match = [regex]::Match([IO.File]::ReadAllText($Path), '(?m)^version:\s*([^\s]+)\s*$')
  if (-not $match.Success) { throw "Version is missing: $Path" }
  return $match.Groups[1].Value
}

function Assert-Asset([string]$Path, [long]$Size, [string]$Sha256) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Core artifact is missing: $Path"
  }
  $file = Get-Item -LiteralPath $Path
  $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
  if ($file.Length -ne $Size -or $hash -ne $Sha256) {
    throw "Core artifact does not match the release binding: $Path"
  }
}

if (-not $RuntimeArtifactsPath) {
  $RuntimeArtifactsPath = Join-Path $root "config/runtime-artifacts.seed.json"
}
if (-not $ReleaseHandoffPath) {
  $ReleaseHandoffPath = Join-Path $root "config/release-handoff.seed.json"
}
if (-not $WindowsReleasePath) {
  $WindowsReleasePath = Join-Path $root "config/windows-release.seed.json"
}

$handoff = Read-Json $ReleaseHandoffPath
$runtime = (Read-Json $RuntimeArtifactsPath).core
$windowsRelease = Read-Json $WindowsReleasePath
$target = $handoff.release_truth.development_target
$androidVersion = Read-Version (Join-Path $root "apps/android_shell/pubspec.yaml")
$windowsVersion = Read-Version (Join-Path $root "apps/windows_shell/pubspec.yaml")
$shellVersion = Read-Version (Join-Path $root "packages/app_shell/pubspec.yaml")

if ($target.package_version -ne "$($target.product_version)+$($target.platform_build)" -or
    $androidVersion -ne $target.package_version -or
    $windowsVersion -ne $target.package_version -or
    $shellVersion -ne $target.product_version) {
  throw "Android, Windows and app-shell versions disagree with the release target."
}
if ($CandidateVersion -and $CandidateVersion -ne $target.product_version) {
  throw "Candidate version disagrees with the release target."
}
if ($runtime.release_tag -ne "v$($runtime.version)" -or
    $runtime.source_commit -notmatch '^[0-9a-f]{40}$' -or
    $runtime.android_package -ne "space.pokrov.core" -or
    [int]$runtime.desktop_abi.version -ne [int]$windowsRelease.runtime.desktop_abi -or
    $runtime.release_tag -ne $windowsRelease.runtime.release_tag) {
  throw "Core release identity disagrees with the client runtime contract."
}

foreach ($platform in @("android", "windows")) {
  $asset = $runtime.assets.$platform
  $path = Join-Path $root $asset.sync_destination
  Assert-Asset (Join-Path $path $asset.entry) ([long]$asset.size) ([string]$asset.sha256)
  $dependencies = @()
  if ($asset.PSObject.Properties["runtime_dependencies"]) {
    $dependencies = @($asset.runtime_dependencies)
  }
  foreach ($dependency in $dependencies) {
    $size = $asset.runtime_dependency_size.PSObject.Properties[$dependency].Value
    $sha256 = $asset.runtime_dependency_sha256.PSObject.Properties[$dependency].Value
    Assert-Asset (Join-Path $path $dependency) ([long]$size) ([string]$sha256)
  }
}

if ($CoreRoot) {
  $corePath = (Resolve-Path -LiteralPath $CoreRoot).Path
  $revision = (& git -C $corePath rev-parse HEAD).Trim()
  $version = [IO.File]::ReadAllText((Join-Path $corePath "VERSION")).Trim()
  $release = Read-Json (Join-Path $corePath "config/release.json")
  if ($revision -ne $runtime.source_commit -or
      $version -ne $runtime.version -or
      [int]$release.desktop_abi -ne [int]$runtime.desktop_abi.version) {
    throw "Local Core source disagrees with the bound runtime."
  }
}

Write-Host "Client $androidVersion and Core $($runtime.version) artifact binding OK." -ForegroundColor Green
