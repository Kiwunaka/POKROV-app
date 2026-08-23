[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$CandidateInputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [Parameter(Mandatory = $true)][string]$PlatformRoot,
  [string]$CoreRoot,
  [switch]$AllowDirtySynthetic
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Assert-ExactProperties {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string[]]$Required,
    [string[]]$Optional = @(),
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ($null -eq $Value) {
    throw "$Path must be an object."
  }
  $names = @($Value.PSObject.Properties.Name)
  foreach ($name in $Required) {
    if ($names -notcontains $name) {
      throw "$Path is missing required property '$name'."
    }
  }
  $allowed = @($Required) + @($Optional)
  foreach ($name in $names) {
    if ($allowed -notcontains $name) {
      throw "$Path contains unsupported property '$name'."
    }
  }
}

function Copy-OrderedObject {
  param(
    [Parameter(Mandatory = $true)]$Value,
    [Parameter(Mandatory = $true)][string[]]$Required,
    [string[]]$Optional = @(),
    [Parameter(Mandatory = $true)][string]$Path
  )

  Assert-ExactProperties -Value $Value -Required $Required -Optional $Optional -Path $Path
  $copy = [ordered]@{}
  foreach ($name in $Required) {
    $copy[$name] = $Value.$name
  }
  foreach ($name in $Optional) {
    if (@($Value.PSObject.Properties.Name) -contains $name) {
      $copy[$name] = $Value.$name
    }
  }
  return [pscustomobject]$copy
}

function Get-Sha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)

  $algorithm = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $utf8NoBom.GetBytes($Text)
    return ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
  } finally {
    $algorithm.Dispose()
  }
}

