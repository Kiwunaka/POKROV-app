$ErrorActionPreference = 'Stop'
$packageRoot = 'E:/r12-n05-windows-source-20260911'
$packageOut = 'E:/r12-windows-observations-package-20260911'
$env:PATH = 'C:/Users/kiwun/tools/flutter/git-3.38.5/bin;' + $env:PATH
if ((& git -C $packageRoot rev-parse HEAD).Trim() -ne '7ed18c97c43ba39ce18701220d487af1b0c5a446') { throw 'Wrong package source' }
& E:/r12-disk-cleanup-20260911/check-disk-budget.ps1 -ExpectedGrowthCGiB 1 -ExpectedGrowthEGiB 2 > "$packageOut/disk-budget-build.json"
$packagePin = [IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json') | ConvertFrom-Json
& git -C $packageRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Source changed during bootstrap' }
Write-Output 'BOOTSTRAP_AND_SOURCE_PASS'
& "$packageRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -OfflinePubGet -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $packagePin.key_id -EmergencySigningPublicKey $packagePin.public_key_b64 *> "$packageOut/windows-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Windows package build failed' }
Write-Output 'WINDOWS_BUILD_PASS'
