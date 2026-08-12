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
  "AGENTS.md",
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
  "config\\cutover-readiness.seed.json",
  "config\\release-handoff.seed.json",
  "config\\templates\\local.env.example",
  "config\\templates\\device-overrides.seed.json",
  "docs\\README.md",
  "docs\\architecture\\folder-structure.md",
  "docs\\architecture\\package-boundaries.md",
  "docs\\architecture\\bootstrap-workflow.md",
  "docs\\decisions\\2026-07-23-pokrov-core-1.0.0-activation.md",
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
  "scripts\\configure-android-production-signing.ps1",
  "scripts\\build-android-production.ps1",
  "scripts\\build-windows-release.ps1",
  "scripts\\sync-pokrov-core-runtime.ps1",
  "scripts\\run-tests.ps1",
  "scripts\\validate-seed.ps1",
  "test\\README.md",
  "test\\docs-contract.ps1",
  "test\\seed-layout.ps1",
  "packages\\app_shell\\test\\pokrov_seed_app_test.dart"
)

$jsonFiles = @(
  "config\\product-contract.seed.json",
  "config\\platform-matrix.seed.json",
  "config\\runtime-profile.seed.json",
  "config\\runtime-artifacts.seed.json",
  "config\\windows-release.seed.json",
  "config\\cutover-readiness.seed.json",
  "config\\release-handoff.seed.json",
  "config\\templates\\device-overrides.seed.json"
)

$missing = [System.Collections.Generic.List[string]]::new()
$invalidJson = [System.Collections.Generic.List[string]]::new()
$manifestErrors = [System.Collections.Generic.List[string]]::new()
$expectedPublicTargets = @("android", "windows")
$expectedReadinessOnlyTargets = @("ios", "macos")
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

  foreach ($target in $expectedReadinessOnlyTargets) {
    if (@($platformMatrix.readiness_only_targets) -notcontains $target) {
      $manifestErrors.Add("config\\platform-matrix.seed.json must include readiness-only target '$target'")
    }
  }

  if (@($platformMatrix.readiness_only_targets).Count -ne $expectedReadinessOnlyTargets.Count) {
    $manifestErrors.Add("config\\platform-matrix.seed.json must keep readiness_only_targets limited to ios and macos for the Android+Windows public lane")
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

  foreach ($target in $expectedReadinessOnlyTargets) {
    if (@($productContract.readiness_only_scope) -notcontains $target) {
      $manifestErrors.Add("config\\product-contract.seed.json must include readiness-only scope '$target'")
    }
  }

  if (@($productContract.readiness_only_scope).Count -ne $expectedReadinessOnlyTargets.Count) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep readiness_only_scope limited to ios and macos for the Android+Windows public lane")
  }

  if (@($productContract.public_routing_modes) -notcontains "selected_apps") {
    $manifestErrors.Add("config\\product-contract.seed.json must expose selected_apps in public_routing_modes")
  }

  if ($productContract.free_tier.enabled -ne $false) {
    $manifestErrors.Add("config\\product-contract.seed.json must keep free_tier.enabled false")
  }

  if ($productContract.free_tier.status -ne "retired_pending_replacement") {
    $manifestErrors.Add("config\\product-contract.seed.json must mark free_tier retired_pending_replacement")
  }

  if ($null -ne $productContract.free_tier.node_pool) {
    $manifestErrors.Add("config\\product-contract.seed.json must not publish a free_tier.node_pool")
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

  if ($runtimeProfile.free_tier.enabled -ne $false) {
    $manifestErrors.Add("config\\runtime-profile.seed.json must keep free_tier.enabled false")
  }

  if ($runtimeProfile.free_tier.status -ne "retired_pending_replacement") {
    $manifestErrors.Add("config\\runtime-profile.seed.json must mark free_tier retired_pending_replacement")
  }

  if ($null -ne $runtimeProfile.free_tier.node_pool) {
    $manifestErrors.Add("config\\runtime-profile.seed.json must not publish a free_tier.node_pool")
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

  if ($runtimeArtifacts.core.release_tag -ne "v1.0.2") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must pin POKROV Core v1.0.2")
  }

  if ($runtimeArtifacts.core.activation_state -ne "active") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must label POKROV Core v1.0.2 as active")
  }

  if ($runtimeArtifacts.core.repository -ne "Kiwunaka/POKROV-core") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must use Kiwunaka/POKROV-core")
  }

  if ($runtimeArtifacts.core.source_commit -ne "a469240dc3e1e1736ff73348b113f164c277492a") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must pin the exact POKROV Core source commit")
  }
  if ($runtimeArtifacts.core.sing_dependency -ne "v0.8.0-beta.12") {
    $manifestErrors.Add("runtime artifact contract must pin sagernet/sing v0.8.0-beta.12")
  }
  if ($runtimeArtifacts.core.sing_box_version -ne "1.13.0") {
    $manifestErrors.Add("runtime artifact contract must pin embedded sing-box 1.13.0")
  }
  if ($runtimeArtifacts.core.go_toolchain -ne "go1.25.12") {
    $manifestErrors.Add("runtime artifact contract must pin Go 1.25.12")
  }
  $artifactProvenance = $runtimeArtifacts.core.artifact_provenance
  if ($artifactProvenance.status -ne "clean_reproducible_release" -or
      $artifactProvenance.vcs_stamp -ne "disabled_for_reproducible_release_artifacts" -or
      $artifactProvenance.source_identity -ne "annotated_release_tag_and_github_release_commit" -or
      $artifactProvenance.release_url -ne "https://github.com/Kiwunaka/pokrov-core/releases/tag/v1.0.2" -or
      [int64]$artifactProvenance.reproducible_build.android.size -ne 106832036 -or
      $artifactProvenance.reproducible_build.android.sha256 -ne "e98861ec0b658304515c04af6ab98a60f3664f8b5eb7660b57e6f0baa0df385f" -or
      [int64]$artifactProvenance.reproducible_build.windows.size -ne 55122944 -or
      $artifactProvenance.reproducible_build.windows.sha256 -ne "b6d4e28b5fb9d475acc623fed84d2009137a55972a841216a81ae6ac45f98305" -or
      $artifactProvenance.reproducible_build.libcronet_sha256 -ne "8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7" -or
      $artifactProvenance.promotion_rule -ne "accept_exact_v1.0.2_release_artifacts") {
    $manifestErrors.Add("runtime artifact contract must pin the clean reproducible POKROV Core v1.0.2 release")
  }
  if ($runtimeArtifacts.core.desktop_abi.name -ne "pokrov-core" -or
      [int]$runtimeArtifacts.core.desktop_abi.version -ne 2 -or
      $runtimeArtifacts.core.desktop_abi.required_symbol -ne "pokrovCoreAbiVersion" -or
      $runtimeArtifacts.core.desktop_abi.secure_file_symbol -ne "pokrovSecureFile") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep the POKROV Core desktop ABI 2 contract")
  }

  foreach ($target in @("android", "ios", "macos", "windows")) {
    $asset = $runtimeArtifacts.core.assets.$target
    if (-not $asset) {
      $manifestErrors.Add("config\\runtime-artifacts.seed.json must define POKROV Core metadata for $target")
      continue
    }
    if ([string]::IsNullOrWhiteSpace([string]$asset.sync_destination)) {
      $manifestErrors.Add("config\\runtime-artifacts.seed.json must define sync_destination for active $target runtime artifacts")
    }
  }

  $androidRuntime = $runtimeArtifacts.core.assets.android
  if ($androidRuntime.entry -ne "pokrov-core.aar" -or
      $androidRuntime.sync_policy -ne "pokrov_release" -or
      [int64]$androidRuntime.size -ne 106832036 -or
      $androidRuntime.sha256 -ne "e98861ec0b658304515c04af6ab98a60f3664f8b5eb7660b57e6f0baa0df385f") {
    $manifestErrors.Add("runtime artifact contract must pin the POKROV Core 1.0.2 Android AAR")
  }

  $windowsRuntime = $runtimeArtifacts.core.assets.windows
  if ($windowsRuntime.entry -ne "pokrov-core.dll" -or
      $windowsRuntime.sync_policy -ne "pokrov_release" -or
      [int64]$windowsRuntime.size -ne 55122944 -or
      $windowsRuntime.sha256 -ne "b6d4e28b5fb9d475acc623fed84d2009137a55972a841216a81ae6ac45f98305" -or
      @($windowsRuntime.runtime_dependencies) -notcontains "libcronet.dll" -or
      [int64]$windowsRuntime.runtime_dependency_size.'libcronet.dll' -ne 8596992 -or
      $windowsRuntime.runtime_dependency_sha256.'libcronet.dll' -ne "8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must pin the POKROV Core 1.0.2 Windows DLL and libcronet.dll")
  }

  foreach ($target in @("ios", "macos")) {
    $asset = $runtimeArtifacts.core.assets.$target
    if ($asset.sync_policy -ne "manual_core_build" -or
        $asset.platform_state -ne "MANUAL_OWNER_TEST" -or
        $null -ne $asset.size -or
        $null -ne $asset.sha256) {
      $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep $target as an unclaimed manual POKROV Core build")
    }
  }
}

