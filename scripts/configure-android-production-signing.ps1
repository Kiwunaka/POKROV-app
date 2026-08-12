[CmdletBinding()]
param(
  [string]$SigningDirectory = (Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "POKROV\android-signing"),
  [string]$KeyAlias = "pokrov-production",
  [string]$CertificateSubject = "CN=POKROV, O=POKROV, C=RU"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-Keytool {
  $candidate = Get-Command keytool.exe -ErrorAction SilentlyContinue
  if ($candidate) {
    return $candidate.Source
  }

  $candidates = @()
  if ($env:JAVA_HOME) {
    $candidates += (Join-Path $env:JAVA_HOME "bin\keytool.exe")
  }
  $candidates += @(
    (Join-Path ${env:ProgramFiles} "Android\Android Studio\jbr\bin\keytool.exe"),
    (Join-Path ${env:ProgramFiles} "Android\Android Studio\jre\bin\keytool.exe"),
    (Join-Path ([Environment]::GetFolderPath("UserProfile")) "tools\jdk\17.0.18\bin\keytool.exe")
  )
  foreach ($bundled in $candidates) {
    if (Test-Path -LiteralPath $bundled -PathType Leaf) {
      return $bundled
    }
  }

  throw "keytool.exe was not found. Install JDK 17 or put keytool.exe on PATH."
}

function Protect-SigningDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
  $grant = "${identity}:(OI)(CI)F"
  & icacls.exe $Path /inheritance:r /grant:r $grant /C /Q | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to restrict the Android signing directory ACL."
  }
  if (@(Get-ChildItem -LiteralPath $Path -Force).Count -gt 0) {
    & icacls.exe (Join-Path $Path "*") /inheritance:e /T /C /Q | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Failed to inherit the protected Android signing directory ACL."
    }
  }
}

function New-RandomSigningPassword {
  $bytes = [byte[]]::new(48)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToBase64String($bytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

$resolvedSigningDirectory = [System.IO.Path]::GetFullPath($SigningDirectory)
$keystorePath = Join-Path $resolvedSigningDirectory "pokrov-production.p12"
$secretPath = Join-Path $resolvedSigningDirectory "pokrov-production.password.dpapi"
$certificatePath = Join-Path $resolvedSigningDirectory "pokrov-production-certificate.der"
$legacyCertificatePath = Join-Path $resolvedSigningDirectory "pokrov-production-certificate.pem"
$metadataPath = Join-Path $resolvedSigningDirectory "pokrov-production.metadata.json"
$ownedFiles = @($keystorePath, $secretPath, $certificatePath, $metadataPath)

$hasKeystore = Test-Path -LiteralPath $keystorePath -PathType Leaf
$hasSecret = Test-Path -LiteralPath $secretPath -PathType Leaf
$hasCertificate = Test-Path -LiteralPath $certificatePath -PathType Leaf
$hasMetadata = Test-Path -LiteralPath $metadataPath -PathType Leaf
if ($hasKeystore -xor $hasSecret) {
  throw "Partial Android signing state has only one private component. Refusing to create or overwrite signing material."
}
if ($hasKeystore -and $hasSecret -and $hasCertificate -and $hasMetadata) {
  Protect-SigningDirectory -Path $resolvedSigningDirectory
  Write-Host "Android production signing is already configured." -ForegroundColor Green
  Write-Host "Metadata: $metadataPath"
  exit 0
}

[void](New-Item -ItemType Directory -Path $resolvedSigningDirectory -Force)
Protect-SigningDirectory -Path $resolvedSigningDirectory

$keytool = Resolve-Keytool
$passwordEnvironmentName = "POKROV_GENERATED_ANDROID_SIGNING_PASSWORD"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$creatingNewIdentity = -not $hasKeystore
if ($creatingNewIdentity) {
  $plainPassword = New-RandomSigningPassword
  $securePassword = ConvertTo-SecureString -String $plainPassword -AsPlainText -Force
  $encryptedPassword = ConvertFrom-SecureString -SecureString $securePassword
  [System.IO.File]::WriteAllText($secretPath, $encryptedPassword, $utf8NoBom)
} else {
  $securePassword = Get-Content -Raw -LiteralPath $secretPath | ConvertTo-SecureString
  $plainPassword = [System.Net.NetworkCredential]::new("", $securePassword).Password
}

try {
  [Environment]::SetEnvironmentVariable($passwordEnvironmentName, $plainPassword, "Process")
  if ($creatingNewIdentity) {
    $createArguments = @(
      "-genkeypair",
      "-noprompt",
      "-keystore", $keystorePath,
      "-storetype", "PKCS12",
      "-alias", $KeyAlias,
      "-keyalg", "RSA",
      "-keysize", "4096",
      "-validity", "10000",
      "-dname", $CertificateSubject,
      "-storepass:env", $passwordEnvironmentName,
      "-keypass:env", $passwordEnvironmentName
    )
    & $keytool @createArguments | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "keytool failed to create the Android production keystore."
    }
  }

  $exportArguments = @(
    "-exportcert",
    "-keystore", $keystorePath,
    "-storetype", "PKCS12",
    "-alias", $KeyAlias,
    "-file", $certificatePath,
    "-storepass:env", $passwordEnvironmentName
  )
  & $keytool @exportArguments | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "keytool failed to export the Android production certificate."
  }
} catch {
  if ($creatingNewIdentity) {
    foreach ($path in $ownedFiles) {
      if (Test-Path -LiteralPath $path -PathType Leaf) {
        Remove-Item -LiteralPath $path -Force
      }
    }
  }
  throw
} finally {
  [Environment]::SetEnvironmentVariable($passwordEnvironmentName, $null, "Process")
  $plainPassword = $null
  $securePassword = $null
}

$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
try {
  $fingerprint = $certificate.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256).ToUpperInvariant()
  $metadata = [ordered]@{
    schema_version = 1
    package_name = "space.pokrov.pokrov_android_shell"
    distribution = "direct_apk"
    key_alias = $KeyAlias
    keystore_format = "PKCS12"
    certificate_subject = $certificate.Subject
    certificate_sha256 = $fingerprint
    certificate_not_before_utc = $certificate.NotBefore.ToUniversalTime().ToString("o")
    certificate_not_after_utc = $certificate.NotAfter.ToUniversalTime().ToString("o")
    secret_storage = "Windows DPAPI CurrentUser"
    created_at_utc = [DateTime]::UtcNow.ToString("o")
  }
  [System.IO.File]::WriteAllText(
    $metadataPath,
    ($metadata | ConvertTo-Json -Depth 4),
    $utf8NoBom
  )
} finally {
  $certificate.Dispose()
}

Protect-SigningDirectory -Path $resolvedSigningDirectory

if (Test-Path -LiteralPath $legacyCertificatePath -PathType Leaf) {
  Remove-Item -LiteralPath $legacyCertificatePath -Force
}

Write-Host "Android production signing configured." -ForegroundColor Green
Write-Host "Keystore: $keystorePath"
Write-Host "Metadata: $metadataPath"
Write-Host "Certificate SHA-256: $fingerprint"
Write-Host "The private key and DPAPI secret remain outside the repository."
