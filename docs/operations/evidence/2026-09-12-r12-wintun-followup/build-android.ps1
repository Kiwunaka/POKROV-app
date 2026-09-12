param([Parameter(Mandatory=$true)][string]$ExpectedSource)
$ErrorActionPreference='Stop'
$taskRoot='E:/r12client'
$taskOut='C:/r12-c05-wintun-20260912'
$env:JAVA_HOME='C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+$env:JAVA_HOME+'/bin;'+$env:PATH
if ((& git -C $taskRoot rev-parse HEAD).Trim() -ne $ExpectedSource) { throw 'Wrong Android build source' }
& git -C $taskRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Tracked Android build source changed' }
$taskRetention=[IO.File]::ReadAllText("$taskOut/android-output-preparation.json")|ConvertFrom-Json
if ($taskRetention.status -ne 'PASS_OLD_BUILD_OUTPUTS_RETAINED_REMOTELY') { throw 'Prior outputs were not retained' }
$taskPin=[IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json')|ConvertFrom-Json
& "$taskRoot/scripts/build-android-production.ps1" -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/android-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Android package build failed' }
Write-Output 'PASS Android production-signed package build; content audit remains separate'
