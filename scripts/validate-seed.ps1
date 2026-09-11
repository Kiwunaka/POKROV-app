[CmdletBinding()]
param(
  [string]$PlatformRoot,
  [string]$CoreRoot
)

$ErrorActionPreference = "Stop"
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
  "packages\\app_shell\\test\\fixtures",
  "packages\\core_domain",
  "packages\\core_domain\\lib",
  "packages\\platform_contracts",
  "packages\\platform_contracts\\lib",
  "packages\\observability_contracts",
  "packages\\observability_contracts\\lib",
  "packages\\observability_contracts\\test",
  "packages\\observability_runtime",
  "packages\\observability_runtime\\lib",
  "packages\\observability_runtime\\test",
  "packages\\observability_runtime\\tool",
  "packages\\diagnostics_collectors",
  "packages\\diagnostics_collectors\\lib",
  "packages\\diagnostics_collectors\\test",
  "packages\\support_bundle",
  "packages\\support_bundle\\lib",
  "packages\\support_bundle\\test",
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
  "config\\observability-contracts.seed.json",
  "config\\support-signing.seed.json",
  "config\\windows-release.seed.json",
  "config\\cutover-readiness.seed.json",
  "config\\release-handoff.seed.json",
  "config\\release-rollback-catalog.seed.json",
  "config\\state-migrations.v1.json",
  "config\\templates\\local.env.example",
  "config\\templates\\device-overrides.seed.json",
  "docs\\README.md",
  "docs\\architecture\\folder-structure.md",
  "docs\\architecture\\package-boundaries.md",
  "docs\\architecture\\bootstrap-workflow.md",
  "docs\\architecture\\persisted-state-contract.md",
  "docs\\architecture\\platform-privilege-runtime-contract.md",
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
  "packages\\observability_contracts\\README.md",
  "packages\\observability_contracts\\pubspec.yaml",
  "packages\\observability_contracts\\lib\\observability_contracts.dart",
  "packages\\observability_contracts\\test\\observability_contracts_test.dart",
  "packages\\observability_runtime\\README.md",
  "packages\\observability_runtime\\pubspec.yaml",
  "packages\\observability_runtime\\lib\\observability_runtime.dart",
  "packages\\observability_runtime\\test\\observability_runtime_test.dart",
  "packages\\observability_runtime\\test\\fault_chaos_contract_test.dart",
  "packages\\observability_runtime\\test\\overhead_contract_test.dart",
  "packages\\observability_runtime\\tool\\runtime_overhead_benchmark.dart",
  "packages\\diagnostics_collectors\\README.md",
  "packages\\diagnostics_collectors\\pubspec.yaml",
  "packages\\diagnostics_collectors\\lib\\diagnostics_collectors.dart",
  "packages\\diagnostics_collectors\\test\\diagnostics_collectors_test.dart",
  "packages\\support_bundle\\README.md",
  "packages\\support_bundle\\pubspec.yaml",
  "packages\\support_bundle\\lib\\support_bundle.dart",
  "packages\\support_bundle\\test\\support_bundle_test.dart",
  "packages\\runtime_engine\\README.md",
  "packages\\runtime_engine\\pubspec.yaml",
  "packages\\runtime_engine\\lib\\runtime_engine.dart",
  "packages\\runtime_engine\\test\\runtime_engine_test.dart",
  "packages\\app_shell\\lib\\src\\seed\\platform_product_facts.g.dart",
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
  "scripts\\support-signing-pin.ps1",
  "scripts\\check-client-version-parity.ps1",
  "scripts\\check-release-source-logging.ps1",
  "scripts\\new-release-handoff-v2.ps1",
  "scripts\\set-release-stable-pointer.ps1",
  "scripts\\validate-observability-contracts.ps1",
  "scripts\\sync-pokrov-core-runtime.ps1",
  "scripts\\run-tests.ps1",
  "scripts\\validate-seed.ps1",
  "test\\README.md",
  "test\\docs-contract.ps1",
  "test\\client-presentation-boundary.ps1",
  "test\\release-handoff-v2-contract.ps1",
  "test\\release-rollback-catalog-contract.ps1",
  "test\\release-source-logging-contract.ps1",
  "test\\release-v2-ci-contract.ps1",
  "test\\support-signing-pin-contract.ps1",
  "test\\repository-hygiene-contract.ps1",
  "test\\run-tests-contract.ps1",
  "test\\fixtures\\release-handoff-v2\\synthetic-candidate-input.json",
  "test\\seed-layout.ps1",
  "packages\\app_shell\\test\\pokrov_seed_app_test.dart",
  "packages\\app_shell\\test\\first_session_coordinator_test.dart",
  "packages\\app_shell\\test\\account_session_coordinator_test.dart",
  "packages\\app_shell\\test\\diagnostics_coordinator_test.dart",
  "packages\\app_shell\\test\\fixtures\\app-first-session-v0.json",
  "packages\\app_shell\\test\\fixtures\\secure-session-v0.txt",
  "packages\\app_shell\\test\\fixtures\\routing-preferences-v0.json",
  "packages\\app_shell\\test\\state_migration_contract_test.dart",
  "packages\\app_shell\\test\\fixtures\\client-experience-v0.json",
  "apps\\android_shell\\android\\app\\src\\test\\resources\\runtime-profile-v0.properties"
)

