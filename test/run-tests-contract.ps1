[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $root "scripts\run-tests.ps1"
$bootstrapPath = Join-Path $root "scripts\bootstrap-workspace.ps1"
$observabilityValidatorPath = Join-Path $root "scripts\validate-observability-contracts.ps1"
$handoffGeneratorPath = Join-Path $root "scripts\new-release-handoff-v2.ps1"

foreach ($path in @($runnerPath, $bootstrapPath, $observabilityValidatorPath, $handoffGeneratorPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Standard client test source is missing: $path"
  }
}

$runner = [IO.File]::ReadAllText($runnerPath).Replace("`r`n", "`n")
$bootstrap = [IO.File]::ReadAllText($bootstrapPath).Replace("`r`n", "`n")
$observabilityValidator = [IO.File]::ReadAllText($observabilityValidatorPath).Replace("`r`n", "`n")
$handoffGenerator = [IO.File]::ReadAllText($handoffGeneratorPath).Replace("`r`n", "`n")

$requiredPackages = @(
  "packages\\core_domain",
  "packages\\platform_contracts",
  "packages\\observability_contracts",
  "packages\\observability_runtime",
  "packages\\diagnostics_collectors",
  "packages\\support_bundle",
  "packages\\support_context",
  "packages\\runtime_engine",
  "packages\\app_shell",
  "apps\\android_shell",
  "apps\\windows_shell"
)

foreach ($relativePath in $requiredPackages) {
  if (-not $runner.Contains('"' + $relativePath + '"')) {
    throw "Standard client runner omits test module: $relativePath"
  }
}

$runnerFragments = @(
  '$IsWindows',
  '$hasTests',
  '"test"',
  '"analyze"',
  '"gradlew.bat"',
  '"gradlew"',
  'chmod +x',
  ':app:testDirectDebugUnitTest',
  ':app:testStoreDebugUnitTest'
)
foreach ($fragment in $runnerFragments) {
  if (-not $runner.Contains($fragment)) {
    throw "Standard client runner is missing platform or flavor fragment: $fragment"
  }
}

foreach ($fragment in @('"android\gradlew"', '"android\gradlew.bat"', 'chmod +x')) {
  if (-not $bootstrap.Contains($fragment)) {
    throw "Workspace bootstrap is missing cross-platform wrapper fragment: $fragment"
  }
}

foreach ($scriptSource in @($observabilityValidator, $handoffGenerator)) {
  if ($scriptSource.Contains("python.exe")) {
    throw "Cross-platform client validation must not hard-code python.exe."
  }
  if (-not $scriptSource.Contains("Get-Command python")) {
    throw "Cross-platform client validation must resolve Python from PATH."
  }
}

Write-Output "PASS: standard client gate analyzes testless modules, tests all test-bearing modules and both Android flavors, and resolves Gradle and Python tools on Windows/Linux."
