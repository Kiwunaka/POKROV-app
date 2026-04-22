$root = Split-Path -Parent $PSScriptRoot

$expectedFiles = @(
  "melos.yaml",
  "config\\platform-matrix.seed.json",
  "config\\runtime-profile.seed.json",
  "config\\templates\\local.env.example",
  "config\\templates\\device-overrides.seed.json",
  "docs\\architecture\\bootstrap-workflow.md",
  "docs\\architecture\\package-boundaries.md",
  "scripts\\bootstrap-workspace.ps1",
  "scripts\\bootstrap-local.ps1",
  "scripts\\run-tests.ps1",
  "apps\\android_shell\\pubspec.yaml",
  "apps\\android_shell\\lib\\main.dart",
  "apps\\ios_shell\\pubspec.yaml",
  "apps\\ios_shell\\lib\\main.dart",
  "apps\\macos_shell\\pubspec.yaml",
  "apps\\macos_shell\\lib\\main.dart",
  "apps\\windows_shell\\pubspec.yaml",
  "apps\\windows_shell\\lib\\main.dart",
  "packages\\app_shell\\pubspec.yaml",
  "packages\\app_shell\\lib\\app_shell.dart",
  "packages\\app_shell\\test\\pokrov_seed_app_test.dart",
  "packages\\core_domain\\pubspec.yaml",
  "packages\\core_domain\\lib\\core_domain.dart",
  "packages\\platform_contracts\\pubspec.yaml",
  "packages\\platform_contracts\\lib\\platform_contracts.dart",
  "packages\\support_context\\pubspec.yaml",
  "packages\\support_context\\lib\\support_context.dart"
)

$missing = [System.Collections.Generic.List[string]]::new()

foreach ($relativePath in $expectedFiles) {
  $fullPath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    $missing.Add($relativePath)
  }
}

if ($missing.Count -gt 0) {
  Write-Host "Seed layout is incomplete." -ForegroundColor Red
  $missing | ForEach-Object { Write-Host $_ }
  exit 1
}

& (Join-Path $root "scripts\\validate-seed.ps1")
exit $LASTEXITCODE
