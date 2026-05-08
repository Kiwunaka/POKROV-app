param(
  [switch]$OfflinePubGet
)

$root = Split-Path -Parent $PSScriptRoot

$workspacePackages = @(
  "packages\\core_domain",
  "packages\\platform_contracts",
  "packages\\support_context",
  "packages\\runtime_engine",
  "packages\\app_shell",
  "apps\\android_shell",
  "apps\\ios_shell",
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
