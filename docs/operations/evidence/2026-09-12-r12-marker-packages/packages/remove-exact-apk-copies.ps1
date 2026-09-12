$ErrorActionPreference='Stop'
$taskOut='C:/r12-marker-packages-20260912'
$taskRecord=[IO.File]::ReadAllText("$taskOut/direct-apks-verified.json")|ConvertFrom-Json
if ($taskRecord.status -ne 'PASS_FOUR_EXACT_DIRECT_APKS' -or $taskRecord.artifacts.Count -ne 4 -or $taskRecord.source_client -ne '8067520c7b9230ab0c66823fae9ae78791f1a838') { throw 'Unexpected APK proof' }
$taskBefore=(Get-PSDrive E).Free
foreach ($taskRow in $taskRecord.artifacts) {
 $taskKeep=[IO.Path]::GetFullPath($taskRow.path)
 $taskDuplicate=[IO.Path]::GetFullPath($taskRow.duplicate_path)
 if (-not $taskKeep.StartsWith('E:\r12client\apps\android_shell\build\app\outputs\flutter-apk\') -or -not $taskDuplicate.StartsWith('E:\r12client\apps\android_shell\build\app\outputs\apk\direct\release\')) { throw 'Unexpected APK scope' }
 foreach ($taskPath in @($taskKeep,$taskDuplicate)) {
  $taskItem=Get-Item -LiteralPath $taskPath
  if ($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Reparse point' }
  if ($taskItem.Length -ne $taskRow.size -or (Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'APK mismatch' }
 }
}
foreach ($taskRow in $taskRecord.artifacts) {
 Remove-Item -LiteralPath $taskRow.duplicate_path
 if ((Get-FileHash -LiteralPath $taskRow.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Retained APK changed' }
}
$taskResult=@{status='PASS_FOUR_EXACT_DUPLICATES_REMOVED';free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;retained_apks=$taskRecord.artifacts;utc=[DateTime]::UtcNow.ToString('o')}
$taskResult|ConvertTo-Json -Depth 8|Set-Content "$taskOut/direct-apk-duplicate-retention.json"
$taskResult|Select-Object status,free_e_before,free_e_after|ConvertTo-Json -Compress
