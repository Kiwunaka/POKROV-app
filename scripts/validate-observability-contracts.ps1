[CmdletBinding()]
param(
  [string]$PlatformRoot,
  [string]$CoreRoot,
  [string]$ClientSnapshotPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ClientSnapshotPath)) {
  $ClientSnapshotPath = Join-Path $root "config\observability-contracts.seed.json"
}

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required observability contract is missing: $Path"
  }
  return [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Assert-ExactProperties {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ($null -eq $Value) {
    throw "$Path must be an object."
  }
  $actual = @($Value.PSObject.Properties.Name | Sort-Object -CaseSensitive)
  $wanted = @($Expected | Sort-Object -CaseSensitive)
  if (@(Compare-Object -ReferenceObject $wanted -DifferenceObject $actual -CaseSensitive).Count -ne 0) {
    throw "$Path has unsupported or missing properties."
  }
}

function Assert-SameStringSet {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][object[]]$Actual,
    [Parameter(Mandatory = $true)][object[]]$Expected
  )

  $actualValues = @($Actual | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive -Unique)
  $expectedValues = @($Expected | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive -Unique)
  if (@(Compare-Object -ReferenceObject $expectedValues -DifferenceObject $actualValues -CaseSensitive).Count -ne 0 -or
      $actualValues.Count -ne $expectedValues.Count) {
    throw "$Label disagrees with the canonical platform contract."
  }
}

function Read-SnapshotContracts {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Label)

  $snapshot = Read-JsonFile $Path
  Assert-ExactProperties -Value $snapshot `
    -Expected @("schema_version", "canonical_repository", "contracts") -Path $Label
  if ([int]$snapshot.schema_version -ne 1 -or
      [string]$snapshot.canonical_repository -ne "Kiwunaka/portal") {
    throw "$Label has an unsupported identity."
  }
  $expectedVersions = @{
    "error-catalog" = "1.2.0"
    "observability-event" = "1.0.0"
  }
  $contracts = @($snapshot.contracts)
  if ($contracts.Count -ne $expectedVersions.Count) {
    throw "$Label must contain exactly two canonical contracts."
  }
  $result = @{}
  foreach ($contract in $contracts) {
    Assert-ExactProperties -Value $contract `
      -Expected @("id", "version", "sha256") -Path "$Label contract"
    $id = [string]$contract.id
    if (-not $expectedVersions.ContainsKey($id) -or $result.ContainsKey($id)) {
      throw "$Label contains an unknown or duplicate contract."
    }
    $version = [string]$contract.version
    $sha256 = [string]$contract.sha256
    if ($version -ne $expectedVersions[$id] -or $sha256 -cnotmatch '^[0-9a-f]{64}$') {
      throw "$Label contains an invalid contract identity."
    }
    $result[$id] = [pscustomobject]@{
      id = $id
      version = $version
      sha256 = $sha256
    }
  }
  return $result
}

$clientContracts = Read-SnapshotContracts -Path $ClientSnapshotPath -Label "client observability snapshot"

if (-not [string]::IsNullOrWhiteSpace($PlatformRoot)) {
  $platformPath = (Resolve-Path -LiteralPath $PlatformRoot).Path
  $platformValidator = Join-Path $platformPath "scripts\validate_observability_contracts.py"
  if (-not (Test-Path -LiteralPath $platformValidator -PathType Leaf)) {
    throw "Platform observability validator is missing."
  }
  & python.exe -B $platformValidator
  if ($LASTEXITCODE -ne 0) {
    throw "Platform observability contracts failed validation."
  }

  $canonicalPaths = @{
    "error-catalog" = Join-Path $platformPath "shared\contracts\observability\error-catalog.json"
    "observability-event" = Join-Path $platformPath "shared\contracts\observability\observability-event.schema.json"
  }
  foreach ($id in @($canonicalPaths.Keys)) {
    $actualHash = (Get-FileHash -LiteralPath $canonicalPaths[$id] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($clientContracts[$id].sha256 -ne $actualHash) {
      throw "Client observability snapshot disagrees with the canonical platform contract."
    }
  }

  $catalog = Read-JsonFile $canonicalPaths["error-catalog"]
  $eventSchema = Read-JsonFile $canonicalPaths["observability-event"]
  $dartSource = [IO.File]::ReadAllText(
    (Join-Path $root "packages\observability_contracts\lib\observability_contracts.dart")
  )
  $dartCodes = @(
    [regex]::Matches($dartSource, "'([A-Z][A-Z0-9-]{1,23}-[0-9]{3})'") |
      ForEach-Object { $_.Groups[1].Value }
  )
  Assert-SameStringSet -Label "Client typed error codes" -Actual $dartCodes `
    -Expected @($catalog.entries | ForEach-Object { $_.code })

  $attributeSection = [regex]::Match(
    $dartSource,
    '(?s)abstract final class ObservabilityAttributeKeys\s*\{(?<body>.*?)\n\}'
  )
  if (-not $attributeSection.Success) {
    throw "Client typed observability attribute allowlist is missing."
  }
  $dartAttributes = @(
    [regex]::Matches($attributeSection.Groups['body'].Value, "'([a-z][a-z0-9_]*)'") |
      ForEach-Object { $_.Groups[1].Value }
  )
  $schemaAttributes = @($eventSchema.'$defs'.attributes.properties.PSObject.Properties.Name)
  Assert-SameStringSet -Label "Client typed observability attributes" `
    -Actual $dartAttributes -Expected $schemaAttributes
}

if (-not [string]::IsNullOrWhiteSpace($CoreRoot)) {
  $corePath = (Resolve-Path -LiteralPath $CoreRoot).Path
  $coreSnapshotPath = Join-Path $corePath "config\observability-contracts.json"
  $coreContracts = Read-SnapshotContracts -Path $coreSnapshotPath -Label "Core observability snapshot"
  foreach ($id in @($clientContracts.Keys)) {
    if ($coreContracts[$id].version -ne $clientContracts[$id].version -or
        $coreContracts[$id].sha256 -ne $clientContracts[$id].sha256) {
      throw "Client and Core observability snapshots disagree."
    }
  }
  $coreValidator = Join-Path $corePath "scripts\verify-observability-contracts.ps1"
  if (-not (Test-Path -LiteralPath $coreValidator -PathType Leaf)) {
    throw "Core observability validator is missing."
  }
  $coreArguments = @{}
  if (-not [string]::IsNullOrWhiteSpace($PlatformRoot)) {
    $coreArguments.PlatformRoot = $PlatformRoot
  }
  & $coreValidator @coreArguments
  if (-not $?) {
    throw "Core observability validator returned an unsuccessful PowerShell status."
  }
}

Write-Host "Observability contract parity OK: platform/client/Core snapshots agree." -ForegroundColor Green
