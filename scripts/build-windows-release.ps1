param(
  [switch]$SyncRuntime,
  [switch]$SkipValidateSeed,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$SkipBuild,
  [switch]$SkipZip
)

$ErrorActionPreference = "Stop"

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

$root = Split-Path -Parent $PSScriptRoot
$windowsReleaseConfigPath = Join-Path $root "config\\windows-release.seed.json"
$runtimeArtifactsConfigPath = Join-Path $root "config\\runtime-artifacts.seed.json"
$windowsReleaseConfig = Get-Content -Raw -LiteralPath $windowsReleaseConfigPath | ConvertFrom-Json
$runtimeArtifactsConfig = Get-Content -Raw -LiteralPath $runtimeArtifactsConfigPath | ConvertFrom-Json

$appDirectory = Join-Path $root "apps\\windows_shell"
$pubspecPath = Join-Path $appDirectory "pubspec.yaml"
$version = Resolve-VersionFromPubspec -PubspecPath $pubspecPath

$runtimeDirectory = Join-Path $root $windowsReleaseConfig.runtime.artifact_directory
$runtimeRequiredFiles = @(
  $windowsReleaseConfig.runtime.core_binary
)
if ($windowsReleaseConfig.runtime.PSObject.Properties.Name -contains "helper_binary") {
  $runtimeRequiredFiles += $windowsReleaseConfig.runtime.helper_binary
}

if (-not $SkipValidateSeed) {
  & (Join-Path $PSScriptRoot "validate-seed.ps1")
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

if ($SyncRuntime -or (Test-RequiredFiles -BasePath $runtimeDirectory -RelativePaths $runtimeRequiredFiles).Count -gt 0) {
  & (Join-Path $PSScriptRoot "fetch-libcore-assets.ps1") -Platforms @("windows") -SyncToHosts
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

if (-not $SkipTests) {
  & (Join-Path $PSScriptRoot "run-tests.ps1")
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} else {
  Invoke-External -FilePath "flutter" -Arguments @("pub", "get") -WorkingDirectory $appDirectory
}

if (-not $SkipAnalyze) {
  Invoke-External -FilePath "flutter" -Arguments @("analyze") -WorkingDirectory $appDirectory
}

if (-not $SkipBuild) {
  $windowsBuildDirectory = Join-Path $appDirectory "build\\windows"
  if (Test-Path -LiteralPath $windowsBuildDirectory) {
    Remove-Item -Recurse -Force -LiteralPath $windowsBuildDirectory
  }
  Invoke-External -FilePath "flutter" -Arguments @("build", "windows", "--release") -WorkingDirectory $appDirectory
}

$releaseOutputDirectory = Join-Path $root $windowsReleaseConfig.bundle_root
$missingBuildFiles = Test-RequiredFiles -BasePath $releaseOutputDirectory -RelativePaths $windowsReleaseConfig.required_files
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
$manifestName = $windowsReleaseConfig.manifest_name_template.Replace("{version}", $version)
$stagedBundleDirectory = Join-Path $artifactRoot $bundleFolderName
$zipPath = Join-Path $artifactRoot $zipName
$manifestPath = Join-Path $artifactRoot $manifestName

New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null

if (Test-Path -LiteralPath $stagedBundleDirectory) {
  Remove-Item -Recurse -Force -LiteralPath $stagedBundleDirectory
}

New-Item -ItemType Directory -Force -Path $stagedBundleDirectory | Out-Null
Copy-Item -Recurse -Force -Path (Join-Path $releaseOutputDirectory "*") -Destination $stagedBundleDirectory

if (-not $SkipZip) {
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -Force -LiteralPath $zipPath
  }
  Compress-Archive -Path (Join-Path $stagedBundleDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal
}

$manifest = [ordered]@{
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  display_name = $windowsReleaseConfig.display_name
  version = $version
  runtime_release_tag = $runtimeArtifactsConfig.libcore.release_tag
  release_output_directory = $releaseOutputDirectory
  staged_bundle_directory = $stagedBundleDirectory
  zip_path = if ($SkipZip) { $null } else { $zipPath }
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
Write-Host "Manifest: $manifestPath"
