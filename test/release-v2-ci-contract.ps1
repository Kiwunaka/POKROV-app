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
  "actions/setup-go@v5",
  'go-version: "1.25.13"',
  "client/apps/linux_shell/daemon/go.mod",
  "subosito/flutter-action@v2",
  'flutter-version: "3.38.5"',
  "./scripts/validate-seed.ps1",
  "-PlatformRoot",
  "-CoreRoot",
  "./scripts/run-tests.ps1",
  "Validate conditional Linux daemon foundation",
  'gofmt -l $(find . -type f -name ''*.go'')',
  "go test ./...",
  "go vet ./...",
  "go build -trimpath"
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
  'RunOwnerCurrentHostSmoke',
  'OWNER_AUTHORIZED_CURRENT_HOST_CANDIDATE8_SMOKE',
  'OWNER_AUTHORIZED_CURRENT_HOST_CANDIDATE16_SMOKE',
  'clean_app_state_only_not_clean_os_or_vm',
  'PASS_EXACT_CANDIDATE_CURRENT_HOST_CLEAN_APP_STATE_INSTALL_SERVICE_IPC_RESTART_UNINSTALL_IDLE_NETWORK',
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
if (-not $windowsWorkflow.Contains("config/windows-clean-host-gate.candidate-3.json")) {
  throw "Windows exact-candidate workflow is not pinned to candidate.3"
}

$candidateThreeInputPath = Join-Path $root "config\windows-clean-host-gate.candidate-3.json"
if (-not (Test-Path -LiteralPath $candidateThreeInputPath -PathType Leaf)) {
  throw "Windows candidate.3 clean-host input is missing: $candidateThreeInputPath"
}

$candidateThreeInput = [IO.File]::ReadAllText($candidateThreeInputPath) | ConvertFrom-Json -Depth 20
$candidateThreeExpected = [ordered]@{
  candidate_label = "pokrov-1.2.0-candidate.3"
  candidate_manifest_sha256 = "a2752b6a3b95faacf13a68edb708c560966a0f5eb8727e109d7f1603fdc81090"
  candidate_manifest_signature_sha256 = "926f0b4667a58ba9cc5ace5c4e6c3c8129d1ec3d4d449b3f0831a8c527cd7121"
  private_ci_release_tag = "pokrov-1.2.0-candidate.3-private-ci"
}
foreach ($entry in $candidateThreeExpected.GetEnumerator()) {
  if ([string]$candidateThreeInput.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.3 input has wrong $($entry.Key)"
  }
}

$candidateThreeSourceExpected = [ordered]@{
  client = "ac22825e857a313c9e4eba61030eb548d6346ead"
  core = "344b317a7a09eca7943a93866b193553538bd8f6"
  platform = "eafaca3e64c0619dea7f58fc9c430682b4520559"
  release_index = "6a1afa95fe52da2d559ba7b1da88715cd0344bb2"
}
foreach ($entry in $candidateThreeSourceExpected.GetEnumerator()) {
  if ([string]$candidateThreeInput.source_tuple.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.3 input has wrong source tuple member $($entry.Key)"
  }
}

if (
  [string]$candidateThreeInput.artifact.sha256 -ne "9962e3e80947dae374619ed388fc08b7322bffda38202a42e5812597c7818021" -or
  [int64]$candidateThreeInput.artifact.size_bytes -ne 28898240
) {
  throw "Windows candidate.3 input has wrong installer identity"
}

if (@($candidateThreeInput.installation.required_files).Count -ne 8) {
  throw "Windows candidate.3 input does not bind all eight installed files"
}

$candidateThreeRequiredFiles = [ordered]@{
  "pokrov_windows.exe" = "191488|fd5059c1e43b1a8e21ba8627911916f21bbda435529dff610b9219f38d3efdca"
  "pokrov_service.exe" = "168960|0cb21283cf16648dcdba8c31d7660641550b1a5ff962ce2b80c3eb5f98ff7b04"
  "flutter_windows.dll" = "18511872|1f4215e1072dd9e34f4565b74310e6771364e1470c7e92214bca64947bd012a1"
  "pokrov-core.dll" = "55401472|60fe3fad7835ec4d00c1f7168bb0ba01dd6b7ca5d883583340e5e2a86b8b3981"
  "libcronet.dll" = "8596992|8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7"
  "pokrov_tray.ico" = "110013|9eea4eff6f980edda2b9c61f3d86fa63e6349bed23bc83e09d5fbb3274d9575d"
  "data/app.so" = "8881072|83d598b90f84275e9dfb5f411183d18dd926548524fb6cc2c1e1a22f5e34bd25"
  "data/icudtl.dat" = "778864|c12537022ef818991a7bfed41a76d8d6ae962ffbc0e6511ac762a5d0845e7f7c"
}
foreach ($requiredFile in @($candidateThreeInput.installation.required_files)) {
  $expectedIdentity = $candidateThreeRequiredFiles[[string]$requiredFile.path]
  $actualIdentity = "$([int64]$requiredFile.size_bytes)|$([string]$requiredFile.sha256)"
  if ([string]::IsNullOrWhiteSpace($expectedIdentity) -or $actualIdentity -ne $expectedIdentity) {
    throw "Windows candidate.3 input has wrong installed-file identity for $($requiredFile.path)"
  }
}

