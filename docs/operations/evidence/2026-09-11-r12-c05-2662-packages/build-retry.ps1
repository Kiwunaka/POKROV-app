$ErrorActionPreference = 'Stop'
$taskRoot = 'E:/r12client'
$taskOut = 'C:/r12-c05-packages-20260911'
$taskExpected = '212bd2f30c9f91d80fd3a6c08fb5557be8457f1c'
$env:JAVA_HOME = 'C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH = 'C:/Users/kiwun/tools/flutter/git-3.38.5/bin;' + $env:JAVA_HOME + '/bin;' + $env:PATH
$taskPin = [IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json') | ConvertFrom-Json
if ((& git -C $taskRoot rev-parse HEAD).Trim() -ne $taskExpected) { throw 'Wrong package source' }
& git -C $taskRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Tracked build source changed' }
$taskRetention = [IO.File]::ReadAllText("$taskOut/output-retention.json") | ConvertFrom-Json
if ($taskRetention.status -ne 'PASS_ALL_PREVIOUS_OUTPUT_BYTES_RETAINED') { throw 'Prior outputs were not retained' }
foreach ($taskPath in @('apps/windows_shell/build/windows','apps/windows_shell/build/native_assets/windows','apps/windows_shell/build/release_bundle')) {
  $taskResolved = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskPath))
  if (-not $taskResolved.StartsWith('E:\r12client\apps\windows_shell\build\', [StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $taskResolved)) { throw 'Windows clean-build path is not empty inside the declared workspace' }
}
$taskProgress = [ordered]@{ source_commit=$taskExpected; process_id=$PID; status='RUNNING'; stage='windows'; started_utc=[DateTime]::UtcNow.ToString('o'); commands=@(); production_deploy=$false; publication=$false }
function Save-TaskProgress { $taskProgress | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath "$taskOut/build-progress-retry.json" -Encoding utf8 }
Save-TaskProgress
try {
  if ((Get-Volume -DriveLetter C).SizeRemaining -lt 40GB -or (Get-Volume -DriveLetter E).SizeRemaining -lt (40GB + 2GB)) { throw 'Package storage floor unavailable' }
  $taskTimer = [Diagnostics.Stopwatch]::StartNew()
  & "$taskRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -OfflinePubGet -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/windows-build-retry.log"
  if ($LASTEXITCODE -ne 0) { throw 'Windows package build failed' }
  $taskProgress.commands += @{ lane='windows'; exit=0; elapsed_seconds=$taskTimer.Elapsed.TotalSeconds; skipped_local_checks='Already passed current binding runtime81/Android8/seed/docs; exact PR CI runs full checks separately' }
  $taskProgress.stage='android'; Save-TaskProgress
  if ((Get-Volume -DriveLetter C).SizeRemaining -lt 40GB -or (Get-Volume -DriveLetter E).SizeRemaining -lt (40GB + 1GB)) { throw 'Android package storage floor unavailable' }
  $taskTimer.Restart()
  & "$taskRoot/scripts/build-android-production.ps1" -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/android-build-retry.log"
  if ($LASTEXITCODE -ne 0) { throw 'Android package build failed' }
  $taskProgress.commands += @{ lane='android'; exit=0; elapsed_seconds=$taskTimer.Elapsed.TotalSeconds }
  $taskProgress.status='PASS'
} catch {
  $taskProgress.status='FAILED'
  $taskProgress.error_type=$_.Exception.GetType().Name
  throw
} finally {
  $taskProgress.finished_utc=[DateTime]::UtcNow.ToString('o')
  Save-TaskProgress
}
