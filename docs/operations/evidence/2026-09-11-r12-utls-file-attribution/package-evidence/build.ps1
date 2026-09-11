$ErrorActionPreference = 'Stop'
$taskRoot = 'E:/r12utls'
$taskOut = 'E:/r12-c05-utls-license-20260911'
$env:JAVA_HOME = 'C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH = 'C:/Users/kiwun/tools/flutter/git-3.38.5/bin;' + $env:JAVA_HOME + '/bin;' + $env:PATH
$taskPin = [IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json') | ConvertFrom-Json
$taskExpected = 'a24b211f9c1c4bf83bb5fde9b8a9c98185ea1028'
if ((& git -C $taskRoot rev-parse HEAD).Trim() -ne $taskExpected) { throw 'Wrong build source' }
& "$taskRoot/scripts/bootstrap-workspace.ps1" -OfflinePubGet *> "$taskOut/bootstrap.log"
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap failed' }
& "$taskRoot/scripts/sync-pokrov-core-runtime.ps1" -CoreRoot C:/r12corec02 *> "$taskOut/runtime-sync.log"
if ($LASTEXITCODE -ne 0) { throw 'Runtime sync failed' }
& git -C $taskRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Build source changed during bootstrap' }
Write-Output 'BOOTSTRAP_AND_SOURCE_PASS'
& "$taskRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/windows-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Windows package build failed' }
Write-Output 'WINDOWS_BUILD_PASS'
& "$taskRoot/scripts/build-android-production.ps1" -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/android-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Android package build failed' }
Write-Output 'ANDROID_BUILD_PASS'
