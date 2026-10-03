$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$builderPath = Join-Path $root 'scripts\build-windows-release.ps1'
$builderSource = [IO.File]::ReadAllText($builderPath)
$windowsRelease = [IO.File]::ReadAllText((Join-Path $root 'config\windows-release.seed.json')) |
  ConvertFrom-Json
$builderTokens = $null
$builderParseErrors = $null
$builderAst = [Management.Automation.Language.Parser]::ParseInput(
  $builderSource, [ref]$builderTokens, [ref]$builderParseErrors
)
if ($builderParseErrors.Count -gt 0) {
  throw 'Windows signing builder has PowerShell parse errors.'
}
$versionResolver = $builderAst.Find({ param($node)
  $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq 'Resolve-VersionFromPubspec'
}, $true)
. ([scriptblock]::Create($versionResolver.Extent.Text))
$productVersion = ((Resolve-VersionFromPubspec -PubspecPath (
  Join-Path $root 'apps\windows_shell\pubspec.yaml'
)) -split '\+', 2)[0]
$expectedBlocker = 'RELEASE_APPROVAL_PENDING_' + $productVersion.Replace('.', '_')

foreach ($requiredMarker in @(
  'CheckTrustedWindowsSigningReadinessOnly',
  'pokrov.windows-signing-readiness-receipt.v1',
  'local_certificate_store_readiness',
  'chain_revocation_mode = "ONLINE_ENTIRE_CHAIN"',
  'private_key_present = $true',
  'pfx_path_or_password_accepted = $false',
  'artifacts_signed = $false',
  'candidate_created = $false',
  'production_runtime_mutated = $false',
  'private_key_value_exposed = $false',
  'RELEASE_APPROVAL_PENDING_',
  'CANDIDATE_ONLY',
  'public_approved = [bool]$windowsReleaseConfig.public_approved',
  'smartscreen_warning_required',
  'required_for_trusted_claim'
)) {
  if (-not $builderSource.Contains($requiredMarker)) {
    throw "Windows signing readiness builder lacks required marker: $requiredMarker"
  }
}

$ownerException = $windowsRelease.signing.owner_exception
$ownerAuthorizationDate = [DateTime]::MinValue
if ($windowsRelease.channel -ne 'outside_store_beta' -or
    $windowsRelease.public_approved -ne $false -or
    $windowsRelease.artifact_status -ne 'unsigned_beta_candidate' -or
    $windowsRelease.signing.status -ne 'CANDIDATE_ONLY' -or
    $windowsRelease.signing.blocker_code -ne $expectedBlocker -or
    $windowsRelease.signing.required_for_candidate -ne $false -or
    $windowsRelease.signing.required_for_trusted_claim -ne $true -or
    $ownerException.status -ne 'CANDIDATE_ONLY' -or
    -not [DateTime]::TryParseExact(
      [string]$ownerException.authorized_on,
      'yyyy-MM-dd',
      [Globalization.CultureInfo]::InvariantCulture,
      [Globalization.DateTimeStyles]::None,
      [ref]$ownerAuthorizationDate
    ) -or
    $ownerException.version_scope -ne $productVersion -or
    $ownerException.channel_scope -ne 'outside_store_beta' -or
    $ownerException.distribution_scope -ne 'direct_download_only' -or
    $ownerException.trusted_claim_allowed -ne $false -or
    $ownerException.store_claim_allowed -ne $false -or
    $ownerException.smartscreen_warning_required -ne $true -or
    $ownerException.expires_when_trusted_signing_is_available -ne $true) {
  throw "Windows unsigned preparation is not constrained to the exact $productVersion candidate-only beta scope."
}

