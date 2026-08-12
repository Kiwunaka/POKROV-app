[CmdletBinding()]
param(
  [string]$SigningDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "POKROV\android-signing"),
  [string]$ApiBaseUrl = "https://api.pokrov.space"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-AndroidBuildTool {
  param([Parameter(Mandatory = $true)][string]$FileName)

  $sdkRoot = if ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
  } elseif ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
  } else {
    Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "Android\Sdk"
  }
  $buildToolsRoot = Join-Path $sdkRoot "build-tools"
  if (-not (Test-Path -LiteralPath $buildToolsRoot -PathType Container)) {
    throw "Android SDK build-tools directory was not found."
  }
  $candidates = Get-ChildItem -LiteralPath $buildToolsRoot -Directory | Sort-Object {
    try { [version]$_.Name } catch { [version]"0.0" }
  } -Descending
  foreach ($candidate in $candidates) {
    $path = Join-Path $candidate.FullName $FileName
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      return $path
    }
  }
  throw "$FileName was not found in Android SDK build-tools."
}

function Set-ProcessEnvironmentValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()][string]$Value
  )
  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$androidRoot = Join-Path $repoRoot "apps\android_shell"
$pubspecPath = Join-Path $androidRoot "pubspec.yaml"
$pubspecText = Get-Content -Raw -LiteralPath $pubspecPath
$versionMatch = [regex]::Match($pubspecText, "(?m)^version:\s*([^\s]+)\s*$")
if (-not $versionMatch.Success) {
  throw "Could not read the Android package version from pubspec.yaml."
}
$declaredVersionName = $versionMatch.Groups[1].Value.Split("+", 2)[0]
$resolvedSigningDirectory = [System.IO.Path]::GetFullPath($SigningDirectory)
$keystorePath = Join-Path $resolvedSigningDirectory "pokrov-production.p12"
$secretPath = Join-Path $resolvedSigningDirectory "pokrov-production.password.dpapi"
$metadataPath = Join-Path $resolvedSigningDirectory "pokrov-production.metadata.json"

foreach ($path in @($keystorePath, $secretPath, $metadataPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Android production signing is not fully configured. Missing a required local signing file."
  }
}

$metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
if ($metadata.package_name -ne "space.pokrov.pokrov_android_shell" -or -not $metadata.key_alias) {
  throw "Android signing metadata does not match the canonical POKROV package."
}

$securePassword = Get-Content -Raw -LiteralPath $secretPath | ConvertTo-SecureString
$plainPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
$environmentNames = @(
  "ANDROID_SIGNING_KEY",
  "ANDROID_SIGNING_STORE_PASSWORD",
  "ANDROID_SIGNING_KEY_PASSWORD",
  "ANDROID_SIGNING_KEY_ALIAS",
  "POKROV_ALLOW_INTERNAL_BETA_DEBUG_SIGNING"
)
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
  $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

try {
  Set-ProcessEnvironmentValue -Name "ANDROID_SIGNING_KEY" -Value $keystorePath
  Set-ProcessEnvironmentValue -Name "ANDROID_SIGNING_STORE_PASSWORD" -Value $plainPassword
  Set-ProcessEnvironmentValue -Name "ANDROID_SIGNING_KEY_PASSWORD" -Value $plainPassword
  Set-ProcessEnvironmentValue -Name "ANDROID_SIGNING_KEY_ALIAS" -Value ([string]$metadata.key_alias)
  Set-ProcessEnvironmentValue -Name "POKROV_ALLOW_INTERNAL_BETA_DEBUG_SIGNING" -Value $null

  Push-Location $androidRoot
  try {
    $buildArguments = @(
      "build",
      "apk",
      "--release",
      "--dart-define=POKROV_API_BASE_URL=$ApiBaseUrl",
      "--dart-define=POKROV_APP_VERSION=$declaredVersionName"
    )
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production APK build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
} finally {
  foreach ($name in $environmentNames) {
    Set-ProcessEnvironmentValue -Name $name -Value $previousEnvironment[$name]
  }
  $plainPassword = $null
  $securePassword = $null
}

$apkPath = Join-Path $androidRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
  throw "The expected production APK was not produced."
}

$apksigner = Resolve-AndroidBuildTool -FileName "apksigner.bat"
$verificationOutput = @(& $apksigner verify --verbose --print-certs $apkPath 2>&1 | ForEach-Object { [string]$_ })
if ($LASTEXITCODE -ne 0) {
  throw "apksigner rejected the production APK."
}
$verificationText = $verificationOutput -join "`n"
if ($verificationText -match "Android Debug") {
  throw "The production APK is still signed with the Android Debug certificate."
}
$fingerprintMatch = [regex]::Match(
  $verificationText,
  "certificate SHA-256 digest:\s*([0-9a-fA-F]{64})"
)
if (-not $fingerprintMatch.Success) {
  throw "Could not read the production signer fingerprint from apksigner output."
}
$artifactFingerprint = $fingerprintMatch.Groups[1].Value.ToUpperInvariant()
$expectedFingerprint = ([string]$metadata.certificate_sha256).Replace(":", "").ToUpperInvariant()
if ($artifactFingerprint -ne $expectedFingerprint) {
  throw "The production APK signer does not match the configured POKROV production certificate."
}

$aapt = Resolve-AndroidBuildTool -FileName "aapt.exe"
$badgingOutput = @(& $aapt dump badging $apkPath 2>&1 | ForEach-Object { [string]$_ })
if ($LASTEXITCODE -ne 0) {
  throw "aapt could not inspect the production APK manifest."
}
$badgingText = $badgingOutput -join "`n"
if ($badgingText -match "(?m)^application-debuggable") {
  throw "The production APK manifest is debuggable."
}
$packageMatch = [regex]::Match(
  $badgingText,
  "(?m)^package:\s+name='([^']+)'\s+versionCode='([^']+)'\s+versionName='([^']+)'"
)
if (-not $packageMatch.Success) {
  throw "Could not read the production APK package and version from aapt."
}
$artifactPackage = $packageMatch.Groups[1].Value
$versionCode = $packageMatch.Groups[2].Value
$versionName = $packageMatch.Groups[3].Value
if ($artifactPackage -ne [string]$metadata.package_name) {
  throw "The production APK package does not match the configured signing identity."
}
if ($versionName -ne $declaredVersionName) {
  throw "The production APK version does not match apps/android_shell/pubspec.yaml."
}

$apk = Get-Item -LiteralPath $apkPath
$artifactHash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
$evidence = [ordered]@{
  schema_version = 1
  artifact = $apk.Name
  package_name = $artifactPackage
  version_name = $versionName
  version_code = $versionCode
  distribution = "direct_apk"
  build_mode = "release"
  debuggable = $false
  signing_state = "production_self_managed"
  certificate_sha256 = $artifactFingerprint
  apk_sha256 = $artifactHash
  size_bytes = [int64]$apk.Length
  api_base_url = $ApiBaseUrl
  verified_at_utc = [DateTime]::UtcNow.ToString("o")
}
$evidencePath = "$apkPath.signing.json"
[System.IO.File]::WriteAllText(
  $evidencePath,
  ($evidence | ConvertTo-Json -Depth 4),
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Android production APK built and verified." -ForegroundColor Green
Write-Host "APK: $apkPath"
Write-Host "Size: $($apk.Length) bytes"
Write-Host "APK SHA-256: $artifactHash"
Write-Host "Certificate SHA-256: $artifactFingerprint"
Write-Host "Evidence: $evidencePath"
