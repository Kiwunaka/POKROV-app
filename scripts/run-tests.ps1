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

function Invoke-WorkspaceFlutterGate {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $modulePath = Join-Path $root $RelativePath
  $hasTests = Test-Path -LiteralPath (Join-Path $modulePath "test") -PathType Container
  $flutterCommand = if ($hasTests) { "test" } else { "analyze" }
  Write-Host "Running flutter $flutterCommand in $RelativePath" -ForegroundColor Cyan
  Push-Location $modulePath
  try {
    flutter $flutterCommand
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

function Invoke-AndroidGradleUnitTests {
  $androidProjectPath = Join-Path $root "apps\android_shell\android"
  $gradleWrapperName = if ($IsWindows) { "gradlew.bat" } else { "gradlew" }
  $gradleWrapper = Join-Path $androidProjectPath $gradleWrapperName

  if (-not (Test-Path $gradleWrapper)) {
    Write-Error "Android Gradle wrapper not found at $gradleWrapper"
    exit 1
  }

  if (-not $IsWindows) {
    & chmod +x $gradleWrapper
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to mark Android Gradle wrapper executable: $gradleWrapper"
      exit $LASTEXITCODE
    }
  }

  Write-Host "Running Android Gradle unit tests in apps\android_shell" -ForegroundColor Cyan
  Push-Location $androidProjectPath
  try {
    # Scope the workspace gate to POKROV's app module. The unqualified task
    # also runs unit tests shipped by Flutter plugins (for example
    # video_player_android) and can fail inside their own Jetifier/test
    # classpath without compiling or exercising any POKROV source.
    & $gradleWrapper :app:testDirectDebugUnitTest :app:testStoreDebugUnitTest
    if ($LASTEXITCODE -ne 0) {
      exit $LASTEXITCODE
    }
  } finally {
    Pop-Location
  }
}

$flutterTestPackages = @(
  "packages\\core_domain",
  "packages\\platform_contracts",
  "packages\\observability_contracts",
  "packages\\observability_runtime",
  "packages\\diagnostics_collectors",
  "packages\\support_bundle",
  "packages\\support_context",
  "packages\\app_shell",
  "packages\\runtime_engine",
  "apps\\android_shell",
  "apps\\windows_shell"
)

foreach ($relativePath in $flutterTestPackages) {
  Invoke-WorkspaceFlutterGate -RelativePath $relativePath
}

Invoke-AndroidGradleUnitTests

Write-Host "Workspace Flutter and Android unit tests passed." -ForegroundColor Green