function Read-JsonFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required JSON input is missing: $Path"
  }
  return [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function New-SigningEvidence {
  param([Parameter(Mandatory = $true)]$Value, [string]$Path)

  return Copy-OrderedObject -Value $Value -Required @("status") `
    -Optional @("signer_identity", "evidence_sha256") -Path $Path
}

function New-SupplyEvidence {
  param([Parameter(Mandatory = $true)]$Value, [string]$Path)

  return Copy-OrderedObject -Value $Value -Required @("status") `
    -Optional @("format", "sha256") -Path $Path
}

$candidateInputFullPath = (Resolve-Path -LiteralPath $CandidateInputPath).Path
$platformFullPath = (Resolve-Path -LiteralPath $PlatformRoot).Path
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$clientRoot = [IO.Path]::GetFullPath($root)
$clientPrefix = $clientRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$localCandidateRoot = [IO.Path]::GetFullPath((Join-Path $root "artifacts\candidate-staging"))
$localCandidatePrefix = $localCandidateRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$retainedReleaseRoot = [IO.Path]::GetFullPath((Join-Path $root "artifacts\releases"))
$retainedReleasePrefix = $retainedReleaseRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ($outputFullPath.Equals($retainedReleaseRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $outputFullPath.StartsWith($retainedReleasePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "WO-003 forbids writing generated metadata under artifacts/releases."
}
if ($outputFullPath.StartsWith($clientPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    -not $outputFullPath.StartsWith($localCandidatePrefix, [StringComparison]::OrdinalIgnoreCase)) {
  throw "Candidate metadata inside the client checkout must use ignored artifacts/candidate-staging."
}
if (Test-Path -LiteralPath $outputFullPath) {
  throw "Output already exists; refusing to overwrite it."
}
$outputDirectory = [IO.Path]::GetDirectoryName($outputFullPath)
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
  throw "Output directory must already exist."
}

$observabilityParityArguments = @{
  PlatformRoot = $platformFullPath
}
if (-not [string]::IsNullOrWhiteSpace($CoreRoot)) {
  $observabilityParityArguments.CoreRoot = $CoreRoot
}
& (Join-Path $root "scripts\validate-observability-contracts.ps1") @observabilityParityArguments
if (-not $?) {
  throw "Observability contract parity validation failed."
}

$inputData = Read-JsonFile $candidateInputFullPath
Assert-ExactProperties -Value $inputData `
  -Required @("purpose", "release", "sources", "compatibility", "artifacts", "manual_gates", "promotion") `
  -Path "candidate input"
Assert-ExactProperties -Value $inputData.release `
  -Required @("version", "channel", "candidate_label", "created_at_utc", "release_notes") `
  -Path "candidate input.release"
Assert-ExactProperties -Value $inputData.release.release_notes `
  -Required @("summary", "url") -Path "candidate input.release.release_notes"

if ($AllowDirtySynthetic) {
  if ($inputData.purpose -ne "synthetic_contract_test" -or
      $inputData.release.channel -eq "stable") {
    throw "AllowDirtySynthetic is restricted to non-stable synthetic contract tests."
  }
}

$gitStatus = (& git -C $root status --porcelain --untracked-files=all 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect client worktree state."
}
if (-not [string]::IsNullOrWhiteSpace($gitStatus) -and -not $AllowDirtySynthetic) {
  throw "Client worktree must be clean before generating release metadata."
}
$revisionLines = @(& git -C $root rev-parse HEAD 2>&1)
$revisionExitCode = $LASTEXITCODE
if ($revisionExitCode -ne 0 -or $revisionLines.Count -eq 0) {
  throw "Could not resolve the exact client Git revision."
}
$clientRevision = ([string]$revisionLines[0]).Trim()
if ($clientRevision -notmatch '^[A-Fa-f0-9]{40}$') {
  throw "Could not resolve the exact client Git revision."
}
$clientRevision = $clientRevision.ToLowerInvariant()

$parityArguments = @{
  CandidateVersion = [string]$inputData.release.version
}
if (-not [string]::IsNullOrWhiteSpace($CoreRoot)) {
  $parityArguments.CoreRoot = $CoreRoot
}
& (Join-Path $root "scripts\check-client-version-parity.ps1") @parityArguments
if (-not $?) {
  throw "Client/Core parity validation failed."
}

$runtimeArtifacts = Read-JsonFile (Join-Path $root "config\runtime-artifacts.seed.json")
$core = $runtimeArtifacts.core
Assert-ExactProperties -Value $inputData.sources `
  -Required @("platform", "core", "release_index") -Path "candidate input.sources"
foreach ($sourceName in @("platform", "core", "release_index")) {
  Assert-ExactProperties -Value $inputData.sources.$sourceName `
    -Required @("repository", "revision") -Path "candidate input.sources.$sourceName"
}
if ([string]$inputData.sources.core.repository -ne "Kiwunaka/pokrov-core" -or
    ([string]$inputData.sources.core.revision).ToLowerInvariant() -ne
      ([string]$core.source_commit).ToLowerInvariant()) {
  throw "Candidate Core source must match the pinned client runtime contract."
}

Assert-ExactProperties -Value $inputData.compatibility `
  -Required @("app_contract_version", "api_contract_version", "contracts") `
  -Path "candidate input.compatibility"
$contracts = @()
$derivedContractIds = @("error-catalog", "observability-event")
foreach ($contract in @($inputData.compatibility.contracts)) {
  if ($derivedContractIds -contains [string]$contract.id) {
    throw "Candidate input cannot supply platform-derived observability contracts."
  }
  $contracts += Copy-OrderedObject -Value $contract `
    -Required @("id", "version", "sha256") -Path "candidate input.compatibility.contracts"
}
$eventSchemaPath = Join-Path $platformFullPath "shared\contracts\observability\observability-event.schema.json"
$errorCatalogPath = Join-Path $platformFullPath "shared\contracts\observability\error-catalog.json"
$eventSchema = Read-JsonFile $eventSchemaPath
$errorCatalog = Read-JsonFile $errorCatalogPath
Assert-ExactProperties -Value $eventSchema.'x-pokrov-contract' `
  -Required @("id", "version") -Path "platform observability event descriptor"
if ([string]$eventSchema.'x-pokrov-contract'.id -ne "observability-event" -or
    [string]$eventSchema.'x-pokrov-contract'.version -ne "1.0.0" -or
    [int]$errorCatalog.schema_version -ne 1 -or
    [string]$errorCatalog.catalog_version -ne "1.2.0") {
  throw "Platform observability contract identity is unsupported."
}
$contracts += [pscustomobject][ordered]@{
  id = "error-catalog"
  version = [string]$errorCatalog.catalog_version
  sha256 = (Get-FileHash -LiteralPath $errorCatalogPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$contracts += [pscustomobject][ordered]@{
  id = "observability-event"
  version = [string]$eventSchema.'x-pokrov-contract'.version
  sha256 = (Get-FileHash -LiteralPath $eventSchemaPath -Algorithm SHA256).Hash.ToLowerInvariant()
}
$contracts = @($contracts | Sort-Object id, version)

$release = [pscustomobject][ordered]@{
  version = [string]$inputData.release.version
  channel = [string]$inputData.release.channel
  candidate_label = [string]$inputData.release.candidate_label
  created_at_utc = $inputData.release.created_at_utc
  release_notes = Copy-OrderedObject -Value $inputData.release.release_notes `
    -Required @("summary", "url") -Path "candidate input.release.release_notes"
}
$sources = [ordered]@{
  platform = Copy-OrderedObject -Value $inputData.sources.platform `
    -Required @("repository", "revision") -Path "candidate input.sources.platform"
  client = [pscustomobject][ordered]@{
    repository = "Kiwunaka/POKROV-app"
    revision = $clientRevision
  }
  core = [pscustomobject][ordered]@{
    repository = "Kiwunaka/pokrov-core"
    revision = ([string]$core.source_commit).ToLowerInvariant()
  }
  release_index = Copy-OrderedObject -Value $inputData.sources.release_index `
    -Required @("repository", "revision") -Path "candidate input.sources.release_index"
}
$compatibility = [ordered]@{
  core_version = [string]$core.version
  core_abi = [pscustomobject][ordered]@{
    desktop = [int]$core.desktop_abi.version
    android_package = [string]$core.android_package
  }
  app_contract_version = [string]$inputData.compatibility.app_contract_version
  api_contract_version = [string]$inputData.compatibility.api_contract_version
  contracts = $contracts
}

$artifacts = @()
$descriptors = @()
foreach ($artifactInput in @($inputData.artifacts)) {
  Assert-ExactProperties -Value $artifactInput `
    -Required @(
      "platform", "kind", "architecture", "file_name", "public_url",
      "sha256", "size_bytes", "signing", "sbom", "provenance"
    ) `
    -Path "candidate input.artifacts"
  $platform = [string]$artifactInput.platform
  if ($platform -eq "android") {
    $coreAsset = $core.assets.android
    $artifactCoreAbi = $null
  } elseif ($platform -eq "windows") {
    $coreAsset = $core.assets.windows
    $artifactCoreAbi = [int]$core.desktop_abi.version
  } else {
    throw "WO-003 supports only Android and Windows client artifacts."
  }

  $artifact = [pscustomobject][ordered]@{
    platform = $platform
    kind = [string]$artifactInput.kind
    architecture = [string]$artifactInput.architecture
    file_name = [string]$artifactInput.file_name
    public_url = [string]$artifactInput.public_url
    sha256 = ([string]$artifactInput.sha256).ToLowerInvariant()
    size_bytes = [int64]$artifactInput.size_bytes
    source_revision = $clientRevision
    core_version = [string]$core.version
    core_abi = $artifactCoreAbi
    core_artifact_sha256 = ([string]$coreAsset.sha256).ToLowerInvariant()
    signing = New-SigningEvidence -Value $artifactInput.signing -Path "candidate input.artifacts.signing"
    sbom = New-SupplyEvidence -Value $artifactInput.sbom -Path "candidate input.artifacts.sbom"
    provenance = New-SupplyEvidence -Value $artifactInput.provenance -Path "candidate input.artifacts.provenance"
  }
  $artifacts += $artifact
  $descriptors += [pscustomobject][ordered]@{
    architecture = $artifact.architecture
    core_abi = $artifact.core_abi
    core_artifact_sha256 = $artifact.core_artifact_sha256
    file_name = $artifact.file_name
    kind = $artifact.kind
    platform = $artifact.platform
    sha256 = $artifact.sha256
    size_bytes = $artifact.size_bytes
  }
}
$artifacts = @($artifacts | Sort-Object platform, kind, architecture)
$descriptors = @($descriptors | Sort-Object platform, kind, architecture)
$descriptorJson = ConvertTo-Json -InputObject $descriptors -Depth 10 -Compress
$artifactSetSha256 = Get-Sha256Text $descriptorJson

$manualGates = @()
foreach ($gateInput in @($inputData.manual_gates)) {
  $manualGates += Copy-OrderedObject -Value $gateInput `
    -Required @("id", "origin", "status", "required_for_promotion") `
    -Optional @("observed_at_utc", "evidence_sha256") `
    -Path "candidate input.manual_gates"
}
$manualGates = @($manualGates | Sort-Object origin, id)

$promotionInput = $inputData.promotion
$promotion = Copy-OrderedObject -Value $promotionInput `
  -Required @("target_channel", "same_byte_required", "observed_status") `
  -Optional @("observed_at_utc", "evidence_sha256") `
  -Path "candidate input.promotion"
if ($promotion.target_channel -ne $release.channel) {
  throw "Release channel and promotion target channel must match."
}
$promotionOutput = [ordered]@{
  target_channel = [string]$promotion.target_channel
  same_byte_required = [bool]$promotion.same_byte_required
  source_artifact_set_sha256 = $artifactSetSha256
  observed_status = [string]$promotion.observed_status
}
foreach ($optionalName in @("observed_at_utc", "evidence_sha256")) {
  if (@($promotion.PSObject.Properties.Name) -contains $optionalName) {
    $promotionOutput[$optionalName] = $promotion.$optionalName
  }
}

$handoff = [pscustomobject][ordered]@{
  schema_version = 2
  release = $release
  sources = [pscustomobject]$sources
  compatibility = [pscustomobject]$compatibility
  artifacts = $artifacts
  manual_gates = $manualGates
  promotion = [pscustomobject]$promotionOutput
}
$json = ConvertTo-Json -InputObject $handoff -Depth 20
$json = ($json -replace "`r`n", "`n").TrimEnd() + "`n"
$temporaryPath = Join-Path $outputDirectory (".release-handoff-v2.{0}.tmp" -f [guid]::NewGuid().ToString("N"))
$validator = Join-Path $platformFullPath "scripts\validate_release_handoff_metadata.py"
if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
  throw "Platform release-handoff validator is missing."
}

try {
  [IO.File]::WriteAllText($temporaryPath, $json, $utf8NoBom)
  & python.exe -B $validator --metadata-file $temporaryPath
  if ($LASTEXITCODE -ne 0) {
    throw "Platform release-handoff validator rejected generated metadata."
  }
  Move-Item -LiteralPath $temporaryPath -Destination $outputFullPath
} finally {
  if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
    Remove-Item -LiteralPath $temporaryPath -Force
  }
}

Write-Host "Release-handoff v2 generated and validated: $outputFullPath" -ForegroundColor Green