$windowsReleaseConfigPath = Join-Path $root "config\\windows-release.seed.json"
if (Test-Path -LiteralPath $windowsReleaseConfigPath -PathType Leaf) {
  $windowsReleaseConfig = Get-Content -Raw -LiteralPath $windowsReleaseConfigPath | ConvertFrom-Json

  if ($windowsReleaseConfig.binary_name -ne "pokrov_windows_beta.exe") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep binary_name as pokrov_windows_beta.exe")
  }

  if ($windowsReleaseConfig.runtime.platform -ne "windows") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.platform as windows")
  }

  if ($windowsReleaseConfig.runtime.artifact_directory -ne "apps/windows_shell/windows/runner/resources/runtime") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.artifact_directory on apps/windows_shell/windows/runner/resources/runtime")
  }

  if ($windowsReleaseConfig.runtime.core_binary -ne "pokrov-core.dll" -or
      $windowsReleaseConfig.runtime.release_tag -ne "v1.0.2" -or
      [int]$windowsReleaseConfig.runtime.desktop_abi -ne 2 -or
      @($windowsReleaseConfig.runtime.runtime_dependencies) -notcontains "libcronet.dll") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep the POKROV Core 1.0.2 ABI 2 runtime contract")
  }

  foreach ($requiredPath in @("pokrov_windows_beta.exe", "pokrov-core.dll", "libcronet.dll", "data/app.so")) {
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

  foreach ($target in $expectedReadinessOnlyTargets) {
    if ($seedLines -notcontains "- $target") {
      $manifestErrors.Add("program.seed.yaml must list readiness-only target '$target'")
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

try {
  & (Join-Path $root "test\\docs-contract.ps1")
  if (-not $?) {
    throw "Client docs contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Client docs contract failed during seed validation: $($_.Exception.Message)"
}

Write-Host "Seed scaffold OK:" -ForegroundColor Green
Write-Host $root
exit 0
