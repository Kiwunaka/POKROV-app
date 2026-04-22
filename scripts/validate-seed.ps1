$root = Split-Path -Parent $PSScriptRoot

$requiredDirectories = @(
  "apps",
  "apps\\android_shell",
  "apps\\android_shell\\lib",
  "apps\\ios_shell",
  "apps\\ios_shell\\lib",
  "apps\\macos_shell",
  "apps\\macos_shell\\lib",
  "apps\\windows_shell",
  "apps\\windows_shell\\lib",
  "packages",
  "packages\\app_shell",
  "packages\\app_shell\\lib",
  "packages\\app_shell\\test",
  "packages\\core_domain",
  "packages\\core_domain\\lib",
  "packages\\platform_contracts",
  "packages\\platform_contracts\\lib",
  "packages\\runtime_engine",
  "packages\\runtime_engine\\lib",
  "packages\\runtime_engine\\test",
  "packages\\support_context",
  "packages\\support_context\\lib",
  "config",
  "config\\local",
  "config\\templates",
  "docs",
  "docs\\architecture",
  "docs\\decisions",
  "docs\\specs",
  "artifacts",
  "assets\\branding",
  "scripts",
  "test"
)

$requiredFiles = @(
  "README.md",
  ".gitignore",
  ".editorconfig",
  "melos.yaml",
  "program.seed.yaml",
  "config\\product-contract.seed.json",
  "config\\platform-matrix.seed.json",
  "config\\runtime-profile.seed.json",
  "config\\runtime-artifacts.seed.json",
  "config\\windows-release.seed.json",
  "config\\templates\\local.env.example",
  "config\\templates\\device-overrides.seed.json",
  "docs\\README.md",
  "docs\\architecture\\folder-structure.md",
  "docs\\architecture\\package-boundaries.md",
  "docs\\architecture\\bootstrap-workflow.md",
  "docs\\decisions\\2026-04-18-karing-vs-clean-room-gate.md",
  "docs\\operations\\windows-release-readiness.md",
  "docs\\specs\\2026-04-18-wave-7-new-base-client-scaffold.md",
  "apps\\README.md",
  "apps\\android_shell\\README.md",
  "apps\\android_shell\\pubspec.yaml",
  "apps\\android_shell\\lib\\main.dart",
  "apps\\ios_shell\\README.md",
  "apps\\ios_shell\\pubspec.yaml",
  "apps\\ios_shell\\lib\\main.dart",
  "apps\\macos_shell\\README.md",
  "apps\\macos_shell\\pubspec.yaml",
  "apps\\macos_shell\\lib\\main.dart",
  "apps\\windows_shell\\README.md",
  "apps\\windows_shell\\pubspec.yaml",
  "apps\\windows_shell\\lib\\main.dart",
  "packages\\README.md",
  "packages\\app_shell\\README.md",
  "packages\\app_shell\\pubspec.yaml",
  "packages\\app_shell\\lib\\app_shell.dart",
  "packages\\core_domain\\README.md",
  "packages\\core_domain\\pubspec.yaml",
  "packages\\core_domain\\lib\\core_domain.dart",
  "packages\\platform_contracts\\README.md",
  "packages\\platform_contracts\\pubspec.yaml",
  "packages\\platform_contracts\\lib\\platform_contracts.dart",
  "packages\\runtime_engine\\README.md",
  "packages\\runtime_engine\\pubspec.yaml",
  "packages\\runtime_engine\\lib\\runtime_engine.dart",
  "packages\\runtime_engine\\test\\runtime_engine_test.dart",
  "packages\\support_context\\README.md",
  "packages\\support_context\\pubspec.yaml",
  "packages\\support_context\\lib\\support_context.dart",
  "artifacts\\README.md",
  "assets\\branding\\README.md",
  "scripts\\README.md",
  "scripts\\bootstrap-workspace.ps1",
  "scripts\\bootstrap-local.ps1",
  "scripts\\build-windows-release.ps1",
  "scripts\\fetch-libcore-assets.ps1",
  "scripts\\run-tests.ps1",
  "scripts\\validate-seed.ps1",
  "test\\README.md",
  "test\\seed-layout.ps1",
  "packages\\app_shell\\test\\pokrov_seed_app_test.dart"
)

$jsonFiles = @(
  "config\\product-contract.seed.json",
  "config\\platform-matrix.seed.json",
  "config\\runtime-profile.seed.json",
  "config\\runtime-artifacts.seed.json",
  "config\\windows-release.seed.json",
  "config\\templates\\device-overrides.seed.json"
)

