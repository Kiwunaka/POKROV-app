param([Parameter(Mandatory=$true)][string]$ExpectedSource)
$ErrorActionPreference='Stop'
$taskRoot='E:/r12client'
$taskOut='C:/r12-dart-crash-packages-20260912'
$env:JAVA_HOME='C:/Users/kiwun/tools/jdk/17.0.18'
$env:PATH='C:/Users/kiwun/tools/flutter/git-3.38.5/bin;'+$env:JAVA_HOME+'/bin;'+$env:PATH
$env:CMAKE_BUILD_PARALLEL_LEVEL='2'
$env:MSBUILDDISABLENODEREUSE='1'
if ((& git -C $taskRoot rev-parse HEAD).Trim() -ne $ExpectedSource) { throw 'Wrong Windows build source' }
& git -C $taskRoot diff --quiet HEAD --
if ($LASTEXITCODE -ne 0) { throw 'Tracked build source changed' }
$taskRetention=[IO.File]::ReadAllText("$taskOut/prior-package-retention.json")|ConvertFrom-Json
if ($taskRetention.status -ne 'PASS_PRIOR_PACKAGE_BYTES_RETAINED') { throw 'Prior outputs were not retained' }
foreach ($taskRow in @($taskRetention.files | Where-Object {$_.name -like 'pokrov-windows-*'})) {
  if ((Get-FileHash -LiteralPath $taskRow.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Previous Windows package changed' }
  $taskRemoteHash=(& ssh -o BatchMode=yes -o ConnectTimeout=8 pokrov-de "sha256sum $($taskRow.remote_path)")
  if ($LASTEXITCODE -ne 0 -or -not $taskRemoteHash.StartsWith($taskRow.remote_sha256+' ')) { throw 'Prior Windows remote verification failed' }
}
foreach ($taskRel in @('apps/windows_shell/build/windows','apps/windows_shell/build/native_assets/windows','apps/windows_shell/build/release_bundle')) {
  $taskResolved=[IO.Path]::GetFullPath((Join-Path $taskRoot $taskRel))
  if (-not $taskResolved.StartsWith('E:\r12client\apps\windows_shell\build\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Build path outside workspace' }
  if (Test-Path -LiteralPath $taskResolved) {
    $taskItems=@(Get-Item -LiteralPath $taskResolved)+@(Get-ChildItem -LiteralPath $taskResolved -Recurse -Force)
    if (@($taskItems|Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Build output reparse point' }
  }
}
# This build flow previously failed C1083 when Flutter reused its output cache.
# Preserve the current cache before rebuilding the cleared Windows output tree.
$taskCacheSource=[IO.Path]::GetFullPath('E:/r12client/apps/windows_shell/.dart_tool/flutter_build')
$taskCacheDestination=[IO.Path]::GetFullPath('E:/r12-dart-crash-prior-flutter-cache-20260912')
if ($taskCacheSource -ne 'E:\r12client\apps\windows_shell\.dart_tool\flutter_build' -or $taskCacheDestination -ne 'E:\r12-dart-crash-prior-flutter-cache-20260912') { throw 'Cache scope mismatch' }
if (Test-Path -LiteralPath $taskCacheDestination) { throw 'Retained cache destination already exists' }
$taskItems = @(Get-Item -LiteralPath $taskCacheSource) + @(Get-ChildItem -LiteralPath $taskCacheSource -Recurse -Force)
if (@($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Cache reparse point' }
$taskCacheRows=@(Get-ChildItem -LiteralPath $taskCacheSource -Recurse -File -Force | ForEach-Object { @{path=[IO.Path]::GetRelativePath($taskCacheSource,$_.FullName);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
Move-Item -LiteralPath $taskCacheSource -Destination $taskCacheDestination
foreach ($taskRow in $taskCacheRows) {
  $taskPath=Join-Path $taskCacheDestination $taskRow.path
  if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Moved cache readback mismatch' }
}
@{status='PASS_BYTES_PRESERVED';source=$taskCacheSource;destination=$taskCacheDestination;files=$taskCacheRows;reason='Prior C1083 with stale Flutter output cache'}|ConvertTo-Json -Depth 8|Set-Content "$taskOut/windows-cache-retention.json"
$taskPin=[IO.File]::ReadAllText('E:/r12-device-20260907/public-pins.json')|ConvertFrom-Json
& "$taskRoot/scripts/build-windows-release-reproducible.ps1" -CoreRoot C:/r12corec02 -OfflinePubGet -SkipValidateSeed -SkipAnalyze -SkipTests -EmergencySigningKeyId $taskPin.key_id -EmergencySigningPublicKey $taskPin.public_key_b64 *> "$taskOut/windows-build.log"
if ($LASTEXITCODE -ne 0) { throw 'Windows package build failed' }
Write-Output 'PASS Windows native build and installer; package audit remains separate'
