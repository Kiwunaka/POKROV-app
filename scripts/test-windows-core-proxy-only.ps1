[CmdletBinding()]
param(
    [string]$CoreRoot = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimePackage = Join-Path $repoRoot "packages\runtime_engine"
if (-not $CoreRoot) {
    $CoreRoot = Join-Path $repoRoot "apps\windows_shell\windows\runner\resources\runtime"
}

$resolvedCoreRoot = (Resolve-Path -LiteralPath $CoreRoot).Path
$coreDll = Join-Path $resolvedCoreRoot "pokrov-core.dll"
if (-not (Test-Path -LiteralPath $coreDll -PathType Leaf)) {
    throw "pokrov-core.dll was not found under the requested runtime root."
}

$previousCoreRoot = $env:POKROV_REAL_CORE_ROOT
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
$testTemp = Join-Path ([IO.Path]::GetTempPath()) ("pokrov-core-proxy-" + [guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($testTemp) | Out-Null
try {
    # The headless host falls back to TEMP for runtime storage. Isolate its
    # database from previous tests; retain it for inspection after the run.
    $env:TEMP = $testTemp
    $env:TMP = $testTemp
    $env:POKROV_REAL_CORE_ROOT = $resolvedCoreRoot
    Push-Location $runtimePackage
    try {
        & flutter test test\runtime_engine_test.dart --plain-name "real Windows POKROV Core 1.1.0 survives 100 start-stop cycles"
        if ($LASTEXITCODE -ne 0) {
            throw "Proxy-only Windows Core smoke failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    $env:POKROV_REAL_CORE_ROOT = $previousCoreRoot
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
}

Write-Output "PASS: exact Windows Core completed 100 proxy-only start/stop cycles without changing system routes."
Write-Output "NOTE: this does not prove Windows TUN, DNS capture, or leak protection; run those in an isolated VM or Windows Sandbox."