$missing = [System.Collections.Generic.List[string]]::new()
$invalidJson = [System.Collections.Generic.List[string]]::new()
$manifestErrors = [System.Collections.Generic.List[string]]::new()
$expectedPublicTargets = @("android", "ios", "macos", "windows")
$expectedHostShells = @{
  android = "apps/android_shell"
  ios = "apps/ios_shell"
  macos = "apps/macos_shell"
  windows = "apps/windows_shell"
}

foreach ($relativePath in $requiredDirectories) {
  $fullPath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) {
    $missing.Add("DIR  $relativePath")
  }
}

foreach ($relativePath in $requiredFiles) {
  $fullPath = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    $missing.Add("FILE $relativePath")
  }
}

foreach ($relativePath in $jsonFiles) {
  $fullPath = Join-Path $root $relativePath
  if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
    try {
      Get-Content -Raw -LiteralPath $fullPath | ConvertFrom-Json | Out-Null
    } catch {
      $invalidJson.Add($relativePath)
    }
  }
}

$platformMatrixPath = Join-Path $root "config\\platform-matrix.seed.json"
if (Test-Path -LiteralPath $platformMatrixPath -PathType Leaf) {
  $platformMatrix = Get-Content -Raw -LiteralPath $platformMatrixPath | ConvertFrom-Json

  foreach ($target in $expectedPublicTargets) {
    if (@($platformMatrix.public_release_targets) -notcontains $target) {
      $manifestErrors.Add("config\\platform-matrix.seed.json must include public target '$target'")
    }
  }

  if (@($platformMatrix.readiness_only_targets).Count -ne 0) {
    $manifestErrors.Add("config\\platform-matrix.seed.json must keep readiness_only_targets empty for the four-target seed")
  }

  foreach ($target in $expectedHostShells.Keys) {
    if ($platformMatrix.host_shells.$target -ne $expectedHostShells[$target]) {
      $manifestErrors.Add("config\\platform-matrix.seed.json must map '$target' to '$($expectedHostShells[$target])'")
    }
  }
}

$productContractPath = Join-Path $root "config\\product-contract.seed.json"
if (Test-Path -LiteralPath $productContractPath -PathType Leaf) {
  $productContract = Get-Content -Raw -LiteralPath $productContractPath | ConvertFrom-Json

  foreach ($target in $expectedPublicTargets) {
    if (@($productContract.public_scope) -notcontains $target) {
      $manifestErrors.Add("config\\product-contract.seed.json must include public scope '$target'")
    }
  }

  if (@($productContract.readiness_only_scope).Count -ne 0) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep readiness_only_scope empty for the four-target seed")
  }

  if (@($productContract.public_routing_modes) -notcontains "selected_apps") {
    $manifestErrors.Add("config\\product-contract.seed.json must expose selected_apps in public_routing_modes")
  }

  if ($productContract.free_tier.node_pool -ne "NL-free") {
    $manifestErrors.Add("config\\product-contract.seed.json must keep free_tier.node_pool as NL-free")
  }

  if ([int]$productContract.free_tier.traffic_gb -ne 5) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep free_tier.traffic_gb at 5")
  }

  if ([int]$productContract.free_tier.speed_mbps -ne 50) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep free_tier.speed_mbps at 50")
  }

  if ($productContract.monetization.in_app_purchases -ne $false) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep monetization.in_app_purchases false")
  }

  if ($productContract.monetization.third_party_ads -ne $false) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep monetization.third_party_ads false")
  }

  if ($productContract.monetization.first_party_promos_only -ne $true) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep monetization.first_party_promos_only true")
  }

  $expectedVariantOrder = @("vless_reality", "vmess", "trojan", "xhttp")
  if ((@($productContract.location_variant_order) -join ",") -ne ($expectedVariantOrder -join ",")) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep location_variant_order as vless_reality, vmess, trojan, xhttp")
  }
}

$runtimeProfilePath = Join-Path $root "config\\runtime-profile.seed.json"
if (Test-Path -LiteralPath $runtimeProfilePath -PathType Leaf) {
  $runtimeProfile = Get-Content -Raw -LiteralPath $runtimeProfilePath | ConvertFrom-Json

  if (@($runtimeProfile.public_routing_modes) -notcontains "selected_apps") {
    $manifestErrors.Add("config\\runtime-profile.seed.json must expose selected_apps in public_routing_modes")
  }

  if ($runtimeProfile.free_tier.node_pool -ne "NL-free") {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep free_tier.node_pool as NL-free")
  }

  if ([int]$runtimeProfile.free_tier.speed_mbps -ne 50) {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep free_tier.speed_mbps at 50")
  }

  if ($runtimeProfile.monetization.in_app_purchases -ne $false) {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep monetization.in_app_purchases false")
  }

  if ($runtimeProfile.monetization.third_party_ads -ne $false) {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep monetization.third_party_ads false")
  }

  if ($runtimeProfile.official_surfaces.checkout -ne "https://pay.pokrov.space/checkout/") {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep the checkout official surface on https://pay.pokrov.space/checkout/")
  }
}