$candidateEightInputPath = Join-Path $root "config\windows-clean-host-gate.candidate-8.json"
if (-not (Test-Path -LiteralPath $candidateEightInputPath -PathType Leaf)) {
  throw "Windows candidate.8 current-host input is missing: $candidateEightInputPath"
}

$candidateEightInput = [IO.File]::ReadAllText($candidateEightInputPath) | ConvertFrom-Json -Depth 20
$candidateEightExpected = [ordered]@{
  candidate_label = "pokrov-1.2.0-candidate.8"
  candidate_manifest_sha256 = "f0006cec90c84e401e9920d9098102c7f50ab5ace5242e0d7683c3df709a6fbc"
  candidate_manifest_signature_sha256 = "5fcae0675ea45e79baf495859fd170661f5d6dd3a8535275acd4d62680d324f6"
}
foreach ($entry in $candidateEightExpected.GetEnumerator()) {
  if ([string]$candidateEightInput.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.8 input has wrong $($entry.Key)"
  }
}
if ($null -ne $candidateEightInput.private_ci_release_tag) {
  throw "Windows candidate.8 input must not claim a private CI carrier"
}

$candidateEightSourceExpected = [ordered]@{
  client = "3459438f02bd774e722b1b858e7f7f16d57a9f5c"
  core = "a45d69e40ed7d892619a2b5c4592a527f630665e"
  platform = "241a83b4dca00799b39696a4ae0c3c97e087ec39"
  release_index = "b242e0a3060b04f9b71641a0524bf251a75ce2a8"
}
foreach ($entry in $candidateEightSourceExpected.GetEnumerator()) {
  if ([string]$candidateEightInput.source_tuple.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.8 input has wrong source tuple member $($entry.Key)"
  }
}

if (
  [string]$candidateEightInput.artifact.sha256 -ne "26ec26d8989d61415f07cbf9707f336ebba0b947fa4ba0ee93d3078fa3984668" -or
  [int64]$candidateEightInput.artifact.size_bytes -ne 28929376
) {
  throw "Windows candidate.8 input has wrong installer identity"
}

if (@($candidateEightInput.installation.required_files).Count -ne 8) {
  throw "Windows candidate.8 input does not bind all eight installed files"
}

$candidateEightRequiredFiles = [ordered]@{
  "pokrov_windows.exe" = "191488|83e8c88a061bd2849b5858a2693ce516bf1eb775f9a789c9ba03e8edca4f755f"
  "pokrov_service.exe" = "168960|64e6d7b26d326147e8c30c8595fd719fe3c62a4186dc1a6bf121540eb8f4b2c2"
  "flutter_windows.dll" = "18511872|1f4215e1072dd9e34f4565b74310e6771364e1470c7e92214bca64947bd012a1"
  "pokrov-core.dll" = "55426048|53b5e82a9c7bc20055c0889a1c8fabb5137f52ad09d38b23cf86477184474652"
  "libcronet.dll" = "8596992|8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7"
  "pokrov_tray.ico" = "110013|9eea4eff6f980edda2b9c61f3d86fa63e6349bed23bc83e09d5fbb3274d9575d"
  "data/app.so" = "8913840|5af656624a95cc7e9c7ef5bdda9b45645aa1fad9e599672732df17beaa6f0a18"
  "data/icudtl.dat" = "778864|c12537022ef818991a7bfed41a76d8d6ae962ffbc0e6511ac762a5d0845e7f7c"
}
foreach ($requiredFile in @($candidateEightInput.installation.required_files)) {
  $expectedIdentity = $candidateEightRequiredFiles[[string]$requiredFile.path]
  $actualIdentity = "$([int64]$requiredFile.size_bytes)|$([string]$requiredFile.sha256)"
  if ([string]::IsNullOrWhiteSpace($expectedIdentity) -or $actualIdentity -ne $expectedIdentity) {
    throw "Windows candidate.8 input has wrong installed-file identity for $($requiredFile.path)"
  }
}

