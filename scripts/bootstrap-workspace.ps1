param(
  [switch]$OfflinePubGet
)

$root = Split-Path -Parent $PSScriptRoot
$androidShellPath = Join-Path $root "apps\android_shell"
$androidWrapperRelativePaths = @(
  "android\gradlew",
  "android\gradlew.bat",
  "android\gradle\wrapper\gradle-wrapper.jar"
)
$androidWrapperFiles = @($androidWrapperRelativePaths | ForEach-Object { Join-Path $androidShellPath $_ })
$missingAndroidWrapperFiles = @(
  $androidWrapperFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) }
)

function Test-AndroidWrapperRepairPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$TempRoot
  )

  $trimCharacters = [char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $resolvedTempRoot = [IO.Path]::GetFullPath($TempRoot).TrimEnd($trimCharacters)
  $resolvedPath = [IO.Path]::GetFullPath($Path).TrimEnd($trimCharacters)
  $tempPrefix = $resolvedTempRoot + [IO.Path]::DirectorySeparatorChar
  $leafName = [IO.Path]::GetFileName($resolvedPath)

  return $resolvedPath.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    $leafName -match '^pokrov-android-wrapper-[0-9a-f]{32}$'
}

if ($missingAndroidWrapperFiles.Count -gt 0) {
  Write-Host "Repairing missing Flutter Android Gradle wrapper files." -ForegroundColor Cyan
  $androidWrapperRepairTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  $androidWrapperRepairPath = Join-Path $androidWrapperRepairTempRoot ("pokrov-android-wrapper-" + [Guid]::NewGuid().ToString("N"))
  if (-not (Test-AndroidWrapperRepairPath -Path $androidWrapperRepairPath -TempRoot $androidWrapperRepairTempRoot)) {
    Write-Error "Refusing unsafe Flutter Android wrapper repair temp path: $androidWrapperRepairPath"
    exit 1
  }

  $androidWrapperRepairExitCode = 1
  $androidWrapperRepairFailure = $null
  try {
    New-Item -ItemType Directory -Path $androidWrapperRepairPath -ErrorAction Stop | Out-Null
    $androidWrapperRepairLocationPushed = $false
    try {
      Push-Location -LiteralPath $androidWrapperRepairPath -ErrorAction Stop
      $androidWrapperRepairLocationPushed = $true
      flutter create --platforms=android --no-pub --no-overwrite --org space.pokrov --project-name pokrov_android_shell .
      $androidWrapperRepairExitCode = $LASTEXITCODE
    } finally {
      if ($androidWrapperRepairLocationPushed) {
        Pop-Location -ErrorAction Stop
      }
    }

    if ($androidWrapperRepairExitCode -eq 0) {
      foreach ($androidWrapperRelativePath in $androidWrapperRelativePaths) {
        $sourceAndroidWrapperFile = Join-Path $androidWrapperRepairPath $androidWrapperRelativePath
        if (-not (Test-Path -LiteralPath $sourceAndroidWrapperFile -PathType Leaf)) {
          $androidWrapperRepairFailure = "Flutter Android wrapper repair did not generate required file: $sourceAndroidWrapperFile"
          break
        }
      }

      if ($null -eq $androidWrapperRepairFailure) {
        foreach ($androidWrapperRelativePath in $androidWrapperRelativePaths) {
          $sourceAndroidWrapperFile = Join-Path $androidWrapperRepairPath $androidWrapperRelativePath
          $destinationAndroidWrapperFile = Join-Path $androidShellPath $androidWrapperRelativePath
          if (-not (Test-Path -LiteralPath $destinationAndroidWrapperFile -PathType Leaf)) {
            Copy-Item -LiteralPath $sourceAndroidWrapperFile -Destination $destinationAndroidWrapperFile -ErrorAction Stop
          }
        }
      }
    }
  } catch {
    $androidWrapperRepairFailure = "Flutter Android wrapper repair failed: $($_.Exception.Message)"
  } finally {
    if (Test-Path -LiteralPath $androidWrapperRepairPath) {
      if (-not (Test-AndroidWrapperRepairPath -Path $androidWrapperRepairPath -TempRoot $androidWrapperRepairTempRoot)) {
        throw "Refusing unsafe Flutter Android wrapper repair cleanup path: $androidWrapperRepairPath"
      }
      Remove-Item -LiteralPath $androidWrapperRepairPath -Recurse -Force -ErrorAction Stop
      if (Test-Path -LiteralPath $androidWrapperRepairPath) {
        throw "Flutter Android wrapper repair temp cleanup left a directory: $androidWrapperRepairPath"
      }
    }
  }

  if ($androidWrapperRepairExitCode -ne 0) {
    Write-Error "Flutter Android wrapper repair failed with exit code $androidWrapperRepairExitCode."
    exit $androidWrapperRepairExitCode
  }
  if ($null -ne $androidWrapperRepairFailure) {
    Write-Error $androidWrapperRepairFailure
    exit 1
  }

  foreach ($androidWrapperFile in $androidWrapperFiles) {
    if (-not (Test-Path -LiteralPath $androidWrapperFile -PathType Leaf)) {
      Write-Error "Flutter Android wrapper repair did not materialize required file: $androidWrapperFile"
      exit 1
    }
  }
}

if (-not $IsWindows) {
  $unixGradleWrapper = Join-Path $androidShellPath "android\gradlew"
  & chmod +x $unixGradleWrapper
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to mark Android Gradle wrapper executable: $unixGradleWrapper"
    exit $LASTEXITCODE
  }
}

$workspacePackages = @(
  "packages\\core_domain",
  "packages\\platform_contracts",
  "packages\\observability_contracts",
  "packages\\observability_runtime",
  "packages\\diagnostics_collectors",
  "packages\\support_bundle",
  "packages\\support_context",
  "packages\\runtime_engine",
  "packages\\app_shell",
  "apps\\android_shell",
  "apps\\ios_shell",
  "apps\\linux_shell",
  "apps\\macos_shell",
  "apps\\windows_shell"
)

foreach ($relativePath in $workspacePackages) {
  $fullPath = Join-Path $root $relativePath
  Write-Host "Running flutter pub get in $relativePath" -ForegroundColor Cyan
  Push-Location $fullPath
  try {
    $pubGetArgs = @("pub", "get")
    if ($OfflinePubGet) {
      $pubGetArgs += "--offline"
    }
    flutter @pubGetArgs
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

Write-Host "Workspace bootstrap complete." -ForegroundColor Green
