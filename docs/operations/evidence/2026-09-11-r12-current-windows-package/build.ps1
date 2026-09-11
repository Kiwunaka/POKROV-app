$ErrorActionPreference='Stop'
$source='C:/r12-current-windows-source-20260911'
$out='E:/r12-current-windows-package-20260911'
$env:PATH='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+$env:PATH
if((& git -C $source rev-parse HEAD).Trim() -ne 'd9763e8cd7aba9b215015e07c0576f667c1dec09'){throw 'Wrong exact client source'}
& "$source/scripts/sync-pokrov-core-runtime.ps1" -CoreRoot C:/r12corec02 -Platforms @("android", "windows") *> "$out/sync-runtime.log"
if(-not $?){throw 'Exact runtime sync failed'}
& "$source/scripts/validate-seed.ps1" -CoreRoot C:/r12corec02 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start *> "$out/validate-seed.log"
if(-not $? -or $LASTEXITCODE -ne 0){throw 'Seed validation failed'}
& git -C $source diff --quiet HEAD --
if($LASTEXITCODE -ne 0){throw 'Source changed before compile'}
Write-Output 'EXACT_RUNTIME_SEED_SOURCE_PASS'
$pin=[IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json') | ConvertFrom-Json
& "$source/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -OfflinePubGet -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $pin.key_id -EmergencySigningPublicKey $pin.public_key_b64 *> "$out/build.log"
if(-not $? -or $LASTEXITCODE -ne 0){throw 'Windows build failed'}
& E:/r12-disk-cleanup-20260911/check-disk-budget.ps1 -ExpectedGrowthCGiB 0 -ExpectedGrowthEGiB 0 > "$out/disk-budget-after-build.json"
Write-Output 'CURRENT_WINDOWS_PACKAGE_BUILD_PASS'
