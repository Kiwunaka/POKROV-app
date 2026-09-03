param(
  [switch]$SyncRuntime,
  [switch]$SkipValidateSeed,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$SkipBuild,
  [switch]$SkipZip,
  [switch]$SkipInstaller,
  [switch]$OfflinePubGet,
  [string]$CoreRoot,
  [string]$EmergencySigningKeyId = $env:POKROV_EMERGENCY_SIGNING_KEY_ID,
  [string]$EmergencySigningPublicKey = $env:POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64,
  [string]$SupportSigningKeyId = $env:POKROV_SUPPORT_SIGNING_KEY_ID,
  [string]$SupportSigningPublicKey = $env:POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64,
  [switch]$RequireTrustedWindowsSigning,
  [switch]$CheckTrustedWindowsSigningReadinessOnly,
  [string]$WindowsSigningCertificateThumbprint = $env:POKROV_WINDOWS_SIGNING_CERTIFICATE_THUMBPRINT,
  [string]$WindowsSigningExpectedSubject = $env:POKROV_WINDOWS_SIGNING_EXPECTED_SUBJECT,
  [string]$WindowsSigningTimestampUrl = $env:POKROV_WINDOWS_SIGNING_TIMESTAMP_URL,
  [ValidateSet("CurrentUser", "LocalMachine")]
  [string]$WindowsSigningStoreLocation = $(
    if ($env:POKROV_WINDOWS_SIGNING_STORE_LOCATION) {
      $env:POKROV_WINDOWS_SIGNING_STORE_LOCATION
    } else {
      "CurrentUser"
    }
  ),
  [string]$SignToolPath = $env:POKROV_SIGNTOOL_PATH,
  [string]$MsvcRuntimeDirectory = $env:POKROV_MSVC_RUNTIME_DIRECTORY
)

$ErrorActionPreference = "Stop"

if (-not $CheckTrustedWindowsSigningReadinessOnly) {
  $versionParityArguments = @{}
  if ($CoreRoot) {
    $versionParityArguments.CoreRoot = $CoreRoot
  }
  & (Join-Path $PSScriptRoot "check-client-version-parity.ps1") @versionParityArguments
}

$EmergencySigningKeyId = [string]$EmergencySigningKeyId
$EmergencySigningPublicKey = [string]$EmergencySigningPublicKey
$SupportSigningKeyId = [string]$SupportSigningKeyId
$SupportSigningPublicKey = [string]$SupportSigningPublicKey
$WindowsSigningCertificateThumbprint = ([string]$WindowsSigningCertificateThumbprint).Replace(" ", "").ToUpperInvariant()
$WindowsSigningExpectedSubject = ([string]$WindowsSigningExpectedSubject).Trim()
$WindowsSigningTimestampUrl = ([string]$WindowsSigningTimestampUrl).Trim()
$SignToolPath = ([string]$SignToolPath).Trim()
$MsvcRuntimeDirectory = ([string]$MsvcRuntimeDirectory).Trim()
if (-not $CheckTrustedWindowsSigningReadinessOnly) {
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
}
$trustedWindowsSigningRequested = [bool]$RequireTrustedWindowsSigning -or
  [bool]$CheckTrustedWindowsSigningReadinessOnly -or
  [bool]$WindowsSigningCertificateThumbprint -or
  [bool]$WindowsSigningExpectedSubject -or
  [bool]$WindowsSigningTimestampUrl -or
  [bool]$SignToolPath

if ($trustedWindowsSigningRequested) {
  if ($WindowsSigningCertificateThumbprint -notmatch '^[A-F0-9]{40}$') {
    throw "Trusted Windows signing requires a 40-hex certificate-store thumbprint."
  }
  if ([string]::IsNullOrWhiteSpace($WindowsSigningExpectedSubject)) {
    throw "Trusted Windows signing requires the exact expected certificate subject."
  }
  $timestampUri = $null
  if (-not [Uri]::TryCreate($WindowsSigningTimestampUrl, [UriKind]::Absolute, [ref]$timestampUri) -or
      $timestampUri.Scheme -ne 'https') {
    throw "Trusted Windows signing requires an absolute HTTPS RFC3161 timestamp URL."
  }
  if ($SkipInstaller -and -not $CheckTrustedWindowsSigningReadinessOnly) {
    throw "Trusted Windows signing requires the exact installer; -SkipInstaller is not allowed."
  }
}

function Invoke-External {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [string[]]$Arguments = @(),
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory
  )

  $commandLabel = "$FilePath $($Arguments -join ' ')".Trim()
  Write-Host ">> $commandLabel" -ForegroundColor Cyan

  Push-Location $WorkingDirectory
  try {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$commandLabel failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Set-StableDartPluginRegistrantPackageUri {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AppDirectory
  )

  $packageConfigPath = Join-Path $AppDirectory ".dart_tool\package_config.json"
  if (-not (Test-Path -LiteralPath $packageConfigPath)) {
    throw "Flutter package config is missing after pub get: $packageConfigPath"
  }

  $packageConfig = Get-Content -Raw -LiteralPath $packageConfigPath | ConvertFrom-Json
  if ([int]$packageConfig.configVersion -ne 2) {
    throw "Flutter package config version must be 2 for reproducible Windows builds."
  }

  $stablePackageName = "pokrov_generated_registrant"
  $stableRootUri = "flutter_build/"
  $stablePackageUri = "./"
  $existing = @(
    $packageConfig.packages |
      Where-Object { [string]$_.name -eq $stablePackageName }
  )
  if ($existing.Count -gt 1) {
    throw "Flutter package config contains duplicate $stablePackageName entries."
  }
  if ($existing.Count -eq 1) {
    if ([string]$existing[0].rootUri -ne $stableRootUri -or
        [string]$existing[0].packageUri -ne $stablePackageUri) {
      throw "Flutter package config contains a conflicting $stablePackageName entry."
    }
    return
  }

  $stablePackage = [pscustomobject][ordered]@{
    name = $stablePackageName
    rootUri = $stableRootUri
    packageUri = $stablePackageUri
    languageVersion = "3.0"
  }
  $packageConfig.packages = @($packageConfig.packages) + $stablePackage
  $serialized = $packageConfig | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText(
    $packageConfigPath,
    $serialized,
    (New-Object System.Text.UTF8Encoding($false))
  )
}