$runtimeArtifactsPath = Join-Path $root "config\\runtime-artifacts.seed.json"
if (Test-Path -LiteralPath $runtimeArtifactsPath -PathType Leaf) {
  $runtimeArtifacts = Get-Content -Raw -LiteralPath $runtimeArtifactsPath | ConvertFrom-Json

  if ($runtimeArtifacts.libcore.release_tag -ne "v3.1.8") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep libcore.release_tag pinned to v3.1.8 until the runtime lane moves in one tracked wave")
  }

  if ($runtimeArtifacts.libcore.repository -ne "hiddify/hiddify-core") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep libcore.repository on hiddify/hiddify-core")
  }

  foreach ($target in @("android", "ios", "macos", "windows")) {
    if (-not $runtimeArtifacts.libcore.assets.$target) {
      $manifestErrors.Add("config\\runtime-artifacts.seed.json must define libcore asset metadata for $target")
    }
  }
}

$windowsReleaseConfigPath = Join-Path $root "config\\windows-release.seed.json"
if (Test-Path -LiteralPath $windowsReleaseConfigPath -PathType Leaf) {
  $windowsReleaseConfig = Get-Content -Raw -LiteralPath $windowsReleaseConfigPath | ConvertFrom-Json

  if ($windowsReleaseConfig.binary_name -ne "pokrov_windows_seed.exe") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep binary_name as pokrov_windows_seed.exe")
  }

  if ($windowsReleaseConfig.runtime.platform -ne "windows") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.platform as windows")
  }

  if ($windowsReleaseConfig.runtime.artifact_directory -ne "apps/windows_shell/windows/runner/resources/runtime") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.artifact_directory on apps/windows_shell/windows/runner/resources/runtime")
  }

  foreach ($requiredPath in @("pokrov_windows_seed.exe", "libcore.dll", "data/app.so")) {
    if (@($windowsReleaseConfig.required_files) -notcontains $requiredPath) {
      $manifestErrors.Add("config\\windows-release.seed.json must list required build file '$requiredPath'")
    }
  }
}

$programSeed = Join-Path $root "program.seed.yaml"

if (Test-Path -LiteralPath $programSeed -PathType Leaf) {
  $seedText = Get-Content -Raw -LiteralPath $programSeed
  $seedLines = $seedText -split "\r?\n" | ForEach-Object { $_.Trim() }

  if ($seedText -notmatch "config/product-contract.seed.json") {
    $manifestErrors.Add("program.seed.yaml must reference config/product-contract.seed.json")
  }

  if ($seedText -notmatch "validation_script: scripts/validate-seed.ps1") {
    $manifestErrors.Add("program.seed.yaml must reference scripts/validate-seed.ps1")
  }

  if ($seedText -notmatch "bootstrap_script: scripts/bootstrap-local.ps1") {
    $manifestErrors.Add("program.seed.yaml must reference scripts/bootstrap-local.ps1")
  }

  if ($seedText -notmatch "workspace_bootstrap_script: scripts/bootstrap-workspace.ps1") {
    $manifestErrors.Add("program.seed.yaml must reference scripts/bootstrap-workspace.ps1")
  }

  if ($seedText -notmatch "test_script: scripts/run-tests.ps1") {
    $manifestErrors.Add("program.seed.yaml must reference scripts/run-tests.ps1")
  }

  foreach ($target in $expectedPublicTargets) {
    if ($seedLines -notcontains "- $target") {
      $manifestErrors.Add("program.seed.yaml must list public target '$target'")
    }
  }

  if ($seedText -notmatch "path: apps/ios_shell") {
    $manifestErrors.Add("program.seed.yaml must track apps/ios_shell")
  }

  if ($seedText -notmatch "path: apps/macos_shell") {
    $manifestErrors.Add("program.seed.yaml must track apps/macos_shell")
  }
}

if ($missing.Count -gt 0 -or $invalidJson.Count -gt 0 -or $manifestErrors.Count -gt 0) {
  Write-Host "Seed scaffold check failed." -ForegroundColor Red

  $missing | ForEach-Object { Write-Host $_ }
  $invalidJson | ForEach-Object { Write-Host "JSON $_" }
  $manifestErrors | ForEach-Object { Write-Host $_ }

  exit 1
}

Write-Host "Seed scaffold OK:" -ForegroundColor Green
Write-Host $root
exit 0
