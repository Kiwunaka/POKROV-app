[CmdletBinding()]
param(
  [string]$SigningDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "POKROV\android-signing"),
  [string]$ApiBaseUrl = "https://app.pokrov.space",
  [string]$EmergencySigningKeyId = $env:POKROV_EMERGENCY_SIGNING_KEY_ID,
  [string]$EmergencySigningPublicKey = $env:POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64,
  [string]$SupportSigningKeyId = $env:POKROV_SUPPORT_SIGNING_KEY_ID,
  [string]$SupportSigningPublicKey = $env:POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$EmergencySigningKeyId = [string]$EmergencySigningKeyId
$EmergencySigningPublicKey = [string]$EmergencySigningPublicKey
$SupportSigningKeyId = [string]$SupportSigningKeyId
$SupportSigningPublicKey = [string]$SupportSigningPublicKey
. (Join-Path $PSScriptRoot 'support-signing-pin.ps1')
$supportSigningPin = Resolve-PokrovSupportSigningPin `
  -RepositoryRoot (Split-Path -Parent $PSScriptRoot) `
  -ProvidedKeyId $SupportSigningKeyId `
  -ProvidedPublicKeyB64Url $SupportSigningPublicKey
$SupportSigningKeyId = $supportSigningPin.key_id
$SupportSigningPublicKey = $supportSigningPin.public_key_b64url
if ($EmergencySigningKeyId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$') {
  throw "A canonical POKROV emergency signing key id is required for a production build."
}
if ($EmergencySigningPublicKey -notmatch '^[A-Za-z0-9_-]{43}$') {
  throw "A 32-byte base64url POKROV emergency signing public key is required for a production build."
}
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
  $emergencyPublicKeySha256 = -join (
    $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($EmergencySigningPublicKey)) |
      ForEach-Object { $_.ToString("x2") }
  )
} finally {
  $sha256.Dispose()
}

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

function Resolve-JdkTool {
  param([Parameter(Mandatory = $true)][string]$FileName)

  $command = Get-Command $FileName -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($command) {
    return $command.Source
  }

  $candidates = @()
  if ($env:JAVA_HOME) {
    $candidates += (Join-Path $env:JAVA_HOME "bin\$FileName")
  }
  $candidates += @(
    (Join-Path ${env:ProgramFiles} "Android\Android Studio\jbr\bin\$FileName"),
    (Join-Path ${env:ProgramFiles} "Android\Android Studio\jre\bin\$FileName")
  )
  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
      return $candidate
    }
  }
  throw "$FileName was not found in the active JDK."
}

function Set-ProcessEnvironmentValue {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [AllowNull()][string]$Value
  )
  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot "check-client-version-parity.ps1")
$androidRoot = Join-Path $repoRoot "apps\android_shell"
$pubspecPath = Join-Path $androidRoot "pubspec.yaml"
$pubspecText = Get-Content -Raw -LiteralPath $pubspecPath
$versionMatch = [regex]::Match($pubspecText, "(?m)^version:\s*([^\s]+)\s*$")
if (-not $versionMatch.Success) {
  throw "Could not read the Android package version from pubspec.yaml."
}
$declaredVersionParts = $versionMatch.Groups[1].Value.Split("+", 2)
if ($declaredVersionParts.Count -ne 2 -or $declaredVersionParts[1] -notmatch '^[1-9][0-9]*$') {
  throw "Android pubspec.yaml must declare a positive numeric build number."
}
$declaredVersionName = $declaredVersionParts[0]
$declaredVersionCode = $declaredVersionParts[1]
$clientRevision = ([string](& git -C $repoRoot rev-parse HEAD 2>&1 | Select-Object -First 1)).Trim()
if ($LASTEXITCODE -ne 0 -or $clientRevision -notmatch '^[0-9a-fA-F]{40}$') {
  throw "Could not bind Android diagnostics to the client revision."
}
& git -C $repoRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) {
  throw "Commit tracked client changes before building revision-bound Android diagnostics."
}
$clientRevision = $clientRevision.ToLowerInvariant()
$outputDirectory = Join-Path $androidRoot "build\app\outputs\flutter-apk"
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
    $commonBuildArguments = @(
      "build",
      "apk",
      "--release",
      "--flavor", "direct",
      "--target-platform", "android-arm,android-arm64,android-x64",
      "--android-project-arg=pokrov.singleVersionSplitApks=true",
      "--dart-define=POKROV_API_BASE_URL=$ApiBaseUrl",
      "--dart-define=POKROV_APP_VERSION=$declaredVersionName",
      "--dart-define=POKROV_BUILD_NUMBER=$declaredVersionCode",
      "--dart-define=POKROV_GIT_REVISION=$clientRevision",
      "--dart-define=POKROV_RELEASE_CHANNEL=direct",
      "--dart-define=POKROV_EMERGENCY_SIGNING_KEY_ID=$EmergencySigningKeyId",
      "--dart-define=POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64=$EmergencySigningPublicKey",
      "--dart-define=POKROV_SUPPORT_SIGNING_KEY_ID=$SupportSigningKeyId",
      "--dart-define=POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64=$SupportSigningPublicKey"
    )
    & flutter @commonBuildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production universal and ABI APK build failed with exit code $LASTEXITCODE."
    }

    $storeBundleBuildArguments = @(
      "build",
      "appbundle",
      "--release",
      "--flavor", "store",
      "--target-platform", "android-arm,android-arm64,android-x64",
      "--dart-define=POKROV_API_BASE_URL=$ApiBaseUrl",
      "--dart-define=POKROV_APP_VERSION=$declaredVersionName",
      "--dart-define=POKROV_BUILD_NUMBER=$declaredVersionCode",
      "--dart-define=POKROV_GIT_REVISION=$clientRevision",
      "--dart-define=POKROV_RELEASE_CHANNEL=store",
      "--dart-define=POKROV_EMERGENCY_SIGNING_KEY_ID=$EmergencySigningKeyId",
      "--dart-define=POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64=$EmergencySigningPublicKey",
      "--dart-define=POKROV_SUPPORT_SIGNING_KEY_ID=$SupportSigningKeyId",
      "--dart-define=POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64=$SupportSigningPublicKey"
    )
    & flutter @storeBundleBuildArguments
    if ($LASTEXITCODE -ne 0) {
      throw "Flutter production store AAB build failed with exit code $LASTEXITCODE."
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

$apksigner = Resolve-AndroidBuildTool -FileName "apksigner.bat"
$expectedFingerprint = ([string]$metadata.certificate_sha256).Replace(":", "").ToUpperInvariant()
$aapt = Resolve-AndroidBuildTool -FileName "aapt.exe"
$artifacts = @(
  [ordered]@{
    path = Join-Path $outputDirectory "app-direct-release.apk"
    abi = "universal"
  },
  [ordered]@{
    path = Join-Path $outputDirectory "app-arm64-v8a-direct-release.apk"
    abi = "arm64-v8a"
  },
  [ordered]@{
    path = Join-Path $outputDirectory "app-armeabi-v7a-direct-release.apk"
    abi = "armeabi-v7a"
  },
  [ordered]@{
    path = Join-Path $outputDirectory "app-x86_64-direct-release.apk"
    abi = "x86_64"
  }
)

foreach ($artifact in $artifacts) {
  $apkPath = [string]$artifact.path
  if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf)) {
    throw "An expected production APK was not produced."
  }

  $verificationOutput = @(& $apksigner verify --verbose --print-certs $apkPath 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "apksigner rejected a production APK."
  }
  $verificationText = $verificationOutput -join "`n"
  if ($verificationText -match "Android Debug") {
    throw "A production APK is still signed with the Android Debug certificate."
  }
  $fingerprintMatch = [regex]::Match(
    $verificationText,
    "certificate SHA-256 digest:\s*([0-9a-fA-F]{64})"
  )
  if (-not $fingerprintMatch.Success) {
    throw "Could not read a production signer fingerprint from apksigner output."
  }
  $artifactFingerprint = $fingerprintMatch.Groups[1].Value.ToUpperInvariant()
  if ($artifactFingerprint -ne $expectedFingerprint) {
    throw "A production APK signer does not match the configured POKROV production certificate."
  }

  $badgingOutput = @(& $aapt dump badging $apkPath 2>&1 | ForEach-Object { [string]$_ })
  if ($LASTEXITCODE -ne 0) {
    throw "aapt could not inspect a production APK manifest."
  }
  $badgingText = $badgingOutput -join "`n"
  if ($badgingText -match "(?m)^application-debuggable") {
    throw "A production APK manifest is debuggable."
  }
  $packageMatch = [regex]::Match(
    $badgingText,
    "(?m)^package:\s+name='([^']+)'\s+versionCode='([^']+)'\s+versionName='([^']+)'"
  )
  if (-not $packageMatch.Success) {
    throw "Could not read a production APK package and version from aapt."
  }
  $artifactPackage = $packageMatch.Groups[1].Value
  $versionCode = $packageMatch.Groups[2].Value
  $versionName = $packageMatch.Groups[3].Value
  $nativeCodeMatch = [regex]::Match($badgingText, "(?m)^native-code:\s*(.+)$")
  $nativeAbis = @(
    [regex]::Matches($nativeCodeMatch.Groups[1].Value, "'([^']+)'") |
      ForEach-Object { $_.Groups[1].Value }
  )
  if ($artifactPackage -ne [string]$metadata.package_name) {
    throw "A production APK package does not match the configured signing identity."
  }
  if ($versionName -ne $declaredVersionName) {
    throw "A production APK version does not match apps/android_shell/pubspec.yaml."
  }
  if ($versionCode -ne $declaredVersionCode) {
    throw "A production APK version code does not match apps/android_shell/pubspec.yaml."
  }
  $expectedNativeAbis = if ($artifact.abi -eq "universal") {
    @("armeabi-v7a", "arm64-v8a", "x86_64")
  } else {
    @([string]$artifact.abi)
  }
  if (@(Compare-Object -ReferenceObject $expectedNativeAbis -DifferenceObject $nativeAbis).Count -ne 0) {
    throw "A production APK native ABI set does not match its artifact label."
  }

  $apk = Get-Item -LiteralPath $apkPath
  $artifactHash = (Get-FileHash -LiteralPath $apkPath -Algorithm SHA256).Hash
  $evidence = [ordered]@{
    schema_version = 1
    artifact = $apk.Name
    abi = [string]$artifact.abi
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
    emergency_signing_key_id = $EmergencySigningKeyId
    emergency_public_key_sha256 = $emergencyPublicKeySha256
    verified_at_utc = [DateTime]::UtcNow.ToString("o")
  }
  $evidencePath = "$apkPath.signing.json"
  [System.IO.File]::WriteAllText(
    $evidencePath,
    ($evidence | ConvertTo-Json -Depth 4),
    [System.Text.UTF8Encoding]::new($false)
  )

  Write-Host "Android production APK built and verified." -ForegroundColor Green
  Write-Host "ABI: $($artifact.abi)"
  Write-Host "APK: $apkPath"
  Write-Host "Size: $($apk.Length) bytes"
  Write-Host "APK SHA-256: $artifactHash"
  Write-Host "Certificate SHA-256: $artifactFingerprint"
  Write-Host "Evidence: $evidencePath"
}