$jsonFiles = @(
  "config\\product-contract.seed.json",
  "config\\platform-matrix.seed.json",
  "config\\runtime-profile.seed.json",
  "config\\runtime-artifacts.seed.json",
  "config\\observability-contracts.seed.json",
  "config\\support-signing.seed.json",
  "config\\windows-release.seed.json",
  "config\\cutover-readiness.seed.json",
  "config\\release-handoff.seed.json",
  "config\\release-rollback-catalog.seed.json",
  "config\\state-migrations.v1.json",
  "config\\templates\\device-overrides.seed.json",
  "test\\fixtures\\release-handoff-v2\\synthetic-candidate-input.json",
  "packages\\app_shell\\test\\fixtures\\app-first-session-v0.json",
  "packages\\app_shell\\test\\fixtures\\routing-preferences-v0.json",
  "packages\\app_shell\\test\\fixtures\\client-experience-v0.json"
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

$stateMigrationsPath = Join-Path $root "config\\state-migrations.v1.json"
if (Test-Path -LiteralPath $stateMigrationsPath -PathType Leaf) {
  $stateMigrations = Get-Content -Raw -LiteralPath $stateMigrationsPath | ConvertFrom-Json
  if ($stateMigrations.contract_id -ne "pokrov.client-state-migrations.v1" -or
      [int]$stateMigrations.schema_version -ne 1 -or
      $stateMigrations.state -ne "PRE_CANDIDATE_LOCAL" -or
      $stateMigrations.source_product_range -ne ">=1.1.0 <1.2.0" -or
      $stateMigrations.target.product_version -ne "1.2.0" -or
      [int]$stateMigrations.target.android_windows_build_number -ne 30 -or
      -not [bool]$stateMigrations.fixture_policy.production_data_forbidden -or
      -not [bool]$stateMigrations.fixture_policy.fixture_hash_required) {
    $manifestErrors.Add("config\\state-migrations.v1.json must bind the PRE_CANDIDATE_LOCAL 1.1.x to 1.2.0+30 migration authority")
  }

  $migrations = @($stateMigrations.migrations)
  if ($migrations.Count -ne 5 -or
      @($migrations.id | Sort-Object -Unique).Count -ne 5 -or
      @($migrations.fixture | Sort-Object -Unique).Count -ne 5) {
    $manifestErrors.Add("state migration contract must define five unique fixture-bound migrations")
  }
  foreach ($migration in $migrations) {
    $fixtureRelative = [string]$migration.fixture
    $testRelative = [string]$migration.test_file
    $fixturePath = Join-Path $root $fixtureRelative
    $testPath = Join-Path $root $testRelative
    if ([string]::IsNullOrWhiteSpace([string]$migration.id) -or
        [string]::IsNullOrWhiteSpace([string]$migration.owner) -or
        [string]::IsNullOrWhiteSpace([string]$migration.source_schema) -or
        [string]::IsNullOrWhiteSpace([string]$migration.target_schema) -or
        [string]::IsNullOrWhiteSpace([string]$migration.migration_behavior) -or
        [string]::IsNullOrWhiteSpace([string]$migration.rollback_policy) -or
        @($migration.platforms).Count -eq 0) {
      $manifestErrors.Add("state migration '$($migration.id)' is missing owner/schema/behavior/rollback metadata")
      continue
    }
    if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
      $manifestErrors.Add("state migration '$($migration.id)' fixture is missing: $fixtureRelative")
    } else {
      $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $fixturePath).Hash.ToLowerInvariant()
      if ($actualHash -ne [string]$migration.fixture_sha256) {
        $manifestErrors.Add("state migration '$($migration.id)' fixture SHA-256 drifted")
      }
    }
    if (-not (Test-Path -LiteralPath $testPath -PathType Leaf) -or
        (Get-Content -Raw -LiteralPath $testPath) -notlike "*$([string]$migration.test_name)*") {
      $manifestErrors.Add("state migration '$($migration.id)' named regression is missing")
    }
  }

  $nonMigrating = @($stateMigrations.non_migrating_state)
  if ($nonMigrating.Count -ne 2 -or
      @($nonMigrating.id | Sort-Object -Unique).Count -ne 2 -or
      @($nonMigrating.id) -notcontains "android_update_cache" -or
      @($nonMigrating.id) -notcontains "windows_runtime_recovery_journal") {
    $manifestErrors.Add("state migration contract must explicitly inventory update cache and Windows recovery journal")
  }
  foreach ($state in $nonMigrating) {
    if ([string]::IsNullOrWhiteSpace([string]$state.owner) -or
        [string]::IsNullOrWhiteSpace([string]$state.policy) -or
        -not (Test-Path -LiteralPath (Join-Path $root ([string]$state.test_file)) -PathType Leaf)) {
      $manifestErrors.Add("non-migrating state '$($state.id)' is missing owner/policy/test evidence")
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

  if ((@($platformMatrix.conditional_beta_targets) -join ',') -ne 'linux' -or
      $platformMatrix.host_shells.linux -ne 'apps/linux_shell' -or
      $platformMatrix.release_readiness.linux -ne 'conditional_beta_foundation_implemented_live_runtime_package_and_matrix_proof_open') {
    $manifestErrors.Add("config\\platform-matrix.seed.json must keep Linux as the conditional non-public beta foundation")
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

  if ((@($productContract.conditional_beta_scope) -join ',') -ne 'linux') {
    $manifestErrors.Add("config\\product-contract.seed.json must keep Linux in conditional_beta_scope")
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

  if ($runtimeArtifacts.core.release_tag -ne "v1.1.0" -or
      $runtimeArtifacts.core.release_tag_created -ne $false) {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must bind untagged POKROV Core v1.1.0 pre-candidate bytes")
  }

  if ($runtimeArtifacts.core.version -ne "1.1.0" -or
      $runtimeArtifacts.core.release_tag -ne "v$($runtimeArtifacts.core.version)") {
    $manifestErrors.Add("runtime artifact contract must align the POKROV Core version and release tag")
  }

  if ($runtimeArtifacts.core.android_package -ne "space.pokrov.core") {
    $manifestErrors.Add("runtime artifact contract must pin Android package space.pokrov.core")
  }

  if ($runtimeArtifacts.core.activation_state -ne "active_pre_candidate_local") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep POKROV Core v1.1.0 active only for the pre-candidate local lane")
  }

  if ($runtimeArtifacts.core.repository -ne "Kiwunaka/POKROV-core") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must use Kiwunaka/POKROV-core")
  }

  if ($runtimeArtifacts.core.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must pin the exact POKROV Core source commit")
  }
  if ($runtimeArtifacts.core.sing_dependency -ne "v0.8.0-beta.12") {
    $manifestErrors.Add("runtime artifact contract must pin sagernet/sing v0.8.0-beta.12")
  }
  if ($runtimeArtifacts.core.sing_box_version -ne "1.13.0") {
    $manifestErrors.Add("runtime artifact contract must pin embedded sing-box 1.13.0")
  }
  if ($runtimeArtifacts.core.go_toolchain -ne "go1.26.8") {
    $manifestErrors.Add("runtime artifact contract must pin Go 1.26.8")
  }
  $nativeGoNotices = $runtimeArtifacts.core.native_go_notices
  $nativeGoNoticeRelativePath = "packages/app_shell/assets/licenses/native-go-NOTICES.txt"
  $nativeGoNoticePath = Join-Path $root $nativeGoNoticeRelativePath
  if ($nativeGoNotices.file -ne $nativeGoNoticeRelativePath -or
      $nativeGoNotices.source_commit -ne $runtimeArtifacts.core.source_commit -or
      $nativeGoNotices.go_toolchain -ne $runtimeArtifacts.core.go_toolchain -or
      -not (Test-Path -LiteralPath $nativeGoNoticePath -PathType Leaf)) {
    $manifestErrors.Add("Core native Go notices must exist and bind the current Core source and toolchain")
  } elseif ((Get-FileHash -Algorithm SHA256 -LiteralPath $nativeGoNoticePath).Hash.ToLowerInvariant() -ne $nativeGoNotices.sha256) {
    $manifestErrors.Add("Core native Go notices must match their manifest SHA-256")
  }
  $appShellPubspec = [System.IO.File]::ReadAllText((Join-Path $root "packages/app_shell/pubspec.yaml"))
  if ($appShellPubspec -notmatch '(?m)^\s+- assets/licenses/native-go-NOTICES\.txt\s*$') {
    $manifestErrors.Add("App shell must package the declared Core native Go notice asset")
  }
  $artifactProvenance = $runtimeArtifacts.core.artifact_provenance
  if ($artifactProvenance.status -ne "clean_reproducible_pre_candidate_local" -or
      $artifactProvenance.vcs_stamp -ne "disabled_for_reproducible_release_artifacts" -or
      $artifactProvenance.source_identity -ne "exact_single_source_commit_without_release_tag_or_publication" -or
      $null -ne $artifactProvenance.release_url -or
      $artifactProvenance.evidence_ceiling -ne "PRE_CANDIDATE_LOCAL" -or
      $artifactProvenance.candidate_created -ne $false -or
      $artifactProvenance.promotion_authorized -ne $false -or
      $artifactProvenance.reproducible_build.android.result -ne "PASS_BYTE_IDENTICAL_TWO_BUILDS" -or
      $artifactProvenance.reproducible_build.android.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      [int64]$artifactProvenance.reproducible_build.android.size -ne 106843791 -or
      $artifactProvenance.reproducible_build.android.sha256 -ne "feb452f5f06b865e3ae0655ef4168ffe065c08b759f64e9cfa084cde9d5a5941" -or
      $artifactProvenance.reproducible_build.windows.result -ne "PASS_BYTE_IDENTICAL_TWO_BUILDS" -or
      $artifactProvenance.reproducible_build.windows.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      [int64]$artifactProvenance.reproducible_build.windows.size -ne 55012864 -or
      $artifactProvenance.reproducible_build.windows.sha256 -ne "e77cc0ab979becc635ec578b8b44248b1146dd96ba34cd4de72e62130089ce2c" -or
      $artifactProvenance.reproducible_build.libcronet_sha256 -ne "8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7" -or
      $artifactProvenance.promotion_rule -ne "exact_bytes_require_platform_source_convergence_candidate_signing_manual_gates_and_publication") {
    $manifestErrors.Add("runtime artifact contract must pin the exact single-source POKROV Core v1.1.0 pre-candidate builds without claiming a tag or publication")
  }
  $artifactEvidence = $artifactProvenance.artifact_evidence
  if ($artifactEvidence.android.result -ne "PASS_BYTE_IDENTICAL_TWO_BUILDS" -or
      $artifactEvidence.android.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      $artifactEvidence.android.tree_sha256 -ne "9e22e6293523569d30c5c64b8a807823f9b3a86adc24b86932b804cda807ffd9" -or
      $artifactEvidence.android.evidence_sha256 -ne "055c05714e445b350eeabec5addcfbe5689522bede9d25d94932c66595001c35" -or
      (@($artifactEvidence.android.abis) -join ',') -ne 'armeabi-v7a,arm64-v8a,x86,x86_64' -or
      $artifactEvidence.windows.result -ne "PASS_BYTE_IDENTICAL_TWO_BUILDS" -or
      $artifactEvidence.windows.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      $artifactEvidence.windows.tree_sha256 -ne "cf42e69f8f9a1abb90e346347b7331d078ce56d593c1c78c37cd37d9b3ef7ca4" -or
      $artifactEvidence.windows.evidence_sha256 -ne "48c02da02167bc1c82e2f7a3fb3a99527bb85ea1dba90dbe88385fade8692ca4" -or
      [int]$artifactEvidence.windows.required_exports -ne 15 -or
      [int]$artifactEvidence.windows.proxy_only_start_stop_cycles -ne 100 -or
      $artifactEvidence.windows.proxy_only_result -ne "PASS_LOCAL") {
    $manifestErrors.Add("runtime artifact contract must bind the exact Core 1.1.0 reproducibility, ABI and Windows proxy-only evidence")
  }
  $sbomEvidence = @($artifactEvidence.sbom)
  if ($sbomEvidence.Count -ne 2 -or
      $sbomEvidence[0].name -ne 'core-source.cdx.json' -or
      $sbomEvidence[0].sha256 -ne 'b1954594dcecda47ae4bbeccff5e83521081c4f95c8e41327b953a166a182378' -or
      $sbomEvidence[1].name -ne 'engine-source.cdx.json' -or
      $sbomEvidence[1].sha256 -ne 'c7cbb50a59983e271e892e74d7dc5c3809c48be96b71afde7057cda36c780bb2') {
    $manifestErrors.Add("runtime artifact contract must bind both exact Core 1.1.0 SBOM identities")
  }
  $retainedCore = $runtimeArtifacts.core.retained_public_release
  if ($retainedCore.version -ne '1.0.3' -or
      $retainedCore.release_tag -ne 'v1.0.3' -or
      $retainedCore.source_commit -ne '69a74545101708e56183c92e31f2b4c7b2509884' -or
      $retainedCore.release_url -ne 'https://github.com/Kiwunaka/pokrov-core/releases/tag/v1.0.3' -or
      [int64]$retainedCore.android.size -ne 106861671 -or
      $retainedCore.android.sha256 -ne '6e6f3b688fe415c9392e19aa4f8660885316897cfc369cf8c3ff3d01100ee14f' -or
      [int64]$retainedCore.windows.size -ne 55134208 -or
      $retainedCore.windows.sha256 -ne '7cc83854fc4022b759e9de3d0942b90a24c859cfd51e3231d04e7c7a6b7d5054' -or
      $retainedCore.libcronet_sha256 -ne '8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7') {
    $manifestErrors.Add("runtime artifact contract must retain the exact public Core 1.0.3 rollback identity separately")
  }
  $coreTarget = $runtimeArtifacts.core.development_target
  if ($coreTarget.required_for_product -ne "1.2.0" -or
      $coreTarget.version -ne "1.1.0" -or
      $coreTarget.release_tag -ne "v1.1.0" -or
      $coreTarget.state -ne "PRE_CANDIDATE_LOCAL" -or
      $coreTarget.candidate_created -ne $false -or
      $coreTarget.artifact_state -ne "exact_local_replacement_bound") {
    $manifestErrors.Add("runtime artifact contract must bind the exact Core 1.1.0 local replacement without claiming a candidate")
  }
  if ($runtimeArtifacts.core.desktop_abi.name -ne "pokrov-core" -or
      [int]$runtimeArtifacts.core.desktop_abi.version -ne 2 -or
      $runtimeArtifacts.core.desktop_abi.required_symbol -ne "pokrovCoreAbiVersion" -or
      $runtimeArtifacts.core.desktop_abi.secure_file_symbol -ne "pokrovSecureFile" -or
      $runtimeArtifacts.core.desktop_abi.optional_capabilities_symbol -ne "pokrovCoreCapabilities" -or
      [int]$runtimeArtifacts.core.desktop_abi.capability_schema -ne 1 -or
      [int]$runtimeArtifacts.core.desktop_abi.event_abi -ne 1 -or
      (@($runtimeArtifacts.core.desktop_abi.legacy_without_capabilities_symbol) -join ',') -ne '2' -or
      (@($runtimeArtifacts.core.desktop_abi.required_capabilities) -join ',') -ne
        'bounded_stop_reason,core_start_stop,materialized_profile,secure_profile_file,structured_operational_events,typed_lifecycle_events' -or
      (@($runtimeArtifacts.core.desktop_abi.lifecycle_events) -join ',') -ne
        'initialization,profile,core_start,tun,routes,dns,egress,recovery,stop') {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must keep the POKROV Core desktop ABI 2 contract")
  }
  $structuredEvents = $runtimeArtifacts.core.desktop_abi.structured_events
  if ($structuredEvents.required_for_release -ne '1.2.0' -or
      $structuredEvents.callback_symbol -ne 'pokrovCoreSetEventCallback' -or
      $structuredEvents.context_symbol -ne 'pokrovCoreSetEventContext' -or
      $structuredEvents.retained_v1_0_3_artifact_mode -ne
        'legacy_without_structured_events' -or
      $structuredEvents.exact_replacement_artifact -ne 'bound_pre_candidate_local') {
    $manifestErrors.Add("config\runtime-artifacts.seed.json must keep the honest Core structured-event cutover state")
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
      $androidRuntime.sync_policy -ne "exact_pre_candidate_build" -or
      $androidRuntime.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      [int64]$androidRuntime.size -ne 106843791 -or
      $androidRuntime.sha256 -ne "feb452f5f06b865e3ae0655ef4168ffe065c08b759f64e9cfa084cde9d5a5941" -or
      $androidRuntime.platform_state -ne "active_pre_candidate_local_security_fixed_physical_repeat_open") {
    $manifestErrors.Add("runtime artifact contract must pin the POKROV Core 1.1.0 Android AAR")
  }

  $windowsRuntime = $runtimeArtifacts.core.assets.windows
  if ($windowsRuntime.entry -ne "pokrov-core.dll" -or
      $windowsRuntime.sync_policy -ne "exact_pre_candidate_build" -or
      $windowsRuntime.source_commit -ne "2662f76a3303a0518bb07fbbdc449c066de2f95b" -or
      [int64]$windowsRuntime.size -ne 55012864 -or
      $windowsRuntime.sha256 -ne "e77cc0ab979becc635ec578b8b44248b1146dd96ba34cd4de72e62130089ce2c" -or
      $windowsRuntime.platform_state -ne "active_pre_candidate_local_security_fixed_reproducible_abi_proxy_recheck_passed" -or
      @($windowsRuntime.runtime_dependencies) -notcontains "libcronet.dll" -or
      [int64]$windowsRuntime.runtime_dependency_size.'libcronet.dll' -ne 8596992 -or
      $windowsRuntime.runtime_dependency_sha256.'libcronet.dll' -ne "8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7") {
    $manifestErrors.Add("config\\runtime-artifacts.seed.json must pin the POKROV Core 1.1.0 Windows DLL and retained libcronet.dll")
  }

  $cronetNotices = $windowsRuntime.runtime_dependency_origin.'libcronet.dll'.notices
  $cronetNoticeRelativePath = "apps/windows_shell/windows/runner/resources/runtime/libcronet.NOTICES.txt"
  $cronetNoticePath = Join-Path $root $cronetNoticeRelativePath
  if ($cronetNotices.file -ne $cronetNoticeRelativePath -or
      -not (Test-Path -LiteralPath $cronetNoticePath -PathType Leaf)) {
    $manifestErrors.Add("Windows Cronet must retain its declared native notice file")
  } elseif ((Get-FileHash -Algorithm SHA256 -LiteralPath $cronetNoticePath).Hash.ToLowerInvariant() -ne $cronetNotices.sha256) {
    $manifestErrors.Add("Windows Cronet native notice file must match its manifest SHA-256")
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

  if ($windowsReleaseConfig.binary_name -ne "pokrov_windows.exe") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep binary_name as pokrov_windows.exe")
  }

  if ($windowsReleaseConfig.runtime.platform -ne "windows") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.platform as windows")
  }

  if ($windowsReleaseConfig.runtime.artifact_directory -ne "apps/windows_shell/windows/runner/resources/runtime") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep runtime.artifact_directory on apps/windows_shell/windows/runner/resources/runtime")
  }

  if ($windowsReleaseConfig.runtime.core_binary -ne "pokrov-core.dll" -or
      $windowsReleaseConfig.runtime.service_binary -ne "pokrov_service.exe" -or
      $windowsReleaseConfig.runtime.release_tag -ne "v1.1.0" -or
      [int]$windowsReleaseConfig.runtime.desktop_abi -ne 2 -or
      @($windowsReleaseConfig.runtime.runtime_dependencies) -notcontains "libcronet.dll") {
    $manifestErrors.Add("config\\windows-release.seed.json must keep the POKROV Core 1.1.0 ABI 2 pre-candidate runtime contract")
  }

  if ([bool]$windowsReleaseConfig.portable_zip.supported) {
    $manifestErrors.Add("config\windows-release.seed.json must not claim a portable ZIP while Windows requires SCM service installation")
  }

  foreach ($requiredPath in @("pokrov_windows.exe", "pokrov_service.exe", "pokrov-core.dll", "libcronet.dll", "data/app.so")) {
    if (@($windowsReleaseConfig.required_files) -notcontains $requiredPath) {
      $manifestErrors.Add("config\\windows-release.seed.json must list required build file '$requiredPath'")
    }
  }
}

