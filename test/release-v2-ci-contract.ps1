[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $root ".github\workflows\release-v2-contract.yml"

if (-not (Test-Path -LiteralPath $workflowPath -PathType Leaf)) {
  throw "Release-v2 CI workflow is missing: $workflowPath"
}

$workflow = [IO.File]::ReadAllText($workflowPath).Replace("`r`n", "`n")
$requiredFragments = @(
  "pull_request:`n",
  "push:`n",
  "      - main`n",
  "repository: Kiwunaka/portal",
  "ref: master",
  "repository: Kiwunaka/pokrov-core",
  "ref: main",
  "fetch-depth: 0",
  "Materialize bound Core source authority",
  "client/config/runtime-artifacts.seed.json",
  '$boundCore',
  'diff --quiet $boundCore HEAD -- . ":(exclude).github/**"',
  "worktree add --detach",
  'POKROV-core-authority',
  "timeout-minutes: 45",
  "Reclaim unused runner disk",
  "sudo rm -rf -- /usr/share/dotnet",
  "sudo rm -rf -- /opt/ghc",
  "sudo rm -rf -- /usr/local/share/boost",
  "sudo rm -rf -- /opt/hostedtoolcache/CodeQL",
  "actions/setup-java@v4",
  "distribution: temurin",
  'java-version: "17"',
  "subosito/flutter-action@v2",
  'flutter-version: "3.38.5"',
  "./scripts/validate-seed.ps1",
  "-PlatformRoot",
  "-CoreRoot",
  "./scripts/run-tests.ps1"
)

foreach ($fragment in $requiredFragments) {
  if (-not $workflow.Contains($fragment)) {
    throw "Release-v2 CI workflow is missing required fragment: $fragment"
  }
}

foreach ($forbiddenFragment in @("allow-missing-client-root", "release_orchestrator.py", "deploy")) {
  if ($workflow.Contains($forbiddenFragment)) {
    throw "Release-v2 CI workflow contains forbidden mutation or skip fragment: $forbiddenFragment"
  }
}

$windowsGatePath = Join-Path $root "scripts\test-windows-exact-candidate.ps1"
$windowsGate = [IO.File]::ReadAllText($windowsGatePath).Replace("`r`n", "`n")
foreach ($fragment in @(
  'Get-SanitizedServiceFailureDiagnostics',
  'scm_exit_code',
  'service_specific_exit_code',
  'owner_sid_matches_runner',
  'event_journal_summary',
  'scm_event_ids',
  '$evidence.service_failure_diagnostics',
  'production_mutation_performed = $false',
  'public_release_created = $false',
  'stable_pointer_mutated = $false'
)) {
  if (-not $windowsGate.Contains($fragment)) {
    throw "Windows exact-candidate gate is missing sanitized failure evidence fragment: $fragment"
  }
}

foreach ($forbiddenFragment in @('event_message', 'owner_sid_value', 'registry_owner_sid')) {
  if ($windowsGate.Contains($forbiddenFragment)) {
    throw "Windows exact-candidate gate contains forbidden raw diagnostic fragment: $forbiddenFragment"
  }
}

$windowsBuilderPath = Join-Path $root "scripts\build-windows-release.ps1"
$windowsBuilder = [IO.File]::ReadAllText($windowsBuilderPath).Replace("`r`n", "`n")
foreach ($fragment in @(
  'procedure CurStepChanged(CurStep: TSetupStep);',
  'function ExecuteServiceCommand',
  'procedure AbortServiceSetup',
  'CreatedBySetup := not ServiceExists();',
  'create POKROVService binPath= "',
  'config POKROVService binPath= "',
  'POKROV_SERVICE_CREATE_FAILED',
  'POKROV_SERVICE_CONFIG_FAILED',
  'POKROV_SERVICE_DESCRIPTION_FAILED',
  'POKROV_SERVICE_RECOVERY_FAILED',
  'POKROV_SERVICE_START_FAILED',
  'RaiseException',
  'ResultCode = 0'
)) {
  if (-not $windowsBuilder.Contains($fragment)) {
    throw "Windows release builder lacks fail-closed SCM marker: $fragment"
  }
}

foreach ($forbiddenFragment in @(
  'Filename: "{sys}\sc.exe"; Parameters: "create POKROVService',
  'Filename: "{sys}\sc.exe"; Parameters: "config POKROVService',
  'Filename: "{sys}\sc.exe"; Parameters: "start POKROVService'
)) {
  if ($windowsBuilder.Contains($forbiddenFragment)) {
    throw "Windows release builder contains unchecked Inno [Run] SCM command: $forbiddenFragment"
  }
}

$seedValidatorPath = Join-Path $root "scripts\validate-seed.ps1"
$seedValidator = [IO.File]::ReadAllText($seedValidatorPath)
foreach ($requiredVersionGateFragment in @(
  '$releaseHandoff.latest_repo_backed_release',
  '$releaseHandoff.release_truth.development_target',
  '$publicUniversalArtifacts',
  '$requiredVersionFacts',
  '$platformVersionOwnerPaths',
  'config/release-handoff.seed.json',
  'Cross-repository version truth failed during seed validation'
)) {
  if (-not $seedValidator.Contains($requiredVersionGateFragment)) {
    throw "Release-v2 standard gate lacks cross-repository version marker: $requiredVersionGateFragment"
  }
}

foreach ($requiredRepositoryGateFragment in @(
  'test\\repository-hygiene-contract.ps1',
  'Repository hygiene contract failed during seed validation',
  'test\\release-rollback-catalog-contract.ps1',
  'Release rollback catalog contract failed during seed validation'
)) {
  if (-not $seedValidator.Contains($requiredRepositoryGateFragment)) {
    throw "Release-v2 standard gate lacks repository hygiene marker: $requiredRepositoryGateFragment"
  }
}

Write-Output "PASS: client release-v2 CI is strict and the Windows exact-candidate gate retains sanitized failure evidence."
