function ConvertFrom-PokrovBase64Url {
  param([Parameter(Mandatory = $true)][string]$Value)

  $padded = $Value.Replace('-', '+').Replace('_', '/')
  switch ($padded.Length % 4) {
    0 { }
    2 { $padded += '==' }
    3 { $padded += '=' }
    default { throw 'Support signing public key is not canonical base64url.' }
  }
  try {
    return [Convert]::FromBase64String($padded)
  } catch {
    throw 'Support signing public key is not canonical base64url.'
  }
}

function Resolve-PokrovSupportSigningPin {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [AllowEmptyString()][string]$ProvidedKeyId,
    [AllowEmptyString()][string]$ProvidedPublicKeyB64Url
  )

  $seedPath = Join-Path $RepositoryRoot 'config\support-signing.seed.json'
  if (-not (Test-Path -LiteralPath $seedPath -PathType Leaf)) {
    throw 'The canonical support signing seed is missing.'
  }

  try {
    $seed = [IO.File]::ReadAllText($seedPath) | ConvertFrom-Json
  } catch {
    throw 'The canonical support signing seed is invalid JSON.'
  }

  $keyId = [string]$seed.key_id
  $publicKey = [string]$seed.public_key_b64url
  $expectedSha256 = ([string]$seed.public_key_sha256).ToLowerInvariant()
  if ([int]$seed.schema_version -ne 1 -or
      [string]$seed.algorithm -ne 'Ed25519' -or
      [string]$seed.purpose -ne 'support-mode-policy-v2' -or
      [string]$seed.status -ne 'active' -or
      $keyId -notmatch '^[a-z0-9][a-z0-9._-]{2,63}$' -or
      $publicKey -notmatch '^[A-Za-z0-9_-]{43}$' -or
      $expectedSha256 -notmatch '^[0-9a-f]{64}$') {
    throw 'The canonical support signing seed is invalid.'
  }

  $decoded = ConvertFrom-PokrovBase64Url -Value $publicKey
  if ($decoded.Length -ne 32) {
    throw 'The canonical support signing public key must decode to 32 bytes.'
  }
  $canonicalPublicKey = ([Convert]::ToBase64String($decoded)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  if ($canonicalPublicKey -cne $publicKey) {
    throw 'The canonical support signing public key is not canonical base64url.'
  }
  $hasher = [Security.Cryptography.SHA256]::Create()
  try {
    $actualSha256 = ([BitConverter]::ToString($hasher.ComputeHash($decoded))).Replace('-', '').ToLowerInvariant()
  } finally {
    $hasher.Dispose()
  }
  if ($actualSha256 -cne $expectedSha256) {
    throw 'The canonical support signing public key SHA-256 does not match its seed.'
  }

  $providedId = ([string]$ProvidedKeyId).Trim()
  $providedKey = ([string]$ProvidedPublicKeyB64Url).Trim()
  if ([bool]$providedId -xor [bool]$providedKey) {
    throw 'Support signing overrides must provide both key id and public key.'
  }
  if (($providedId -and $providedId -cne $keyId) -or
      ($providedKey -and $providedKey -cne $publicKey)) {
    throw 'Support signing overrides must exactly match the canonical tracked pin.'
  }

  return [pscustomobject]@{
    key_id = $keyId
    public_key_b64url = $publicKey
    public_key_sha256 = $actualSha256
    seed_path = $seedPath
  }
}