$supportSigningConfigPath = Join-Path $root "config\\support-signing.seed.json"
if (Test-Path -LiteralPath $supportSigningConfigPath -PathType Leaf) {
  try {
    . (Join-Path $root "scripts\\support-signing-pin.ps1")
    $supportSigningPin = Resolve-PokrovSupportSigningPin -RepositoryRoot $root -ProvidedKeyId '' -ProvidedPublicKeyB64Url ''
    if ($supportSigningPin.key_id -ne 'pokrov-support-2026-08' -or
        $supportSigningPin.public_key_sha256 -ne '44aed43310eaf5442b3493cbe566b5f0f620a5660bb84a6bd028832114f48845') {
      $manifestErrors.Add("config\\support-signing.seed.json does not resolve to the active 1.2.0 support signing identity")
    }
  } catch {
    $manifestErrors.Add("config\\support-signing.seed.json failed canonical pin validation: $($_.Exception.Message)")
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

if ([string]::IsNullOrWhiteSpace($CoreRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:POKROV_CORE_ROOT)) {
    $CoreRoot = $env:POKROV_CORE_ROOT
  } else {
    $CoreRoot = Join-Path (Split-Path -Parent $root) "POKROV-core"
  }
}

try {
  & (Join-Path $root "scripts\\check-client-version-parity.ps1") -CoreRoot $CoreRoot
  if (-not $?) {
    throw "Client version parity returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Client version parity failed during seed validation: $($_.Exception.Message)"
}

if ([string]::IsNullOrWhiteSpace($PlatformRoot)) {
  if (-not [string]::IsNullOrWhiteSpace($env:POKROV_PLATFORM_ROOT)) {
    $PlatformRoot = $env:POKROV_PLATFORM_ROOT
  } else {
    $PlatformRoot = Join-Path (Split-Path -Parent $root) "VPN"
  }
}

try {
  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if (-not $pythonCommand) {
    throw "Python is required for the cross-repository product-facts projection check."
  }
  $sharedFactsSync = Join-Path $PlatformRoot "scripts\\sync_shared_surface_facts.py"
  if (-not (Test-Path -LiteralPath $sharedFactsSync -PathType Leaf)) {
    throw "Missing platform shared-facts synchronizer."
  }
  & $pythonCommand.Source -B $sharedFactsSync `
    --target-lane pokrov-app `
    --pokrov-app-root $root `
    --check
  if ($LASTEXITCODE -ne 0) {
    throw "Platform shared-facts projection check failed."
  }
  $seedContextSource = [IO.File]::ReadAllText(
    (Join-Path $root "packages\\app_shell\\lib\\src\\seed\\seed_context.dart")
  )
  foreach ($requiredProjectionConsumer in @(
    "PlatformProductFacts.publicReleaseTargets",
    "PlatformProductFacts.defaultRuntimeCore",
    "PlatformProductFacts.trialDays",
    "PlatformProductFacts.telegramRewardDays",
    "PlatformProductFacts.supportBot"
  )) {
    if (-not $seedContextSource.Contains($requiredProjectionConsumer)) {
      throw "Client runtime seed does not consume generated platform fact: $requiredProjectionConsumer"
    }
  }
  Write-Host "Cross-repository product facts projection OK." -ForegroundColor Green
} catch {
  throw "Cross-repository product facts failed during seed validation: $($_.Exception.Message)"
}

try {
  $releaseHandoff = Get-Content -Raw -LiteralPath `
    (Join-Path $root "config\release-handoff.seed.json") | ConvertFrom-Json
  $publicRelease = $releaseHandoff.latest_repo_backed_release
  $developmentTarget = $releaseHandoff.release_truth.development_target
  $publicUniversalArtifacts = @(
    $publicRelease.artifacts | Where-Object {
      $_.platform -eq 'android' -and $_.kind -eq 'apk' -and $_.abi -eq 'universal'
    }
  )
  if ($publicUniversalArtifacts.Count -ne 1) {
    throw "Release handoff must contain exactly one retained public universal Android artifact."
  }
  $publicPackageLine = "$($publicRelease.version)+$($publicUniversalArtifacts[0].version_code)"
  $requiredVersionFacts = @(
    "v$($publicRelease.version)",
    $publicPackageLine,
    $developmentTarget.package_version,
    $developmentTarget.state,
    "candidate_created=$($developmentTarget.candidate_created.ToString().ToLowerInvariant())",
    "config/release-handoff.seed.json"
  )
  $platformVersionOwnerPaths = @(
    "docs\operations\deployment-and-access.md",
    "docs\operations\publishing-and-signing-guide.md",
    "docs\developer\developer-guide.md",
    "docs\developer\repository-map.md"
  )
  foreach ($relativePath in $platformVersionOwnerPaths) {
    $ownerPath = Join-Path $PlatformRoot $relativePath
    if (-not (Test-Path -LiteralPath $ownerPath -PathType Leaf)) {
      throw "Missing platform version owner: $relativePath"
    }
    $ownerText = [IO.File]::ReadAllText($ownerPath)
    foreach ($fact in $requiredVersionFacts) {
      if (-not $ownerText.Contains($fact)) {
        throw "Platform version owner $relativePath lacks handoff-derived fact: $fact"
      }
    }
    foreach ($staleVersion in @('v1.0.10', 'v1.0.13')) {
      if ($ownerText.Contains($staleVersion)) {
        throw "Platform version owner $relativePath retains stale active version: $staleVersion"
      }
    }
  }
  Write-Host (
    "Cross-repository version truth OK: public={0} package={1} target={2} state={3} candidate={4}" -f `
      $publicRelease.version,
      $publicPackageLine,
      $developmentTarget.package_version,
      $developmentTarget.state,
      $developmentTarget.candidate_created
  ) -ForegroundColor Green
} catch {
  throw "Cross-repository version truth failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "scripts\\validate-observability-contracts.ps1") `
    -PlatformRoot $PlatformRoot -CoreRoot $CoreRoot
  if (-not $?) {
    throw "Observability contract parity returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Observability contract parity failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\release-source-logging-contract.ps1")
  if (-not $?) {
    throw "Release source logging contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Release source logging contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\release-handoff-v2-contract.ps1") `
    -PlatformRoot $PlatformRoot -CoreRoot $CoreRoot
  if (-not $?) {
    throw "Release-handoff v2 client contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Release-handoff v2 client contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\release-rollback-catalog-contract.ps1")
  if (-not $?) {
    throw "Release rollback catalog contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Release rollback catalog contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\release-v2-ci-contract.ps1")
  if (-not $?) {
    throw "Release-v2 CI contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Release-v2 CI contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\repository-hygiene-contract.ps1")
  if (-not $?) {
    throw "Repository hygiene contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Repository hygiene contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\run-tests-contract.ps1")
  if (-not $?) {
    throw "Standard client test-runner contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Standard client test-runner contract failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\client-presentation-boundary.ps1")
  if (-not $?) {
    throw "Client presentation boundary returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Client presentation boundary failed during seed validation: $($_.Exception.Message)"
}

try {
  & (Join-Path $root "test\\client-performance-collector-contract.ps1")
  if (-not $?) {
    throw "Client performance collector contract returned an unsuccessful PowerShell status."
  }
} catch {
  throw "Client performance collector contract failed during seed validation: $($_.Exception.Message)"
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