$aabPath = Join-Path $androidRoot "build\app\outputs\bundle\storeRelease\app-store-release.aab"
if (-not (Test-Path -LiteralPath $aabPath -PathType Leaf)) {
  throw "The expected production store AAB was not produced."
}

$jarsigner = Resolve-JdkTool -FileName "jarsigner.exe"
$jarVerificationOutput = @(
  & $jarsigner -verify $aabPath 2>&1 | ForEach-Object { [string]$_ }
)
if ($LASTEXITCODE -ne 0) {
  throw "jarsigner rejected the production store AAB."
}
$jarVerificationText = $jarVerificationOutput -join "`n"
if ($jarVerificationText -notmatch "(?im)^\s*jar verified\.\s*$") {
  throw "jarsigner did not confirm the production store AAB signature."
}

$keytool = Resolve-JdkTool -FileName "keytool.exe"
$certificateOutput = @(
  & $keytool -printcert -jarfile $aabPath 2>&1 | ForEach-Object { [string]$_ }
)
if ($LASTEXITCODE -ne 0) {
  throw "keytool could not inspect the production store AAB signer."
}
$certificateText = $certificateOutput -join "`n"
$aabFingerprintMatch = [regex]::Match(
  $certificateText,
  "SHA256:\s*((?:[0-9a-fA-F]{2}:){31}[0-9a-fA-F]{2})"
)
if (-not $aabFingerprintMatch.Success) {
  throw "Could not read the production store AAB signer fingerprint."
}
$aabFingerprint = $aabFingerprintMatch.Groups[1].Value.Replace(":", "").ToUpperInvariant()
if ($aabFingerprint -ne $expectedFingerprint) {
  throw "The production store AAB signer does not match the configured POKROV production certificate."
}

