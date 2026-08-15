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
  [string]$EmergencySigningPublicKey = $env:POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64
)

$ErrorActionPreference = "Stop"

$EmergencySigningKeyId = [string]$EmergencySigningKeyId
$EmergencySigningPublicKey = [string]$EmergencySigningPublicKey
if ($EmergencySigningKeyId -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$') {
  throw "A canonical POKROV emergency signing key id is required for a production build."
}
if ($EmergencySigningPublicKey -notmatch '^[A-Za-z0-9_-]{43}$') {
  throw "A 32-byte base64url POKROV emergency signing public key is required for a production build."
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
if ($windowsReleaseConfig.runtime.PSObject.Properties.Name -contains "runtime_dependencies") {
  $runtimeRequiredFiles += @($windowsReleaseConfig.runtime.runtime_dependencies)
}

if (-not $SkipValidateSeed) {
  & (Join-Path $PSScriptRoot "validate-seed.ps1")
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
}

if ($SyncRuntime -or (Test-RequiredFiles -BasePath $runtimeDirectory -RelativePaths $runtimeRequiredFiles).Count -gt 0) {
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

if (-not $SkipTests) {
  $runTestsArgs = @()
  if ($OfflinePubGet) {
    $runTestsArgs += "-OfflinePubGet"
  }
  & (Join-Path $PSScriptRoot "run-tests.ps1") @runTestsArgs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} else {
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
  $windowsBuildDirectory = Join-Path $appDirectory "build\\windows"
  if (Test-Path -LiteralPath $windowsBuildDirectory) {
    Remove-Item -Recurse -Force -LiteralPath $windowsBuildDirectory
  }
  Invoke-External -FilePath "flutter" -Arguments @(
    "build",
    "windows",
    "--release",
    "--dart-define=POKROV_APP_VERSION=$version",
    "--dart-define=POKROV_EMERGENCY_SIGNING_KEY_ID=$EmergencySigningKeyId",
    "--dart-define=POKROV_EMERGENCY_SIGNING_PUBLIC_KEY_B64=$EmergencySigningPublicKey"
  ) -WorkingDirectory $appDirectory
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

if (-not $SkipZip) {
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -Force -LiteralPath $zipPath
  }
  Compress-Archive -Path (Join-Path $stagedBundleDirectory "*") -DestinationPath $zipPath -CompressionLevel Optimal
}

$installerSha256 = $null
if (-not $SkipInstaller) {
  if ($SkipZip) {
    throw "Windows installer packaging requires the versioned zip. Remove -SkipZip or pass -SkipInstaller."
  }
  $iexpress = Get-Command "iexpress.exe" -ErrorAction SilentlyContinue
  if (-not $iexpress) {
    throw "iexpress.exe is required to build the unsigned Windows direct-download installer EXE"
  }

  $installerPayloadDirectory = Join-Path $artifactRoot ("installer_payload_" + ($version -replace '[^A-Za-z0-9_.-]', '_'))
  if (Test-Path -LiteralPath $installerPayloadDirectory) {
    Remove-Item -Recurse -Force -LiteralPath $installerPayloadDirectory
  }
  New-Item -ItemType Directory -Force -Path $installerPayloadDirectory | Out-Null

  $zipLeaf = Split-Path -Leaf $zipPath
  Copy-Item -Force -LiteralPath $zipPath -Destination (Join-Path $installerPayloadDirectory $zipLeaf)

  $installPs1Path = Join-Path $installerPayloadDirectory "install-pokrov.ps1"
  $installCmdPath = Join-Path $installerPayloadDirectory "install-pokrov.cmd"
  $installPs1 = @"
`$ErrorActionPreference = "Stop"
`$sourceDir = Split-Path -Parent `$MyInvocation.MyCommand.Path
`$zipPath = Join-Path `$sourceDir "$zipLeaf"
`$target = Join-Path `$env:LOCALAPPDATA "Programs\\POKROV"
`$temp = Join-Path `$env:TEMP ("pokrov-install-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path `$temp | Out-Null
try {
  Expand-Archive -Path `$zipPath -DestinationPath `$temp -Force
  if (Test-Path -LiteralPath `$target) {
    Remove-Item -Recurse -Force -LiteralPath `$target
  }
  New-Item -ItemType Directory -Force -Path `$target | Out-Null
  Copy-Item -Recurse -Force -Path (Join-Path `$temp "*") -Destination `$target
  `$exe = Join-Path `$target "$($windowsReleaseConfig.binary_name)"
  `$shell = New-Object -ComObject WScript.Shell
  `$programs = [Environment]::GetFolderPath("Programs")
  `$shortcut = `$shell.CreateShortcut((Join-Path `$programs "POKROV.lnk"))
  `$shortcut.TargetPath = `$exe
  `$shortcut.WorkingDirectory = `$target
  `$shortcut.Save()
  `$protocolRoot = "HKCU:\Software\Classes\pokrov"
  New-Item -Path `$protocolRoot -Force | Out-Null
  Set-Item -LiteralPath `$protocolRoot -Value "URL:POKROV acquisition continuation"
  New-ItemProperty -LiteralPath `$protocolRoot -Name "URL Protocol" -Value "" -PropertyType String -Force | Out-Null
  `$iconKey = Join-Path `$protocolRoot "DefaultIcon"
  New-Item -Path `$iconKey -Force | Out-Null
  Set-Item -LiteralPath `$iconKey -Value ('"' + `$exe + '",0')
  `$commandKey = Join-Path `$protocolRoot "shell\open\command"
  New-Item -Path `$commandKey -Force | Out-Null
  Set-Item -LiteralPath `$commandKey -Value ('"' + `$exe + '" "%1"')
  Start-Process -FilePath `$exe -WorkingDirectory `$target
} finally {
  if (Test-Path -LiteralPath `$temp) {
    Remove-Item -Recurse -Force -LiteralPath `$temp
  }
}
"@
  $installCmd = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-pokrov.ps1"
exit /b %ERRORLEVEL%
"@
  Write-Utf8File -Path $installPs1Path -Content $installPs1
  Write-Utf8File -Path $installCmdPath -Content $installCmd

  $sedPath = Join-Path $artifactRoot ($installerName + ".sed")
  $sed = @"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=1
HideExtractAnimation=0
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=POKROV installed.
TargetName=$installerPath
FriendlyName=POKROV Windows installer
AppLaunched=install-pokrov.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=install-pokrov.cmd
UserQuietInstCmd=install-pokrov.cmd
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$installerPayloadDirectory
[SourceFiles0]
install-pokrov.cmd=
install-pokrov.ps1=
$zipLeaf=
"@
  Write-Utf8File -Path $sedPath -Content $sed
  if (Test-Path -LiteralPath $installerPath) {
    Remove-Item -Force -LiteralPath $installerPath
  }
  $iexpressProcess = Start-Process -FilePath $iexpress.Source -ArgumentList @("/N", "/Q", $sedPath) -NoNewWindow -Wait -PassThru
  if ($iexpressProcess.ExitCode -ne 0) {
    throw "iexpress.exe failed with exit code $($iexpressProcess.ExitCode)"
  }
  $installerReady = $false
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    if (Test-Path -LiteralPath $installerPath) {
      $installerReady = $true
      break
    }
    Start-Sleep -Seconds 1
  }
  if (-not $installerReady) {
    throw "iexpress.exe did not produce installer: $installerPath"
  }
  $installerSha256 = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
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
