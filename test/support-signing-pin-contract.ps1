$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\support-signing-pin.ps1')

function Assert-Throws {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Action,
    [Parameter(Mandatory = $true)][string]$Case
  )

  try {
    & $Action
  } catch {
    return
  }
  throw "$Case did not fail closed."
}

$pin = Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId '' -ProvidedPublicKeyB64Url ''
if ($pin.key_id -ne 'pokrov-support-2026-08' -or
    $pin.public_key_sha256 -ne '44aed43310eaf5442b3493cbe566b5f0f620a5660bb84a6bd028832114f48845') {
  throw 'Canonical support signing pin did not resolve to the expected identity.'
}

$exact = Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId $pin.key_id -ProvidedPublicKeyB64Url $pin.public_key_b64url
if ($exact.public_key_sha256 -ne $pin.public_key_sha256) {
  throw 'Exact support signing override changed the canonical identity.'
}

Assert-Throws -Case 'Partial support signing override' -Action {
  Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId $pin.key_id -ProvidedPublicKeyB64Url '' | Out-Null
}
Assert-Throws -Case 'Different support signing key id' -Action {
  Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId 'pokrov-support-different' -ProvidedPublicKeyB64Url $pin.public_key_b64url | Out-Null
}
Assert-Throws -Case 'Different support signing public key' -Action {
  Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId $pin.key_id -ProvidedPublicKeyB64Url ('A' * 43) | Out-Null
}

$temporaryRoot = [IO.Path]::GetFullPath(
  (Join-Path ([IO.Path]::GetTempPath()) ('pokrov-support-pin-' + [guid]::NewGuid().ToString('N')))
)
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
if (-not $temporaryRoot.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Temporary support signing test root escaped the system temporary directory.'
}
try {
  $temporaryConfig = Join-Path $temporaryRoot 'config'
  [IO.Directory]::CreateDirectory($temporaryConfig) | Out-Null
  $seed = [IO.File]::ReadAllText((Join-Path $root 'config\support-signing.seed.json')) | ConvertFrom-Json
  $tamperedPath = Join-Path $temporaryConfig 'support-signing.seed.json'
  $seed.public_key_b64url = $seed.public_key_b64url.Substring(0, 42) + 'F'
  $tampered = (ConvertTo-Json $seed -Depth 10) -replace "`r`n", "`n"
  [IO.File]::WriteAllText($tamperedPath, $tampered.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  Assert-Throws -Case 'Non-canonical support signing seed encoding' -Action {
    Resolve-PokrovSupportSigningPin -RepositoryRoot $temporaryRoot -ProvidedKeyId '' -ProvidedPublicKeyB64Url '' | Out-Null
  }

  $seed.public_key_b64url = $pin.public_key_b64url
  $seed.public_key_sha256 = '0' * 64
  $tampered = (ConvertTo-Json $seed -Depth 10) -replace "`r`n", "`n"
  [IO.File]::WriteAllText($tamperedPath, $tampered.TrimEnd() + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
  Assert-Throws -Case 'Tampered support signing seed digest' -Action {
    Resolve-PokrovSupportSigningPin -RepositoryRoot $temporaryRoot -ProvidedKeyId '' -ProvidedPublicKeyB64Url '' | Out-Null
  }
} finally {
  if (Test-Path -LiteralPath $temporaryRoot) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}

Write-Host 'Support signing pin contract passed.' -ForegroundColor Green
