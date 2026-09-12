param([Parameter(Mandatory=$true)][string]$ExpectedSource)
$ErrorActionPreference='Stop'
$taskRoot='E:/r12client'
$taskOut='C:/r12-c05-wintun-20260912'
$env:JAVA_HOME='C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+$env:JAVA_HOME+'/bin;'+$env:PATH
$env:CMAKE_BUILD_PARALLEL_LEVEL='2'
$env:MSBUILDDISABLENODEREUSE='1'
if ((& git -C $taskRoot rev-parse HEAD).Trim() -ne $ExpectedSource) { throw 'Wrong Windows build source' }
& git -C $taskRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Tracked build source changed' }
$taskRetention=[IO.File]::ReadAllText("$taskOut/output-retention.json")|ConvertFrom-Json
if ($taskRetention.status -ne 'PASS_ALL_PREVIOUS_OUTPUT_BYTES_RETAINED') { throw 'Prior outputs have no verified copy' }
foreach ($taskRel in @('apps/windows_shell/build/windows','apps/windows_shell/build/native_assets/windows','apps/windows_shell/build/release_bundle')) {
  $taskResolved=[IO.Path]::GetFullPath((Join-Path $taskRoot $taskRel))
  if (-not $taskResolved.StartsWith('E:\r12client\apps\windows_shell\build\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Build path outside workspace' }
  if (Test-Path -LiteralPath $taskResolved) {
    $taskItems=@(Get-Item -LiteralPath $taskResolved)+@(Get-ChildItem -LiteralPath $taskResolved -Recurse -Force)
    if (@($taskItems|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Build output reparse point' }
  }
}
# The previous build failed after preserving its Flutter output cache: C1083.
# Preserve that exact cache again and force regeneration before the same build.
$taskCacheSource=[IO.Path]::GetFullPath('E:/r12client/apps/windows_shell/.dart_tool/flutter_build')
$taskCacheDestination=[IO.Path]::GetFullPath('E:/r12-c05-wintun-prior-flutter-cache-20260912')
if ($taskCacheSource -ne 'E:\r12client\apps\windows_shell\.dart_tool\flutter_build' -or $taskCacheDestination -ne 'E:\r12-c05-wintun-prior-flutter-cache-20260912') { throw 'Cache scope mismatch' }
if (Test-Path -LiteralPath $taskCacheDestination) { throw 'Retained cache destination already exists' }
$taskPlan=[IO.File]::ReadAllText("$taskOut/package-retention-plan.json")|ConvertFrom-Json
$taskCacheRows=@($taskPlan.files|Where-Object {$_.path.StartsWith('apps/windows_shell/.dart_tool/flutter_build/')})
if ($taskCacheRows.Count -ne 21) { throw 'Unexpected old cache inventory' }
foreach ($taskRow in $taskCacheRows) {
  $taskPath=Join-Path $taskRoot $taskRow.path
  if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Cache changed since remote retention' }
}
Move-Item -LiteralPath $taskCacheSource -Destination $taskCacheDestination
foreach ($taskRow in $taskCacheRows) {
  $taskRel=$taskRow.path.Substring('apps/windows_shell/.dart_tool/flutter_build/'.Length)
  $taskPath=Join-Path $taskCacheDestination $taskRel
  if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Moved cache readback mismatch' }
}
@{status='PASS_BYTES_PRESERVED';source=$taskCacheSource;destination=$taskCacheDestination;files=$taskCacheRows.Count;reason='Previous identical build flow failed C1083 with stale Flutter output cache'}|ConvertTo-Json|Set-Content "$taskOut/windows-cache-retention.json"
$taskPin=[IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json')|ConvertFrom-Json
& "$taskRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -OfflinePubGet -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/windows-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Windows package build failed' }
Write-Output 'PASS Windows native build and installer; package audit remains separate'
