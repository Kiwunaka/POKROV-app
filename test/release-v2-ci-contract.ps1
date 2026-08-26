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

$windowsWorkflowPath = Join-Path $root ".github\workflows\windows-exact-candidate.yml"
$windowsWorkflow = [IO.File]::ReadAllText($windowsWorkflowPath).Replace("`r`n", "`n")
if (-not $windowsWorkflow.Contains("config/windows-clean-host-gate.candidate-2.json")) {
  throw "Windows exact-candidate workflow is not pinned to candidate.2"
}

$candidateTwoInputPath = Join-Path $root "config\windows-clean-host-gate.candidate-2.json"
if (-not (Test-Path -LiteralPath $candidateTwoInputPath -PathType Leaf)) {
  throw "Windows candidate.2 clean-host input is missing: $candidateTwoInputPath"
}

$candidateTwoInput = [IO.File]::ReadAllText($candidateTwoInputPath) | ConvertFrom-Json -Depth 20
$candidateTwoExpected = [ordered]@{
  candidate_label = "pokrov-1.2.0-candidate.2"
  candidate_manifest_sha256 = "1697a1bce4f72314aa1f60cd74a1711f9b8f7d70091c5757e98fbdc09b4ce5e0"
  candidate_manifest_signature_sha256 = "ebf259f1a9d3c9d561e3f39123c12804a178da5f15efcb293aeab47d45308a82"
  private_ci_release_tag = "pokrov-1.2.0-candidate.2-private-ci"
}
foreach ($entry in $candidateTwoExpected.GetEnumerator()) {
  if ([string]$candidateTwoInput.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.2 input has wrong $($entry.Key)"
  }
}

$candidateTwoSourceExpected = [ordered]@{
  client = "e6c29d1201eded0d045a3e75f43beff8ae24bd8f"
  core = "344b317a7a09eca7943a93866b193553538bd8f6"
  platform = "c5f3fca5c55d6baa48b54af3bf756ef40cc0e6e1"
  release_index = "4c6d46c10083e68dc5d2032c13f51c4e80a17049"
}
foreach ($entry in $candidateTwoSourceExpected.GetEnumerator()) {
  if ([string]$candidateTwoInput.source_tuple.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.2 input has wrong source tuple member $($entry.Key)"
  }
}

if (
  [string]$candidateTwoInput.artifact.sha256 -ne "4226daa49975cb25dae5bec8cbcd26299648ee89f5dbff613f62d807be0ac412" -or
  [int64]$candidateTwoInput.artifact.size_bytes -ne 28893114
) {
  throw "Windows candidate.2 input has wrong installer identity"
}

if (@($candidateTwoInput.installation.required_files).Count -ne 8) {
  throw "Windows candidate.2 input does not bind all eight installed files"
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