function Sync-FlutterWindowsCppClientWrapper {
  param(
    [Parameter(Mandatory = $true)]
    [string]$AppDirectory
  )

  $flutterMetadataJson = & flutter --version --machine
  if ($LASTEXITCODE -ne 0) {
    throw "Could not resolve the pinned Flutter SDK metadata."
  }
  $flutterMetadata = ($flutterMetadataJson -join "`n") | ConvertFrom-Json
  $flutterRoot = [string]$flutterMetadata.flutterRoot
  if ([string]::IsNullOrWhiteSpace($flutterRoot)) {
    throw "Pinned Flutter SDK metadata does not declare flutterRoot."
  }
  $sourceDirectory = Join-Path $flutterRoot `
    "bin\\cache\\artifacts\\engine\\windows-x64\\cpp_client_wrapper"
  $destinationDirectory = Join-Path $AppDirectory `
    "windows\\flutter\\ephemeral\\cpp_client_wrapper"
  $requiredFiles = @(
    "core_implementations.cc",
    "standard_codec.cc",
    "plugin_registrar.cc",
    "flutter_engine.cc",
    "flutter_view_controller.cc",
    "include\\flutter\\basic_message_channel.h"
  )

  $missingSourceFiles = @(
    Test-RequiredFiles -BasePath $sourceDirectory -RelativePaths $requiredFiles
  )
  if ($missingSourceFiles.Count -gt 0) {
    throw "Pinned Flutter Windows C++ wrapper is incomplete: $($missingSourceFiles -join ', ')"
  }

  New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
  Copy-Item -Path (Join-Path $sourceDirectory "*") `
    -Destination $destinationDirectory -Recurse -Force

  $missingDestinationFiles = @(
    Test-RequiredFiles -BasePath $destinationDirectory -RelativePaths $requiredFiles
  )
  if ($missingDestinationFiles.Count -gt 0) {
    throw "Flutter Windows C++ wrapper staging is incomplete: $($missingDestinationFiles -join ', ')"
  }
}

function Resolve-VersionFromPubspec {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PubspecPath
  )

  $pubspec = Get-Content -Raw -LiteralPath $PubspecPath
  $match = [regex]::Match($pubspec, '(?m)^version:\s*(.+)$')
  if (-not $match.Success) {
    throw "Could not resolve a version from $PubspecPath"
  }

  return $match.Groups[1].Value.Trim()
}

function Test-RequiredFiles {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,
    [Parameter(Mandatory = $true)]
    [string[]]$RelativePaths
  )

  $missing = @()
  foreach ($relativePath in $RelativePaths) {
    $fullPath = Join-Path $BasePath $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
      $missing += $relativePath
    }
  }

  return $missing
}

function Resolve-AppLocalMsvcRuntimeDirectory {
  param(
    [string]$RequestedDirectory,
    [Parameter(Mandatory = $true)]
    [string]$ToolsetDirectory
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedDirectory)) {
    $resolved = Resolve-Path -LiteralPath $RequestedDirectory -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
      throw "POKROV_MSVC_RUNTIME_DIRECTORY must identify a directory."
    }
    return $resolved.Path
  }

  $vswhereCandidates = @(
    (Get-Command "vswhere.exe" -ErrorAction SilentlyContinue |
      Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
    Select-Object -Unique
  $vswhere = $vswhereCandidates | Select-Object -First 1
  if (-not $vswhere) {
    throw "vswhere.exe is required to locate the official x64 Microsoft VC runtime. Set POKROV_MSVC_RUNTIME_DIRECTORY explicitly when Visual Studio is installed elsewhere."
  }

  $visualStudioRoot = & $vswhere -latest -products "*" `
    -requires Microsoft.VisualStudio.Component.VC.Redist.14.Latest `
    -property installationPath
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($visualStudioRoot)) {
    throw "Visual Studio with Microsoft.VisualStudio.Component.VC.Redist.14.Latest is required for the Windows release package."
  }

  $redistRoot = Join-Path ([string]$visualStudioRoot).Trim() "VC\Redist\MSVC"
  $runtimeDirectories = @(
    Get-ChildItem -LiteralPath $redistRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
      Sort-Object { [version]$_.Name } -Descending |
      ForEach-Object {
        Join-Path $_.FullName "x64\$ToolsetDirectory"
      } |
      Where-Object { Test-Path -LiteralPath $_ -PathType Container }
  )
  $runtimeDirectory = $runtimeDirectories | Select-Object -First 1
  if (-not $runtimeDirectory) {
    throw "Could not locate the official x64 $ToolsetDirectory runtime under $redistRoot."
  }
  return $runtimeDirectory
}

function New-ReleaseManifestFileList {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BasePath,
    [Parameter(Mandatory = $true)]
    [string[]]$RelativePaths
  )

  $files = foreach ($relativePath in $RelativePaths) {
    $fullPath = Join-Path $BasePath $relativePath
    $item = Get-Item -LiteralPath $fullPath
    [ordered]@{
      path = $relativePath
      size_bytes = [int64]$item.Length
      sha256 = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    }
  }

  return $files
}

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Content
  )

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-CertificateSha256 {
  param(
    [Parameter(Mandatory = $true)]
    [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
  )

  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($sha256.ComputeHash($Certificate.RawData))).Replace("-", "")
  } finally {
    $sha256.Dispose()
  }
}

function Resolve-SignTool {
  param([string]$ExplicitPath)

  if ($ExplicitPath) {
    if (-not (Test-Path -LiteralPath $ExplicitPath -PathType Leaf)) {
      throw "Configured SignTool was not found: $ExplicitPath"
    }
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

  $pathCommand = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
  if ($pathCommand) {
    return $pathCommand.Source
  }

  $kitsRoot = if (${env:ProgramFiles(x86)}) {
    Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
  } else {
    $null
  }
  if ($kitsRoot -and (Test-Path -LiteralPath $kitsRoot)) {
    $kitCandidates = @(Get-ChildItem -LiteralPath $kitsRoot -Filter "signtool.exe" -File -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.Directory.Name -eq "x64" } |
      Sort-Object FullName -Descending)
    if ($kitCandidates.Count -gt 0) {
      return $kitCandidates[0].FullName
    }
  }

  throw "SignTool.exe is required for trusted Windows signing. Install the Windows SDK or set POKROV_SIGNTOOL_PATH."
}

function Resolve-TrustedWindowsSigningContext {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Thumbprint,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSubject,
    [Parameter(Mandatory = $true)]
    [string]$TimestampUrl,
    [Parameter(Mandatory = $true)]
    [ValidateSet("CurrentUser", "LocalMachine")]
    [string]$StoreLocation,
    [string]$ExplicitSignToolPath
  )

  $certificatePath = "Cert:\$StoreLocation\My\$Thumbprint"
  $certificate = Get-Item -LiteralPath $certificatePath -ErrorAction SilentlyContinue
  if (-not $certificate) {
    throw "Windows signing certificate was not found in $StoreLocation/My for thumbprint $Thumbprint."
  }
  if (-not $certificate.HasPrivateKey) {
    throw "Windows signing certificate $Thumbprint has no associated private key."
  }
  if ($certificate.Subject -cne $ExpectedSubject) {
    throw "Windows signing certificate subject mismatch. Expected '$ExpectedSubject', got '$($certificate.Subject)'."
  }
  if ($certificate.Subject -ceq $certificate.Issuer) {
    throw "Self-signed certificates cannot satisfy trusted Windows signing."
  }
  $codeSigningEku = @($certificate.EnhancedKeyUsageList | Where-Object {
      $_.ObjectId.Value -eq "1.3.6.1.5.5.7.3.3"
    })
  if ($codeSigningEku.Count -eq 0) {
    throw "Windows signing certificate lacks the Code Signing EKU."
  }
  $now = Get-Date
  if ($now -lt $certificate.NotBefore -or $now -gt $certificate.NotAfter) {
    throw "Windows signing certificate is outside its validity period."
  }

  $chain = New-Object Security.Cryptography.X509Certificates.X509Chain
  try {
    $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    $chain.ChainPolicy.RevocationFlag = [Security.Cryptography.X509Certificates.X509RevocationFlag]::EntireChain
    $chain.ChainPolicy.VerificationFlags = [Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
    $chain.ChainPolicy.UrlRetrievalTimeout = [TimeSpan]::FromSeconds(20)
    if (-not $chain.Build($certificate)) {
      $chainErrors = @($chain.ChainStatus | ForEach-Object { $_.Status.ToString() }) -join ", "
      throw "Windows signing certificate chain is not trusted: $chainErrors"
    }
  } finally {
    $chain.Dispose()
  }

  return [ordered]@{
    certificate = $certificate
    signtool_path = Resolve-SignTool -ExplicitPath $ExplicitSignToolPath
    store_location = $StoreLocation
    timestamp_url = $TimestampUrl
  }
}

function Get-TrustedAuthenticodeEvidence {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [Collections.IDictionary]$SigningContext
  )

  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  $certificate = $SigningContext.certificate
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    throw "Authenticode verification failed for $Path with status $($signature.Status)."
  }
  if (-not $signature.SignerCertificate -or
      $signature.SignerCertificate.Thumbprint -cne $certificate.Thumbprint -or
      $signature.SignerCertificate.Subject -cne $certificate.Subject) {
    throw "Authenticode signer identity mismatch for $Path."
  }
  if (-not $signature.TimeStamperCertificate) {
    throw "Authenticode signature has no verifiable RFC3161 timestamp for $Path."
  }

  return [ordered]@{
    file_name = [IO.Path]::GetFileName($Path)
    sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    signature_status = $signature.Status.ToString()
    signer_subject = $signature.SignerCertificate.Subject
    signer_thumbprint_sha1 = $signature.SignerCertificate.Thumbprint
    signer_certificate_sha256 = Get-CertificateSha256 -Certificate $signature.SignerCertificate
    timestamp_signer_subject = $signature.TimeStamperCertificate.Subject
    timestamp_signer_thumbprint_sha1 = $signature.TimeStamperCertificate.Thumbprint
    timestamp_signer_certificate_sha256 = Get-CertificateSha256 -Certificate $signature.TimeStamperCertificate
  }
}

function Invoke-TrustedAuthenticodeSigning {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [Collections.IDictionary]$SigningContext,
    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory
  )

  $arguments = @(
    "sign",
    "/v",
    "/s", "My",
    "/sha1", $SigningContext.certificate.Thumbprint,
    "/fd", "SHA256",
    "/tr", $SigningContext.timestamp_url,
    "/td", "SHA256"
  )
  if ($SigningContext.store_location -eq "LocalMachine") {
    $arguments += "/sm"
  }
  $arguments += $Path
  Invoke-External -FilePath $SigningContext.signtool_path -Arguments $arguments -WorkingDirectory $WorkingDirectory
  return Get-TrustedAuthenticodeEvidence -Path $Path -SigningContext $SigningContext
}

$root = Split-Path -Parent $PSScriptRoot
$windowsReleaseConfigPath = Join-Path $root "config\\windows-release.seed.json"
$runtimeArtifactsConfigPath = Join-Path $root "config\\runtime-artifacts.seed.json"
$windowsReleaseConfig = Get-Content -Raw -LiteralPath $windowsReleaseConfigPath | ConvertFrom-Json
$runtimeArtifactsConfig = Get-Content -Raw -LiteralPath $runtimeArtifactsConfigPath | ConvertFrom-Json
$expectedSignedFiles = @(
  [string]$windowsReleaseConfig.binary_name,
  [string]$windowsReleaseConfig.runtime.service_binary,
  [string]$windowsReleaseConfig.installer_name_template,
  "unins???.exe"
)
$configuredSignedFiles = @($windowsReleaseConfig.signing.required_signed_files | ForEach-Object { [string]$_ })
$signedFileContractDifference = @(Compare-Object -ReferenceObject $expectedSignedFiles -DifferenceObject $configuredSignedFiles)
if ($signedFileContractDifference.Count -ne 0) {
  throw "Windows signing seed must require the exact UI, service and installer targets."
}
$ownerUnsignedException = $windowsReleaseConfig.signing.owner_exception
$ownerUnsignedExceptionActive =
  $windowsReleaseConfig.signing.status -eq "SKIPPED_BY_OWNER" -and
  $windowsReleaseConfig.signing.blocker_code -eq "OWNER_ACCEPTED_UNSIGNED_WINDOWS_BETA_1_2_0" -and
  $windowsReleaseConfig.signing.required_for_candidate -eq $false -and
  $windowsReleaseConfig.signing.required_for_trusted_claim -eq $true -and
  $windowsReleaseConfig.channel -eq "outside_store_beta" -and
  $ownerUnsignedException.status -eq "SKIPPED_BY_OWNER" -and
  $ownerUnsignedException.authorized_on -eq "2026-08-24" -and
  $ownerUnsignedException.version_scope -eq "1.2.0" -and
  $ownerUnsignedException.channel_scope -eq "outside_store_beta" -and
  $ownerUnsignedException.distribution_scope -eq "direct_download_only" -and
  $ownerUnsignedException.trusted_claim_allowed -eq $false -and
  $ownerUnsignedException.store_claim_allowed -eq $false -and
  $ownerUnsignedException.smartscreen_warning_required -eq $true -and
  $ownerUnsignedException.expires_when_trusted_signing_is_available -eq $true
if ($windowsReleaseConfig.signing.required_for_candidate -ne $true -and
    -not $ownerUnsignedExceptionActive) {
  throw "Unsigned Windows candidate policy is incomplete or outside the exact owner-approved 1.2.0 beta scope."
}
$trustedWindowsSigningContext = $null
if ($trustedWindowsSigningRequested) {
  $trustedWindowsSigningContext = Resolve-TrustedWindowsSigningContext `
    -Thumbprint $WindowsSigningCertificateThumbprint `
    -ExpectedSubject $WindowsSigningExpectedSubject `
    -TimestampUrl $WindowsSigningTimestampUrl `
    -StoreLocation $WindowsSigningStoreLocation `
    -ExplicitSignToolPath $SignToolPath
}
if ($CheckTrustedWindowsSigningReadinessOnly) {
  $readinessReceipt = [ordered]@{
    schema = "pokrov.windows-signing-readiness-receipt.v1"
    status = "PASS"
    scope = "local_certificate_store_readiness"
    checked_at_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    signing_contract = "AUTHENTICODE_SHA256_RFC3161_HTTPS_V1"
    store_location = $trustedWindowsSigningContext.store_location
    signer_subject = $trustedWindowsSigningContext.certificate.Subject
    signer_thumbprint_sha1 = $trustedWindowsSigningContext.certificate.Thumbprint
    signer_certificate_sha256 = Get-CertificateSha256 `
      -Certificate $trustedWindowsSigningContext.certificate
    certificate_not_before_utc = $trustedWindowsSigningContext.certificate.NotBefore.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    certificate_not_after_utc = $trustedWindowsSigningContext.certificate.NotAfter.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    code_signing_eku = $true
    private_key_present = $true
    self_signed = $false
    chain_trusted = $true
    chain_revocation_mode = "ONLINE_ENTIRE_CHAIN"
    signtool_present = $true
    timestamp_url = $trustedWindowsSigningContext.timestamp_url
    pfx_path_or_password_accepted = $false
    artifacts_signed = $false
    candidate_created = $false
    production_runtime_mutated = $false
    private_key_value_exposed = $false
  }
  Write-Output ($readinessReceipt | ConvertTo-Json -Depth 4)
  return
}
if (($windowsReleaseConfig.PSObject.Properties.Name -contains "portable_zip") -and
    -not [bool]$windowsReleaseConfig.portable_zip.supported) {
  $SkipZip = $true
}
$appDirectory = Join-Path $root "apps\\windows_shell"
$pubspecPath = Join-Path $appDirectory "pubspec.yaml"
$version = Resolve-VersionFromPubspec -PubspecPath $pubspecPath
if ($ownerUnsignedExceptionActive) {
  $productVersion = ($version -split '\+', 2)[0]
  $unsignedWarning = [string]$windowsReleaseConfig.signing.user_warning
  if ($productVersion -ne [string]$ownerUnsignedException.version_scope) {
    throw "The unsigned Windows owner exception does not cover product version $productVersion."
  }
  if ([string]::IsNullOrWhiteSpace($unsignedWarning) -or
      ($unsignedWarning -notmatch 'SmartScreen') -or
      ($unsignedWarning -notmatch 'unknown-publisher')) {
    throw "The unsigned Windows beta requires the canonical SmartScreen and unknown-publisher warning."
  }
}

$runtimeDirectory = Join-Path $root $windowsReleaseConfig.runtime.artifact_directory
$runtimeRequiredFiles = @(
  $windowsReleaseConfig.runtime.core_binary
)
if ($windowsReleaseConfig.runtime.PSObject.Properties.Name -contains "helper_binary") {
  $runtimeRequiredFiles += $windowsReleaseConfig.runtime.helper_binary
}
if ($windowsReleaseConfig.runtime.PSObject.Properties.Name -contains "runtime_dependencies") {
  $runtimeRequiredFiles += @($windowsReleaseConfig.runtime.runtime_dependencies)
}

if (-not $SkipValidateSeed) {
  $validateSeedArguments = @{}
  if ($CoreRoot) {
    $validateSeedArguments.CoreRoot = $CoreRoot
  }
  & (Join-Path $PSScriptRoot "validate-seed.ps1") @validateSeedArguments
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

$runtimeMissingFiles = @(
  Test-RequiredFiles -BasePath $runtimeDirectory -RelativePaths $runtimeRequiredFiles
)
if ($SyncRuntime -or $runtimeMissingFiles.Count -gt 0) {
  $syncArguments = @{
    Platforms = @("windows")
  }
  if ($CoreRoot) {
    $syncArguments.CoreRoot = $CoreRoot
  }
  & (Join-Path $PSScriptRoot "sync-pokrov-core-runtime.ps1") @syncArguments
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

$appLocalMsvcRuntimeFiles = @($windowsReleaseConfig.app_local_msvc_runtime.required_files)
if ($appLocalMsvcRuntimeFiles.Count -eq 0) {
  throw "Windows release config must declare app-local Microsoft VC runtime files."
}
$duplicateMsvcRuntimeFiles = @(
  $appLocalMsvcRuntimeFiles |
    Group-Object |
    Where-Object Count -gt 1 |
    Select-Object -ExpandProperty Name
)
if ($duplicateMsvcRuntimeFiles.Count -gt 0) {
  throw "Windows release config contains duplicate app-local Microsoft VC runtime files: $($duplicateMsvcRuntimeFiles -join ', ')"
}
foreach ($runtimeFile in $appLocalMsvcRuntimeFiles) {
  if (@($windowsReleaseConfig.required_files) -notcontains $runtimeFile) {
    throw "App-local Microsoft VC runtime file is absent from required_files: $runtimeFile"
  }
}
$appLocalMsvcRuntimeDirectory = Resolve-AppLocalMsvcRuntimeDirectory `
  -RequestedDirectory $MsvcRuntimeDirectory `
  -ToolsetDirectory ([string]$windowsReleaseConfig.app_local_msvc_runtime.toolset_directory)
$missingMsvcRuntimeFiles = @(
  Test-RequiredFiles -BasePath $appLocalMsvcRuntimeDirectory -RelativePaths $appLocalMsvcRuntimeFiles
)
if ($missingMsvcRuntimeFiles.Count -gt 0) {
  throw "Missing expected app-local Microsoft VC runtime files: $($missingMsvcRuntimeFiles -join ', ')"
}
$appLocalMsvcRuntimeEvidence = foreach ($runtimeFile in $appLocalMsvcRuntimeFiles) {
  $runtimePath = Join-Path $appLocalMsvcRuntimeDirectory $runtimeFile
  $signature = Get-AuthenticodeSignature -FilePath $runtimePath
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
      -not $signature.SignerCertificate -or
      $signature.SignerCertificate.Subject -notmatch '(?i)Microsoft') {
    throw "App-local Microsoft VC runtime file is not validly Microsoft-signed: $runtimeFile"
  }
  [ordered]@{
    path = $runtimeFile
    product_version = [string](Get-Item -LiteralPath $runtimePath).VersionInfo.ProductVersion
    sha256 = (Get-FileHash -LiteralPath $runtimePath -Algorithm SHA256).Hash
  }
}

if (-not $SkipTests) {
  $runTestsArgs = @()
  if ($OfflinePubGet) {
    $runTestsArgs += "-OfflinePubGet"
  }
  & (Join-Path $PSScriptRoot "run-tests.ps1") @runTestsArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} elseif ($SkipBuild) {
  $pubGetArgs = @("pub", "get")
  if ($OfflinePubGet) {
    $pubGetArgs += "--offline"
  }
  Invoke-External -FilePath "flutter" -Arguments $pubGetArgs -WorkingDirectory $appDirectory
}

if (-not $SkipAnalyze) {
  Invoke-External -FilePath "flutter" -Arguments @("analyze") -WorkingDirectory $appDirectory
}

if (-not $SkipBuild) {
  $buildPubGetArgs = @("pub", "get")
  if ($OfflinePubGet) {
    $buildPubGetArgs += "--offline"
  }
  Invoke-External -FilePath "flutter" -Arguments $buildPubGetArgs -WorkingDirectory $appDirectory
  Set-StableDartPluginRegistrantPackageUri -AppDirectory $appDirectory
  Sync-FlutterWindowsCppClientWrapper -AppDirectory $appDirectory

  $windowsBuildDirectory = Join-Path $appDirectory "build\\windows"
  if (Test-Path -LiteralPath $windowsBuildDirectory) {
    Remove-Item -Recurse -Force -LiteralPath $windowsBuildDirectory
  }
  Invoke-External -FilePath "flutter" -Arguments @(
    "build",
    "windows",
    "--release",
    "--no-pub",
    "--dart-define=POKROV_APP_VERSION=$version",
    "--dart-define=POKROV_EMERGENCY_SIGNING_KEY_ID=$EmergencySigningKeyId",
    "--dart-define=POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64=$EmergencySigningPublicKey",
    "--dart-define=POKROV_SUPPORT_SIGNING_KEY_ID=$SupportSigningKeyId",
    "--dart-define=POKROV_SUPPORT_SIGNING_PUBLIC_KEY_B64=$SupportSigningPublicKey"
  ) -WorkingDirectory $appDirectory
}

function Write-Utf8BomFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Content
  )

  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

$releaseOutputDirectory = Join-Path $root $windowsReleaseConfig.bundle_root
$buildRequiredFiles = @(
  @($windowsReleaseConfig.required_files) |
    Where-Object { $appLocalMsvcRuntimeFiles -notcontains $_ }
)
$missingBuildFiles = @(
  Test-RequiredFiles -BasePath $releaseOutputDirectory -RelativePaths $buildRequiredFiles
)
if ($missingBuildFiles.Count -gt 0) {
  throw "Missing expected Windows release outputs: $($missingBuildFiles -join ', ')"
}

$exePath = Join-Path $releaseOutputDirectory $windowsReleaseConfig.binary_name
$versionInfo = (Get-Item -LiteralPath $exePath).VersionInfo
$metadataErrors = @()

if ($versionInfo.CompanyName -ne $windowsReleaseConfig.metadata.company_name) {
  $metadataErrors += "CompanyName must be '$($windowsReleaseConfig.metadata.company_name)' but was '$($versionInfo.CompanyName)'"
}

if ($versionInfo.FileDescription -ne $windowsReleaseConfig.metadata.file_description) {
  $metadataErrors += "FileDescription must be '$($windowsReleaseConfig.metadata.file_description)' but was '$($versionInfo.FileDescription)'"
}

if ($versionInfo.ProductName -ne $windowsReleaseConfig.metadata.product_name) {
  $metadataErrors += "ProductName must be '$($windowsReleaseConfig.metadata.product_name)' but was '$($versionInfo.ProductName)'"
}

if ($metadataErrors.Count -gt 0) {
  throw ($metadataErrors -join [Environment]::NewLine)
}

$artifactRoot = Join-Path $root $windowsReleaseConfig.artifact_root
$bundleFolderName = $windowsReleaseConfig.bundle_folder_template.Replace("{version}", $version)
$zipName = $windowsReleaseConfig.zip_name_template.Replace("{version}", $version)
$installerName = $windowsReleaseConfig.installer_name_template.Replace("{version}", $version)
$manifestName = $windowsReleaseConfig.manifest_name_template.Replace("{version}", $version)
$stagedBundleDirectory = Join-Path $artifactRoot $bundleFolderName
$zipPath = Join-Path $artifactRoot $zipName
$installerPath = Join-Path $artifactRoot $installerName
$manifestPath = Join-Path $artifactRoot $manifestName

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

if (Test-Path -LiteralPath $stagedBundleDirectory) {
  Remove-Item -Recurse -Force -LiteralPath $stagedBundleDirectory
}

New-Item -ItemType Directory -Force -Path $stagedBundleDirectory | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $releaseOutputDirectory "*") -Destination $stagedBundleDirectory
foreach ($runtimeFile in $appLocalMsvcRuntimeFiles) {
  Copy-Item -Force -LiteralPath (Join-Path $appLocalMsvcRuntimeDirectory $runtimeFile) `
    -Destination (Join-Path $stagedBundleDirectory $runtimeFile)
}
$missingStagedFiles = @(
  Test-RequiredFiles -BasePath $stagedBundleDirectory -RelativePaths $windowsReleaseConfig.required_files
)
if ($missingStagedFiles.Count -gt 0) {
  throw "Missing expected staged Windows release outputs: $($missingStagedFiles -join ', ')"
}

$trustedSigningEvidence = @()
if ($trustedWindowsSigningContext) {
  foreach ($signedBinaryName in @(
      $windowsReleaseConfig.binary_name,
      $windowsReleaseConfig.runtime.service_binary
    )) {
    $signedBinaryPath = Join-Path $stagedBundleDirectory $signedBinaryName
    $trustedSigningEvidence += Invoke-TrustedAuthenticodeSigning `
      -Path $signedBinaryPath `
      -SigningContext $trustedWindowsSigningContext `
      -WorkingDirectory $artifactRoot
  }
}

if (-not $SkipZip) {
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -Force -LiteralPath $zipPath
  }
  Compress-Archive -Path (Join-Path $stagedBundleDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal
}

$installerSha256 = $null
if (-not $SkipInstaller) {
  $innoCandidates = @(
    (Get-Command "ISCC.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
    (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
  $iscc = $innoCandidates | Select-Object -First 1
  if (-not $iscc) {
    throw "Inno Setup 6 (ISCC.exe) is required to build the Windows installer."
  }

  $issPath = Join-Path $artifactRoot ($installerName + ".iss")
  $installerOutputName = [System.IO.Path]::GetFileNameWithoutExtension($installerName)
  $setupIconPath = Join-Path $appDirectory "windows\runner\resources\app_icon.ico"
  $innoSigningDirectives = "SignedUninstaller=no"
  $innoArguments = @("/Qp")
  $signedUninstallerDirectory = $null
  if ($trustedWindowsSigningContext) {
    $signedUninstallerDirectory = Join-Path $artifactRoot "signed-uninstaller"
    New-Item -ItemType Directory -Force -Path $signedUninstallerDirectory | Out-Null
    Get-ChildItem -LiteralPath $signedUninstallerDirectory -Filter "unins*.exe" -File -ErrorAction SilentlyContinue |
      Remove-Item -Force

    $innoSigningDirectives = @"
SignTool=POKROV
SignedUninstaller=yes
SignedUninstallerDir=$signedUninstallerDirectory
"@
    $innoStoreFlag = if ($trustedWindowsSigningContext.store_location -eq "LocalMachine") { " /sm" } else { "" }
    $innoSignToolCommand = '$q' + $trustedWindowsSigningContext.signtool_path +
      '$q sign /v /s My /sha1 ' + $trustedWindowsSigningContext.certificate.Thumbprint +
      $innoStoreFlag + ' /fd SHA256 /tr ' + $trustedWindowsSigningContext.timestamp_url +
      ' /td SHA256 $f'
    $innoArguments += "/SPOKROV=$innoSignToolCommand"
  }
  $iss = @"
#pragma code_page 65001
[Setup]
AppId={{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}
AppName=POKROV VPN
AppVersion=$version
AppPublisher=POKROV
AppPublisherURL=https://pokrov.space/
AppSupportURL=https://pokrov.space/support/
DefaultDirName={autopf}\POKROV
DefaultGroupName=POKROV
DisableDirPage=no
DisableProgramGroupPage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=$artifactRoot
OutputBaseFilename=$installerOutputName
SetupIconFile=$setupIconPath
UninstallDisplayIcon={app}\$($windowsReleaseConfig.binary_name)
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
$innoSigningDirectives
CloseApplications=yes
RestartApplications=no
AppMutex=POKROV.Windows.Shell

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"; Flags: unchecked

[Files]
Source: "$stagedBundleDirectory\*"; Excludes: "\$($windowsReleaseConfig.runtime.service_binary)"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "$stagedBundleDirectory\$($windowsReleaseConfig.runtime.service_binary)"; DestDir: "{app}"; Flags: ignoreversion; AfterInstall: InstallAndStartService

[Icons]
Name: "{group}\POKROV"; Filename: "{app}\$($windowsReleaseConfig.binary_name)"; WorkingDir: "{app}"
Name: "{autodesktop}\POKROV"; Filename: "{app}\$($windowsReleaseConfig.binary_name)"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKLM64; Subkey: "Software\space.pokrov\POKROV\Service"; ValueType: string; ValueName: "InstallOwnerSid"; ValueData: "{code:GetInstallOwnerSid}"; Flags: uninsdeletekey

[Run]
Filename: "{app}\$($windowsReleaseConfig.binary_name)"; WorkingDir: "{app}"; Description: "Запустить POKROV"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ""`$ErrorActionPreference='Stop'; `$service=Get-Service -Name 'POKROVService' -ErrorAction SilentlyContinue; if (`$null -ne `$service -and `$service.Status -ne 'Stopped') {{ Stop-Service -InputObject `$service -Force -ErrorAction Stop; `$service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30)) }"""; Flags: runhidden waituntilterminated; RunOnceId: "StopPOKROVService"
Filename: "{sys}\sc.exe"; Parameters: "delete POKROVService"; Flags: runhidden waituntilterminated; RunOnceId: "DeletePOKROVService"

[UninstallDelete]
Type: dirifempty; Name: "{app}"

[Code]
var
  InstallOwnerSid: String;
  SetupFailureExitCode: Integer;
  InstallOwnerRegistryKeyExisted: Boolean;
  InstallOwnerRegistryValueExisted: Boolean;
  InstallOwnerPreviousSid: String;
  LegacyPerUserInstallDetected: Boolean;
  LegacyPerUserInstallDirectory: String;
  LegacyPerUserUninstaller: String;

function InitializeUninstall: Boolean;
var
  ResultCode: Integer;
begin
  Result := Exec(
    ExpandConstant('{sys}\taskkill.exe'),
    '/IM "$($windowsReleaseConfig.binary_name)" /T /F',
    '',
    SW_HIDE,
    ewWaitUntilTerminated,
    ResultCode
  );
  if not Result then
  begin
    Log('POKROV_UI_CLOSE_FAILED: taskkill could not be started');
    Exit;
  end;
  if (ResultCode <> 0) and (ResultCode <> 128) then
  begin
    Log(Format('POKROV_UI_CLOSE_FAILED: taskkill exit %d', [ResultCode]));
    Result := False;
    Exit;
  end;
  Result := True;
end;

function IsSidCharacter(Value: Char): Boolean;
begin
  Result := ((Value >= '0') and (Value <= '9')) or (Value = '-');
end;

function ExtractOwnerSid(const Value: String): String;
var
  StartAt: Integer;
  EndAt: Integer;
begin
  Result := '';
  StartAt := Pos('S-1-5-21-', Value);
  if StartAt = 0 then
    exit;
  EndAt := StartAt + Length('S-1-5-21-');
  while (EndAt <= Length(Value)) and IsSidCharacter(Value[EndAt]) do
    EndAt := EndAt + 1;
  Result := Copy(Value, StartAt, EndAt - StartAt);
  if (Length(Result) < 16) or (Length(Result) > 184) then
    Result := '';
end;

function TryReuseExistingInstallOwnerSid(): Boolean;
var
  ExistingOwnerSid: String;
begin
  Result := RegQueryStringValue(HKLM64,
    'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
    ExistingOwnerSid);
  if Result then
  begin
    Result := (ExistingOwnerSid <> '') and
      (ExtractOwnerSid(ExistingOwnerSid) = ExistingOwnerSid);
    if Result then
    begin
      InstallOwnerSid := ExistingOwnerSid;
      Log('POKROV_INSTALL_OWNER_REUSED_FOR_UPGRADE');
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  SidFile: String;
  SidLines: TArrayOfString;
  CommandLine: String;
  ResultCode: Integer;
  OwnerQuerySucceeded: Boolean;
begin
  Result := '';
  LegacyPerUserInstallDirectory :=
    ExpandConstant('{localappdata}\Programs\POKROV');
  LegacyPerUserUninstaller :=
    AddBackslash(LegacyPerUserInstallDirectory) + 'unins000.exe';
  LegacyPerUserInstallDetected := RegKeyExists(HKCU,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}_is1');
  if LegacyPerUserInstallDetected and
      not FileExists(LegacyPerUserUninstaller) then
  begin
    Result := 'Старая пользовательская установка POKROV повреждена: ' +
      'не найден её деинсталлятор. Удалите POKROV 1.1.6 вручную и ' +
      'повторите установку.';
    exit;
  end;
  SidFile := ExpandConstant('{tmp}\pokrov-install-owner.sid');
  DeleteFile(SidFile);
  CommandLine := '/C ""' + ExpandConstant('{sys}\whoami.exe') +
    '" /user /fo csv /nh > "' + SidFile + '""';
  OwnerQuerySucceeded := ExecAsOriginalUser(
    ExpandConstant('{sys}\cmd.exe'), CommandLine, '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
  if OwnerQuerySucceeded then
    OwnerQuerySucceeded := ResultCode = 0;
  if OwnerQuerySucceeded then
    OwnerQuerySucceeded := LoadStringsFromFile(SidFile, SidLines) and
      (GetArrayLength(SidLines) > 0);
  if OwnerQuerySucceeded then
    InstallOwnerSid := ExtractOwnerSid(SidLines[0])
  else
    InstallOwnerSid := '';
  if InstallOwnerSid = '' then
  begin
    if not TryReuseExistingInstallOwnerSid() then
    begin
      if OwnerQuerySucceeded then
        Result := 'Windows вернула некорректный SID владельца установки POKROV.'
      else
        Result := 'Не удалось определить владельца установки POKROV.';
      exit;
    end;
  end;
  Exec(ExpandConstant('{sys}\net.exe'), 'stop POKROVService /y', '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode);
end;

function GetInstallOwnerSid(Param: String): String;
begin
  Result := InstallOwnerSid;
end;

function ServiceExists(): Boolean;
begin
  Result := RegKeyExists(HKLM64,
    'SYSTEM\CurrentControlSet\Services\POKROVService');
end;

function ExecuteServiceCommand(const Parameters: String;
  var ResultCode: Integer): Boolean;
begin
  ResultCode := -1;
  Result := Exec(ExpandConstant('{sys}\sc.exe'), Parameters, '', SW_HIDE,
    ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

procedure AbortServiceSetup(const FailureCode: String;
  const CreatedBySetup: Boolean; const ResultCode: Integer);
var
  CleanupCode: Integer;
begin
  SetupFailureExitCode := 4;
  if CreatedBySetup then
  begin
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop POKROVService', '', SW_HIDE,
      ewWaitUntilTerminated, CleanupCode);
    Exec(ExpandConstant('{sys}\sc.exe'), 'delete POKROVService', '', SW_HIDE,
      ewWaitUntilTerminated, CleanupCode);
  end;
  if InstallOwnerRegistryValueExisted then
    RegWriteStringValue(HKLM64,
      'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
      InstallOwnerPreviousSid)
  else if InstallOwnerRegistryKeyExisted then
    RegDeleteValue(HKLM64, 'Software\space.pokrov\POKROV\Service',
      'InstallOwnerSid')
  else
    RegDeleteKeyIncludingSubkeys(HKLM64,
      'Software\space.pokrov\POKROV\Service');
  RaiseException(FailureCode + ' (SCM exit ' + IntToStr(ResultCode) + ').');
end;

procedure MigrateLegacyPerUserInstall(const CreatedBySetup: Boolean);
var
  ResultCode: Integer;
  LegacyBinary: String;
  LegacyUninstallRegistryKey: String;
begin
  if not LegacyPerUserInstallDetected then
    exit;
  LegacyBinary := AddBackslash(LegacyPerUserInstallDirectory) +
    'pokrov_windows.exe';
  LegacyUninstallRegistryKey :=
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    '{A8EE9193-93A9-4B13-A7AD-8441D98A48E1}_is1';
  if not Exec(LegacyPerUserUninstaller,
      '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode) or (ResultCode <> 0) then
    AbortServiceSetup('POKROV_LEGACY_PER_USER_UNINSTALL_FAILED',
      CreatedBySetup, ResultCode);
  if RegKeyExists(HKCU, LegacyUninstallRegistryKey) or
      FileExists(LegacyBinary) then
    AbortServiceSetup('POKROV_LEGACY_PER_USER_RESIDUAL_FOUND',
      CreatedBySetup, -1);
  Log('POKROV_LEGACY_PER_USER_MIGRATION_COMPLETE');
end;

function GetCustomSetupExitCode: Integer;
begin
  Result := SetupFailureExitCode;
end;

procedure DeinitializeSetup;
var
  CleanupCode: Integer;
  UninstallerPath: String;
begin
  if SetupFailureExitCode = 0 then
    exit;
  UninstallerPath := ExpandConstant('{uninstallexe}');
  if FileExists(UninstallerPath) then
  begin
    if not Exec(UninstallerPath,
        '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART', '', SW_HIDE,
        ewWaitUntilTerminated, CleanupCode) or (CleanupCode <> 0) then
      Log('POKROV_SERVICE_FAILURE_UNINSTALL_CLEANUP_FAILED exit=' +
        IntToStr(CleanupCode));
  end
  else
    Log('POKROV_SERVICE_FAILURE_UNINSTALLER_MISSING');
end;

procedure InstallAndStartService;
var
  CreatedBySetup: Boolean;
  ResultCode: Integer;
  ServiceBinary: String;
begin
  CreatedBySetup := not ServiceExists();
  InstallOwnerRegistryKeyExisted := RegKeyExists(HKLM64,
    'Software\space.pokrov\POKROV\Service');
  InstallOwnerRegistryValueExisted := RegQueryStringValue(HKLM64,
    'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
    InstallOwnerPreviousSid);
  if not RegWriteStringValue(HKLM64,
      'Software\space.pokrov\POKROV\Service', 'InstallOwnerSid',
      InstallOwnerSid) then
    AbortServiceSetup('POKROV_SERVICE_OWNER_BINDING_FAILED', CreatedBySetup,
      -1);
  ServiceBinary := ExpandConstant('{app}\pokrov_service.exe');
  if CreatedBySetup then
  begin
    if not ExecuteServiceCommand(
      'create POKROVService binPath= "' + ServiceBinary +
      '" start= auto DisplayName= "POKROV Service"', ResultCode) then
      AbortServiceSetup('POKROV_SERVICE_CREATE_FAILED', CreatedBySetup,
        ResultCode);
  end
  else
  begin
    if not ExecuteServiceCommand(
      'config POKROVService binPath= "' + ServiceBinary +
      '" start= auto DisplayName= "POKROV Service"', ResultCode) then
      AbortServiceSetup('POKROV_SERVICE_CONFIG_FAILED', CreatedBySetup,
        ResultCode);
  end;

  if not ExecuteServiceCommand(
    'description POKROVService "POKROV privileged runtime service"',
    ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_DESCRIPTION_FAILED', CreatedBySetup,
      ResultCode);
  if not ExecuteServiceCommand(
    'failure POKROVService reset= 86400 actions= restart/5000/restart/15000',
    ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_RECOVERY_FAILED', CreatedBySetup,
      ResultCode);
  if not ExecuteServiceCommand('start POKROVService', ResultCode) then
    AbortServiceSetup('POKROV_SERVICE_START_FAILED', CreatedBySetup,
      ResultCode);
  MigrateLegacyPerUserInstall(CreatedBySetup);
end;
"@
  Write-Utf8BomFile -Path $issPath -Content $iss
  if (Test-Path -LiteralPath $installerPath) {
    Remove-Item -Force -LiteralPath $installerPath
  }
  $innoArguments += $issPath
  Invoke-External -FilePath $iscc -Arguments $innoArguments -WorkingDirectory $artifactRoot
  if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "ISCC.exe did not produce installer: $installerPath"
  }
  if ($trustedWindowsSigningContext) {
    $installerSigningEvidence = Get-TrustedAuthenticodeEvidence `
      -Path $installerPath `
      -SigningContext $trustedWindowsSigningContext
    $installerSigningEvidence["target_role"] = "installer"
    $trustedSigningEvidence += $installerSigningEvidence

    $signedUninstallers = @(Get-ChildItem -LiteralPath $signedUninstallerDirectory -Filter "unins*.exe" -File)
    if ($signedUninstallers.Count -ne 1) {
      throw "Inno Setup must produce exactly one signed uninstaller evidence file; found $($signedUninstallers.Count)."
    }
    $uninstallerSigningEvidence = Get-TrustedAuthenticodeEvidence `
      -Path $signedUninstallers[0].FullName `
      -SigningContext $trustedWindowsSigningContext
    $uninstallerSigningEvidence["target_role"] = "embedded_uninstaller"
    $trustedSigningEvidence += $uninstallerSigningEvidence
  }
  $installerSha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
}

$trustedSigningStatus = if ($trustedWindowsSigningContext) {
  "PASS"
} elseif ($ownerUnsignedExceptionActive) {
  "SKIPPED_BY_OWNER"
} else {
  "MISSING"
}
$trustedSigningManifest = [ordered]@{
  status = $trustedSigningStatus
  contract = [string]$windowsReleaseConfig.signing.contract
  blocker_code = if ($trustedWindowsSigningContext) {
    $null
  } elseif ($ownerUnsignedExceptionActive) {
    "OWNER_ACCEPTED_UNSIGNED_WINDOWS_BETA_1_2_0"
  } else {
    "MISSING_TRUSTED_WINDOWS_SIGNATURE"
  }
  required_for_candidate = [bool]$windowsReleaseConfig.signing.required_for_candidate
  required_for_trusted_claim = [bool]$windowsReleaseConfig.signing.required_for_trusted_claim
  requested = [bool]$trustedWindowsSigningRequested
  certificate_store_location = if ($trustedWindowsSigningContext) { $trustedWindowsSigningContext.store_location } else { $null }
  expected_subject = if ($trustedWindowsSigningContext) { $trustedWindowsSigningContext.certificate.Subject } else { $null }
  signer_thumbprint_sha1 = if ($trustedWindowsSigningContext) { $trustedWindowsSigningContext.certificate.Thumbprint } else { $null }
  signer_certificate_sha256 = if ($trustedWindowsSigningContext) {
    Get-CertificateSha256 -Certificate $trustedWindowsSigningContext.certificate
  } else {
    $null
  }
  timestamp_url = if ($trustedWindowsSigningContext) { $trustedWindowsSigningContext.timestamp_url } else { $null }
  owner_exception = if ($ownerUnsignedExceptionActive -and -not $trustedWindowsSigningContext) {
    [ordered]@{
      status = [string]$ownerUnsignedException.status
      authorized_on = [string]$ownerUnsignedException.authorized_on
      version_scope = [string]$ownerUnsignedException.version_scope
      channel_scope = [string]$ownerUnsignedException.channel_scope
      distribution_scope = [string]$ownerUnsignedException.distribution_scope
      trusted_claim_allowed = [bool]$ownerUnsignedException.trusted_claim_allowed
      store_claim_allowed = [bool]$ownerUnsignedException.store_claim_allowed
      smartscreen_warning_required = [bool]$ownerUnsignedException.smartscreen_warning_required
      expires_when_trusted_signing_is_available = [bool]$ownerUnsignedException.expires_when_trusted_signing_is_available
    }
  } else {
    $null
  }
  user_warning = if ($trustedWindowsSigningContext) { $null } else { [string]$windowsReleaseConfig.signing.user_warning }
  targets = @($trustedSigningEvidence)
}

$manifest = [ordered]@{
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  display_name = $windowsReleaseConfig.display_name
  version = $version
  runtime_release_tag = $runtimeArtifactsConfig.core.release_tag
  release_output_directory = $releaseOutputDirectory
  staged_bundle_directory = $stagedBundleDirectory
  zip_path = if ($SkipZip) { $null } else { $zipPath }
  installer_path = if ($SkipInstaller) { $null } else { $installerPath }
  installer_sha256 = $installerSha256
  signing = $trustedSigningManifest
  app_local_msvc_runtime = [ordered]@{
    deployment = [string]$windowsReleaseConfig.app_local_msvc_runtime.deployment
    architecture = [string]$windowsReleaseConfig.app_local_msvc_runtime.architecture
    toolset_directory = [string]$windowsReleaseConfig.app_local_msvc_runtime.toolset_directory
    files = @($appLocalMsvcRuntimeEvidence)
  }
  executable = [ordered]@{
    file_name = $windowsReleaseConfig.binary_name
    file_description = $versionInfo.FileDescription
    product_name = $versionInfo.ProductName
    product_version = $versionInfo.ProductVersion
    is_prerelease = [bool]$versionInfo.IsPreRelease
  }
  required_files = New-ReleaseManifestFileList -BasePath $stagedBundleDirectory -RelativePaths $windowsReleaseConfig.required_files
  safe_claims = @($windowsReleaseConfig.safe_claims)
  blocked_on = @($windowsReleaseConfig.blocked_on)
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Host "Windows bundle ready." -ForegroundColor Green
Write-Host "Version: $version"
Write-Host "Release output: $releaseOutputDirectory"
Write-Host "Staged bundle: $stagedBundleDirectory"
if (-not $SkipZip) {
  Write-Host "Zip: $zipPath"
}
if (-not $SkipInstaller) {
  Write-Host "Installer: $installerPath"
}
Write-Host "Manifest: $manifestPath"