$requiredAabEntries = @(
  "base/manifest/AndroidManifest.xml",
  "base/lib/armeabi-v7a/libpokrov-core.so",
  "base/lib/arm64-v8a/libpokrov-core.so",
  "base/lib/x86_64/libpokrov-core.so"
)
$aabArchive = [IO.Compression.ZipFile]::OpenRead($aabPath)
try {
  $aabEntryNames = @($aabArchive.Entries | ForEach-Object { $_.FullName })
  foreach ($requiredEntry in $requiredAabEntries) {
    if ($aabEntryNames -notcontains $requiredEntry) {
      throw "The production store AAB is missing a required manifest or Core ABI entry."
    }
  }
} finally {
  $aabArchive.Dispose()
}

$aab = Get-Item -LiteralPath $aabPath
$aabHash = (Get-FileHash -LiteralPath $aabPath -Algorithm SHA256).Hash
$aabEvidence = [ordered]@{
  schema_version = 1
  artifact = $aab.Name
  canonical_file_name = "pokrov-android-market.aab"
  package_name = [string]$metadata.package_name
  version_name = $declaredVersionName
  version_code = $declaredVersionCode
  distribution = "store_aab"
  build_mode = "release"
  debuggable = $false
  signing_state = "production_self_managed_upload_key"
  certificate_sha256 = $aabFingerprint
  aab_sha256 = $aabHash
  size_bytes = [int64]$aab.Length
  included_core_abis = @("armeabi-v7a", "arm64-v8a", "x86_64")
  api_base_url = $ApiBaseUrl
  emergency_signing_key_id = $EmergencySigningKeyId
  emergency_public_key_sha256 = $emergencyPublicKeySha256
  jar_signature_integrity = "PASS"
  certificate_chain_status = "SELF_MANAGED_SELF_SIGNED_NO_PUBLIC_CHAIN"
  source_client_sha = $clientRevision.ToLowerInvariant()
  store_submission_status = "NOT_REQUESTED"
  candidate_created = $false
  verified_at_utc = [DateTime]::UtcNow.ToString("o")
}
$aabEvidencePath = "$aabPath.signing.json"
[System.IO.File]::WriteAllText(
  $aabEvidencePath,
  ($aabEvidence | ConvertTo-Json -Depth 4),
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Android production store AAB built and verified." -ForegroundColor Green
Write-Host "AAB: $aabPath"
Write-Host "Size: $($aab.Length) bytes"
Write-Host "AAB SHA-256: $aabHash"
Write-Host "Certificate SHA-256: $aabFingerprint"
Write-Host "Store submission: NOT_REQUESTED"
Write-Host "Evidence: $aabEvidencePath"