$candidateSixteenInputPath = Join-Path $root "config\windows-clean-host-gate.candidate-16.json"
if (-not (Test-Path -LiteralPath $candidateSixteenInputPath -PathType Leaf)) {
  throw "Windows candidate.16 current-host input is missing: $candidateSixteenInputPath"
}

$candidateSixteenInput = [IO.File]::ReadAllText($candidateSixteenInputPath) | ConvertFrom-Json -Depth 20
$candidateSixteenExpected = [ordered]@{
  candidate_label = "pokrov-1.2.0-candidate.16"
  candidate_manifest_sha256 = "ae1906e68df755b1e0ce6a77d6ede8256f923e72fe11da57f1cae89a82c4ffe6"
  candidate_manifest_signature_sha256 = "f5df63578d56db84a48eac1c68f1192e81462e8b407b1b6ff877c2b415507a9a"
}
foreach ($entry in $candidateSixteenExpected.GetEnumerator()) {
  if ([string]$candidateSixteenInput.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.16 input has wrong $($entry.Key)"
  }
}
if ($null -ne $candidateSixteenInput.private_ci_release_tag) {
  throw "Windows candidate.16 input must not claim a private CI carrier"
}

$candidateSixteenSourceExpected = [ordered]@{
  client = "75ba7e721cfee486f7189edd51de97aba2746722"
  core = "cd8f0f4169d570d693992a959d81d17c2c44884d"
  platform = "719e23dc49407beb9ae30d98d17d4b73d18ae37c"
  release_index = "54cfa03502ffafa5e4fb230a2cbdb0c0572c429f"
}
foreach ($entry in $candidateSixteenSourceExpected.GetEnumerator()) {
  if ([string]$candidateSixteenInput.source_tuple.($entry.Key) -ne [string]$entry.Value) {
    throw "Windows candidate.16 input has wrong source tuple member $($entry.Key)"
  }
}

if (
  [string]$candidateSixteenInput.artifact.sha256 -ne "0afaf6e1d73a7e72762d945557f48793646a9bdbf12bb8ca2e843d4b94df276c" -or
  [int64]$candidateSixteenInput.artifact.size_bytes -ne 28932793
) {
  throw "Windows candidate.16 input has wrong installer identity"
}

if (@($candidateSixteenInput.installation.required_files).Count -ne 8) {
  throw "Windows candidate.16 input does not bind all eight installed files"
}

$candidateSixteenRequiredFiles = [ordered]@{
  "pokrov_windows.exe" = "191488|322684678534cd09cba2cb284317b4f49a4e6a5909605aa0c4b138a7aa11f985"
  "pokrov_service.exe" = "168960|d6e4efd71d7fb13ae523a4fcaeb5da076270f47009cdcb105202afef4fb49510"
  "flutter_windows.dll" = "18511872|1f4215e1072dd9e34f4565b74310e6771364e1470c7e92214bca64947bd012a1"
  "pokrov-core.dll" = "55426048|f284fa8841f1a45271874a7a05ed6093fb0e3efbdd03e00001edd046be708204"
  "libcronet.dll" = "8596992|8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7"
  "pokrov_tray.ico" = "110013|9eea4eff6f980edda2b9c61f3d86fa63e6349bed23bc83e09d5fbb3274d9575d"
  "data/app.so" = "8930224|26b9cb836331e15be38247407be0eecf14b468f9f0a329ef0156f25b5f59f364"
  "data/icudtl.dat" = "778864|c12537022ef818991a7bfed41a76d8d6ae962ffbc0e6511ac762a5d0845e7f7c"
}
foreach ($requiredFile in @($candidateSixteenInput.installation.required_files)) {
  $expectedIdentity = $candidateSixteenRequiredFiles[[string]$requiredFile.path]
  $actualIdentity = "$([int64]$requiredFile.size_bytes)|$([string]$requiredFile.sha256)"
  if ([string]::IsNullOrWhiteSpace($expectedIdentity) -or $actualIdentity -ne $expectedIdentity) {
    throw "Windows candidate.16 input has wrong installed-file identity for $($requiredFile.path)"
  }
}

$windowsBuilderPath = Join-Path $root "scripts\build-windows-release.ps1"
$windowsBuilder = [IO.File]::ReadAllText($windowsBuilderPath).Replace("`r`n", "`n")
foreach ($fragment in @(
  '$versionParityArguments.CoreRoot = $CoreRoot',
  '$validateSeedArguments.CoreRoot = $CoreRoot',
  '$runtimeMissingFiles = @(',
  '$missingBuildFiles = @('
)) {
  if (-not $windowsBuilder.Contains($fragment)) {
    throw "Windows release builder does not forward exact Core authority: $fragment"
  }
}
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
