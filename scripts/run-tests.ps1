param(
  [switch]$OfflinePubGet
)

$root = Split-Path -Parent $PSScriptRoot

$bootstrapArgs = @()
if ($OfflinePubGet) {
  $bootstrapArgs += "-OfflinePubGet"
}
& (Join-Path $PSScriptRoot "bootstrap-workspace.ps1") @bootstrapArgs
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

function Invoke-WorkspaceFlutterTests {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  Write-Host "Running flutter test in $RelativePath" -ForegroundColor Cyan
  Push-Location (Join-Path $root $RelativePath)
  try {
    flutter test
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

function Invoke-AndroidGradleUnitTests {
  $androidProjectPath = Join-Path $root "apps\android_shell\android"
  $gradleWrapper = Join-Path $androidProjectPath "gradlew.bat"

  if (-not (Test-Path $gradleWrapper)) {
    Write-Error "Android Gradle wrapper not found at $gradleWrapper"
    exit 1
  }

  Write-Host "Running Android Gradle unit tests in apps\android_shell" -ForegroundColor Cyan
  Push-Location $androidProjectPath
  try {
    # Scope the workspace gate to POKROV's app module. The unqualified task
    # also runs unit tests shipped by Flutter plugins (for example
    # video_player_android) and can fail inside their own Jetifier/test
    # classpath without compiling or exercising any POKROV source.
    & $gradleWrapper :app:testDebugUnitTest
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

$flutterTestPackages = @(
  "packages\\app_shell",
  "packages\\runtime_engine",
  "apps\\android_shell",
  "apps\\windows_shell"
)

foreach ($relativePath in $flutterTestPackages) {
  Invoke-WorkspaceFlutterTests -RelativePath $relativePath
}

Invoke-AndroidGradleUnitTests

Write-Host "Workspace Flutter and Android unit tests passed." -ForegroundColor Green
