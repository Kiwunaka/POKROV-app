[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root "scripts\set-release-stable-pointer.ps1"
$catalogPath = Join-Path $root "config\release-rollback-catalog.seed.json"
$releaseSeedPath = Join-Path $root "config\release-handoff.seed.json"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) `
  ("pokrov-release-pointer-{0}" -f [guid]::NewGuid().ToString("N"))
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Invoke-PointerScript {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)

  $powerShell = Join-Path $PSHOME "powershell.exe"
  if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) {
    $powerShell = (Get-Process -Id $PID).Path
  }
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $lines = @(& $powerShell -NoProfile -ExecutionPolicy Bypass -File $script @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  return [pscustomobject]@{
    ExitCode = $exitCode
    Output = ($lines | Out-String).Trim()
  }
}

function Assert-Success {
  param([Parameter(Mandatory = $true)]$Result, [Parameter(Mandatory = $true)][string]$Case)

  if ($Result.ExitCode -ne 0) {
    throw "$Case failed unexpectedly: $($Result.Output)"
  }
}

function Assert-Failure {
  param([Parameter(Mandatory = $true)]$Result, [Parameter(Mandatory = $true)][string]$Case)

  if ($Result.ExitCode -eq 0) {
    throw "$Case succeeded unexpectedly."
  }
}

function Write-Json {
  param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)

  $json = ConvertTo-Json -InputObject $Value -Depth 20
  $json = ($json -replace "`r`n", "`n").TrimEnd() + "`n"
  [IO.File]::WriteAllText($Path, $json, $utf8NoBom)
}

$actualValidation = Invoke-PointerScript -Arguments @(
  "-CatalogPath", $catalogPath,
  "-ValidateOnly"
)
Assert-Success -Result $actualValidation -Case "retained stable catalog validation"
$actualSummary = $actualValidation.Output | ConvertFrom-Json
$releaseSeed = [IO.File]::ReadAllText($releaseSeedPath) | ConvertFrom-Json
if ($actualSummary.stable_release_id -ne "1.1.6+20260819" -or
    $actualSummary.stable_release_version -ne $releaseSeed.latest_repo_backed_release.version -or
    [int]$actualSummary.rollback_target_count -lt 1 -or
    $releaseSeed.release_truth.rollback_catalog -ne "config/release-rollback-catalog.seed.json") {
  throw "Retained stable pointer, rollback catalog, and release-handoff seed disagree."
}

New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
  $configRoot = Join-Path $temporaryRoot "config"
  $artifactRoot = Join-Path $temporaryRoot "artifacts\releases"
  $versionARoot = Join-Path $artifactRoot "pokrov-app\stable-a"
  $versionBRoot = Join-Path $artifactRoot "pokrov-app\candidate-b"
  $evidenceRoot = Join-Path $temporaryRoot "evidence"
  foreach ($directory in @($configRoot, $versionARoot, $versionBRoot, $evidenceRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $handoffA = [pscustomobject][ordered]@{
    schema_version = 1
    release_id = "stable-a"
    release_version = "1.1.6"
  }
  $handoffB = [pscustomobject][ordered]@{
    schema_version = 1
    release_id = "candidate-b"
    release_version = "1.2.0"
  }
  $pathA = Join-Path $versionARoot "release-handoff.json"
  $pathB = Join-Path $versionBRoot "release-handoff.json"
  $pointerPath = Join-Path $artifactRoot "release-handoff.json"
  Write-Json -Path $pathA -Value $handoffA
  Write-Json -Path $pathB -Value $handoffB
  [IO.File]::Copy($pathA, $pointerPath)
  $hashA = (Get-FileHash -LiteralPath $pathA -Algorithm SHA256).Hash.ToLowerInvariant()
  $hashB = (Get-FileHash -LiteralPath $pathB -Algorithm SHA256).Hash.ToLowerInvariant()
  $syntheticCatalog = [pscustomobject][ordered]@{
    schema_version = 1
    channel = "stable"
    artifact_root = "../artifacts/releases"
    stable_pointer = [pscustomobject][ordered]@{ path = "release-handoff.json" }
    rollback_targets = @(
      [pscustomobject][ordered]@{
        release_id = "stable-a"
        release_version = "1.1.6"
        handoff_schema_version = 1
        handoff_path = "pokrov-app/stable-a/release-handoff.json"
        handoff_sha256 = $hashA
        eligibility = "ROLLBACK_ELIGIBLE"
        platforms = @("android", "windows")
      },
      [pscustomobject][ordered]@{
        release_id = "candidate-b"
        release_version = "1.2.0"
        handoff_schema_version = 1
        handoff_path = "pokrov-app/candidate-b/release-handoff.json"
        handoff_sha256 = $hashB
        eligibility = "ROLLBACK_ELIGIBLE"
        platforms = @("android", "windows")
      }
    )
    mutation_policy = [pscustomobject][ordered]@{
      atomic_replace_required = $true
      optimistic_lock_required = $true
      backup_required = $true
      same_byte_target_required = $true
      exact_candidate_gate_required = $true
    }
  }
  $syntheticCatalogPath = Join-Path $configRoot "release-rollback-catalog.seed.json"
  Write-Json -Path $syntheticCatalogPath -Value $syntheticCatalog

  $dryRun = Invoke-PointerScript -Arguments @(
    "-CatalogPath", $syntheticCatalogPath,
    "-ExpectedCurrentReleaseId", "stable-a",
    "-TargetReleaseId", "candidate-b"
  )
  Assert-Success -Result $dryRun -Case "pointer dry run"
  if ((Get-FileHash -LiteralPath $pointerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashA) {
    throw "Dry run changed the stable pointer."
  }

  $badLock = Invoke-PointerScript -Arguments @(
    "-CatalogPath", $syntheticCatalogPath,
    "-ExpectedCurrentReleaseId", "wrong-current",
    "-TargetReleaseId", "candidate-b",
    "-BackupPath", (Join-Path $evidenceRoot "bad-lock-backup.json"),
    "-ReceiptPath", (Join-Path $evidenceRoot "bad-lock-receipt.json"),
    "-Apply"
  )
  Assert-Failure -Result $badLock -Case "optimistic-lock mismatch"
  if ((Get-FileHash -LiteralPath $pointerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashA) {
    throw "Failed optimistic lock changed the stable pointer."
  }

  $forwardBackup = Join-Path $evidenceRoot "forward-backup.json"
  $forwardReceipt = Join-Path $evidenceRoot "forward-receipt.json"
  $forward = Invoke-PointerScript -Arguments @(
    "-CatalogPath", $syntheticCatalogPath,
    "-ExpectedCurrentReleaseId", "stable-a",
    "-TargetReleaseId", "candidate-b",
    "-BackupPath", $forwardBackup,
    "-ReceiptPath", $forwardReceipt,
    "-Apply"
  )
  Assert-Success -Result $forward -Case "atomic forward switch"
  if ((Get-FileHash -LiteralPath $pointerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashB -or
      (Get-FileHash -LiteralPath $forwardBackup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashA -or
      -not (Test-Path -LiteralPath $forwardReceipt -PathType Leaf)) {
    throw "Forward switch did not retain exact pointer and rollback evidence bytes."
  }

  $reverseBackup = Join-Path $evidenceRoot "reverse-backup.json"
  $reverseReceipt = Join-Path $evidenceRoot "reverse-receipt.json"
  $reverse = Invoke-PointerScript -Arguments @(
    "-CatalogPath", $syntheticCatalogPath,
    "-ExpectedCurrentReleaseId", "candidate-b",
    "-TargetReleaseId", "stable-a",
    "-BackupPath", $reverseBackup,
    "-ReceiptPath", $reverseReceipt,
    "-Apply"
  )
  Assert-Success -Result $reverse -Case "atomic rollback switch"
  if ((Get-FileHash -LiteralPath $pointerPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashA -or
      (Get-FileHash -LiteralPath $reverseBackup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hashB -or
      -not (Test-Path -LiteralPath $reverseReceipt -PathType Leaf)) {
    throw "Rollback did not restore the original stable pointer byte-for-byte."
  }

  $tamperedCatalog = [IO.File]::ReadAllText($syntheticCatalogPath) | ConvertFrom-Json
  $tamperedCatalog.rollback_targets[0].handoff_sha256 = "0" * 64
  $tamperedCatalogPath = Join-Path $configRoot "tampered-catalog.json"
  Write-Json -Path $tamperedCatalogPath -Value $tamperedCatalog
  $tampered = Invoke-PointerScript -Arguments @(
    "-CatalogPath", $tamperedCatalogPath,
    "-ValidateOnly"
  )
  Assert-Failure -Result $tampered -Case "tampered rollback target"

  Write-Host "Release rollback catalog contract OK: retained pointer plus 5 synthetic cases." -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temporaryRoot -PathType Container) {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
