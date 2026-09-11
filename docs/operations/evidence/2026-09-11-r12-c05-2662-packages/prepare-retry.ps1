$ErrorActionPreference='Stop'
$taskRoot='E:/r12client/apps/windows_shell'
$taskOut='E:/r12-c05-failed-build-20260911'
if (Test-Path -LiteralPath $taskOut) { throw 'Retry evidence already exists' }
$taskPaths=@('build/windows','build/native_assets/windows','.dart_tool/flutter_build')
$taskRows=@()
foreach($taskRel in $taskPaths) {
 $taskSource=[IO.Path]::GetFullPath((Join-Path $taskRoot $taskRel))
 $taskTarget=[IO.Path]::GetFullPath((Join-Path $taskOut $taskRel))
 if (-not $taskSource.StartsWith('E:\r12client\apps\windows_shell\',[StringComparison]::OrdinalIgnoreCase) -or -not $taskTarget.StartsWith('E:\r12-c05-failed-build-20260911\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside declared scope' }
 if(Test-Path -LiteralPath $taskSource){
  $taskAll=@(Get-ChildItem -LiteralPath $taskSource -Recurse -Force)
  if(@($taskAll | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count){throw 'Reparse point present'}
  $taskFiles=@($taskAll | Where-Object {-not $_.PSIsContainer} | ForEach-Object { @{path=[IO.Path]::GetRelativePath($taskSource,$_.FullName);bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
  $taskRows+=@{source=$taskSource;destination=$taskTarget;files=$taskFiles}
 }
}
$taskRows | ConvertTo-Json -Depth 8 | Set-Content C:/r12-c05-packages-20260911/retry-retention-plan.json
foreach($taskRow in $taskRows){
 New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($taskRow.destination)) -Force | Out-Null
 Move-Item -LiteralPath $taskRow.source -Destination $taskRow.destination
 foreach($taskFile in $taskRow.files){
  $taskRetained=Join-Path $taskRow.destination $taskFile.path
  if((Get-Item -LiteralPath $taskRetained).Length -ne $taskFile.bytes -or (Get-FileHash -LiteralPath $taskRetained -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256){throw 'Retained file mismatch'}
 }
}
@{status='PASS';reason='Windows C1083 missing generated wrapper sources; preserve failed outputs and invalidate stale Flutter output cache';files=@($taskRows.files).Count;entries=$taskRows} | ConvertTo-Json -Depth 9 | Set-Content C:/r12-c05-packages-20260911/retry-retention.json
$taskScript=[IO.File]::ReadAllText('C:/r12-c05-packages-20260911/build.ps1').Replace('build-progress.json','build-progress-retry.json').Replace('windows-build.log','windows-build-retry.log').Replace('android-build.log','android-build-retry.log')
[IO.File]::WriteAllText('C:/r12-c05-packages-20260911/build-retry.ps1',$taskScript)
Write-Output 'Retained and SHA256 verified all failed output/cache bytes; retry driver prepared.'
