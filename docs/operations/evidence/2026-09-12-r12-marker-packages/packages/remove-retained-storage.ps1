$ErrorActionPreference='Stop'
$taskOut='C:/r12-marker-packages-20260912'
$taskProof=[IO.File]::ReadAllText("$taskOut/storage-retention.json")|ConvertFrom-Json
if ($taskProof.status -ne 'PASS_RETAINED_AND_HASH_VERIFIED_BEFORE_REMOVAL' -or $taskProof.local_deleted -or $taskProof.files.Count -ne 17) { throw 'Wrong retention receipt' }
if (Get-Process java,dart -ErrorAction SilentlyContinue) { throw 'Build is running' }
$taskAllowed=@('E:\r12client\apps\android_shell\build\app\intermediates\merged_native_libs\storeRelease\','E:\r12client\apps\android_shell\build\app\intermediates\intermediary_bundle\storeRelease\','E:\r12client\apps\android_shell\build\app\intermediates\module_bundle\storeRelease\','E:\r12client\apps\android_shell\build\app\outputs\flutter-apk\','E:\r12client\apps\android_shell\build\app\outputs\bundle\storeRelease\')
foreach ($taskRow in $taskProof.files) {
 $taskPath=[IO.Path]::GetFullPath($taskRow.path)
 if (-not ($taskAllowed | Where-Object { $taskPath.StartsWith($_,[StringComparison]::OrdinalIgnoreCase) })) { throw 'Out of scoped directories' }
 $taskItem=Get-Item -LiteralPath $taskPath
 if (($taskItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $taskItem.PSIsContainer) { throw 'Not a regular retained file' }
 if ($taskItem.Length -ne $taskRow.bytes -or (Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256) { throw 'Retention source mismatch' }
}
$taskBefore=(Get-PSDrive E).Free
foreach ($taskRow in $taskProof.files) { Remove-Item -LiteralPath $taskRow.path }
$taskResult=@{status='PASS_17_EXACT_RETAINED_FILES_REMOVED';retention_sha256=(Get-FileHash -LiteralPath "$taskOut/storage-retention.json" -Algorithm SHA256).Hash.ToLowerInvariant();free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;utc=[DateTime]::UtcNow.ToString('o');files=$taskProof.files}
$taskResult|ConvertTo-Json -Depth 8|Set-Content -LiteralPath "$taskOut/storage-removal.json"
$taskResult|Select-Object status,free_e_before,free_e_after|ConvertTo-Json -Compress
foreach ($taskName in @('android-direct-build.log','android-direct-driver.log','android-direct-progress.json')) {
 $taskTarget="$taskOut/stopped-$taskName"
 if (Test-Path -LiteralPath $taskTarget) { throw 'Stop evidence already retained' }
 Copy-Item -LiteralPath "$taskOut/$taskName" -Destination $taskTarget
 if ((Get-FileHash -LiteralPath "$taskOut/$taskName").Hash -ne (Get-FileHash -LiteralPath $taskTarget).Hash) { throw 'Stop evidence mismatch' }
}