$policyAssignment = $builderAst.Find({ param($node)
  $node -is [Management.Automation.Language.AssignmentStatementAst] -and
    $node.Left -is [Management.Automation.Language.VariableExpressionAst] -and
    $node.Left.VariablePath.UserPath -eq 'ownerUnsignedExceptionActive'
}, $true)
$policy = [scriptblock]::Create($policyAssignment.Extent.Text)
$windowsReleaseConfig = $windowsRelease
$ownerUnsignedException = $ownerException
. $policy
if (-not $ownerUnsignedExceptionActive) {
  throw 'Actual builder policy rejected the authorized current candidate.'
}
$originalVersionScope = $ownerException.version_scope
try {
  $ownerException.version_scope = '0.0.0'
  . $policy
  if ($ownerUnsignedExceptionActive) {
    throw 'Actual builder policy admitted an owner exception for another product version.'
  }
} finally {
  $ownerException.version_scope = $originalVersionScope
}

if ($windowsRelease.signing.readiness_probe.receipt_schema -ne
      'pokrov.windows-signing-readiness-receipt.v1' -or
    $windowsRelease.signing.readiness_probe.scope -ne
      'local_certificate_store_readiness' -or
    $windowsRelease.signing.readiness_probe.artifacts_signed -ne $false -or
    $windowsRelease.signing.readiness_probe.candidate_created -ne $false) {
  throw 'Windows signing readiness seed does not preserve the public no-candidate receipt contract.'
}

if (-not $IsWindows) {
  Write-Host 'Windows signing runtime negatives SKIPPED_BY_PLATFORM; source contract passed.' -ForegroundColor Yellow
  return
}

function Assert-ThrowsMessage {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$ExpectedPattern,
    [Parameter(Mandatory = $true)][string]$Case
  )

  try {
    & $Action
  } catch {
    if ($_.Exception.Message -notmatch $ExpectedPattern) {
      throw "$Case failed with an unexpected error: $($_.Exception.Message)"
    }
    return
  }
  throw "$Case did not fail closed."
}

$fixtureId = [guid]::NewGuid().ToString('N')
$selfSignedSubject = "CN=POKROV Signing Readiness Self Signed $fixtureId"
$selfSignedFixture = $null

try {
  $selfSignedFixture = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $selfSignedSubject `
    -KeyAlgorithm RSA `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -NotAfter (Get-Date).AddDays(3)

  Assert-ThrowsMessage `
    -Case 'Partial timestamp configuration' `
    -ExpectedPattern 'absolute HTTPS RFC3161 timestamp URL' `
    -Action {
      & $builderPath `
        -CheckTrustedWindowsSigningReadinessOnly `
        -WindowsSigningCertificateThumbprint $selfSignedFixture.Thumbprint `
        -WindowsSigningExpectedSubject $selfSignedFixture.Subject `
        -WindowsSigningStoreLocation CurrentUser | Out-Null
    }

  Assert-ThrowsMessage `
    -Case 'Self-signed release identity' `
    -ExpectedPattern 'Self-signed certificates cannot satisfy trusted Windows signing' `
    -Action {
      & $builderPath `
        -CheckTrustedWindowsSigningReadinessOnly `
        -WindowsSigningCertificateThumbprint $selfSignedFixture.Thumbprint `
        -WindowsSigningExpectedSubject $selfSignedFixture.Subject `
        -WindowsSigningTimestampUrl 'https://timestamp.invalid/pokrov-readiness-fixture' `
        -WindowsSigningStoreLocation CurrentUser | Out-Null
    }
} finally {
  if ($selfSignedFixture) {
    $certificateStore = [Security.Cryptography.X509Certificates.X509Store]::new(
      'My',
      [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    )
    $certificateStore.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    try {
      $matches = $certificateStore.Certificates.Find(
        [Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
        $selfSignedFixture.Thumbprint,
        $false
      )
      if ($matches.Count -ne 1 -or $matches[0].Subject -cne $selfSignedSubject) {
        throw 'Refusing to remove an unexpected Windows signing readiness fixture.'
      }
      $certificateStore.Remove($matches[0])
    } finally {
      $certificateStore.Close()
    }
  }
}

Write-Host 'Windows signing readiness source and negative contracts passed.' -ForegroundColor Green
