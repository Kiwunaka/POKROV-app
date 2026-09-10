$ErrorActionPreference='Stop'
$taskRoot='E:/r12-observability-startup-source-20260910'
$env:JAVA_HOME='C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+$env:JAVA_HOME+'/bin;'+$env:PATH
$taskPin=[IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json')|ConvertFrom-Json
& "$taskRoot/scripts/bootstrap-workspace.ps1" -OfflinePubGet *> E:/r12-observability-startup-20260910/bootstrap.log
if($LASTEXITCODE -ne 0){throw 'Bootstrap failed'}
& "$taskRoot/scripts/sync-pokrov-core-runtime.ps1" -CoreRoot E:/r12core-implementation *> E:/r12-observability-startup-20260910/runtime-sync.log
if($LASTEXITCODE -ne 0){throw 'Runtime sync failed'}
& git -C $taskRoot diff --quiet HEAD --
if($LASTEXITCODE -ne 0){throw 'Build source dirty after bootstrap'}
Write-Output 'BOOTSTRAP_AND_SOURCE_PASS'
& "$taskRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot E:/r12core-implementation -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> E:/r12-observability-startup-20260910/windows-build.log
if($LASTEXITCODE -ne 0){throw 'Windows build failed'}
Write-Output 'WINDOWS_BUILD_PASS'
