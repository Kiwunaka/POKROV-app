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

$windowsWorkflowPath = Join-Path $root ".github\workflows\windows-exact-candidate.yml"
if (-not (Test-Path -LiteralPath $windowsWorkflowPath -PathType Leaf)) {
  throw "Windows exact-candidate CI workflow is missing: $windowsWorkflowPath"
}

$windowsWorkflow = [IO.File]::ReadAllText($windowsWorkflowPath).Replace("`r`n", "`n")
foreach ($fragment in @(
  'repos/$env:GITHUB_REPOSITORY/releases?per_page=100',
  '$_.tag_name -eq $gate.private_ci_release_tag',
  '$matchingReleases.Count -ne 1',
  '$matchingReleases[0].draft',
  '$matchingReleases[0].prerelease',
  '$_.name -eq $gate.artifact.file_name',
  '$matchingAssets.Count -ne 1',
  'Accept = "application/octet-stream"',
  'Invoke-WebRequest',
  '-OutFile $destination',
  './scripts/test-windows-exact-candidate.ps1',
  '-RunCleanHostSmoke'
)) {
  if (-not $windowsWorkflow.Contains($fragment)) {
    throw "Windows exact-candidate CI workflow is missing required fragment: $fragment"
  }
}

if ($windowsWorkflow.Contains('gh release download')) {
  throw "Windows exact-candidate CI workflow must not use the published-tag-only download path for its draft carrier."
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

Write-Output "PASS: client release-v2 CI is strict and the Windows exact-candidate workflow resolves one private draft asset fail closed."
