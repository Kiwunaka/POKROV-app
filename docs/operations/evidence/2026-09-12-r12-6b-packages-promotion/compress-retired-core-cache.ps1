$ErrorActionPreference = 'Stop'
$taskOut = 'C:/r12-c05-setup-privacy-20260912'
$taskInventory = [IO.File]::ReadAllText("$taskOut/core-cache-inventory.json") | ConvertFrom-Json
$taskRoot = [IO.Path]::GetFullPath('E:/POKROV-workspace-cache/gradle-user-home/caches/8.11.1/transforms')
if ($taskInventory.root -ne $taskRoot) { throw 'Unexpected cache root' }
if (@(Get-Process java -ErrorAction SilentlyContinue).Count) { throw 'Gradle may still be active' }
$taskRetired = @($taskInventory.groups | Where-Object {-not $_.current_core})
if ($taskRetired.Count -ne 20) { throw 'Unexpected bounded cache inventory' }
foreach ($taskGroup in $taskRetired) {
    $taskPath = [IO.Path]::GetFullPath($taskGroup.directory)
    if ([IO.Path]::GetDirectoryName($taskPath) -ne $taskRoot -or [IO.Path]::GetFileName($taskPath) -notmatch '^[0-9a-f]{32}$') { throw 'Cache path outside intended scope' }
    $taskItems = @(Get-Item -LiteralPath $taskPath) + @(Get-ChildItem -LiteralPath $taskPath -Recurse -Force)
    if (@($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Cache reparse point' }
    $taskFiles = @($taskItems | Where-Object {-not $_.PSIsContainer})
    if ($taskFiles.Count -ne $taskGroup.files.Count) { throw 'Cache inventory changed' }
    foreach ($taskFile in $taskGroup.files) {
        $taskFilePath = Join-Path $taskRoot $taskFile.path
        if ((Get-FileHash -LiteralPath $taskFilePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'Cache bytes changed before compression' }
    }
}
$taskBefore = (Get-PSDrive E).Free
[Diagnostics.Process]::GetCurrentProcess().PriorityClass = 'BelowNormal'
foreach ($taskGroup in $taskRetired) {
    & compact.exe /C "/S:$($taskGroup.directory)" /I /Q *> "$taskOut/compact-$([IO.Path]::GetFileName($taskGroup.directory)).log"
    if ($LASTEXITCODE -ne 0) { throw 'NTFS compression failed; inspect exact cache log' }
}
foreach ($taskGroup in $taskInventory.groups) {
    foreach ($taskFile in $taskGroup.files) {
        $taskFilePath = Join-Path $taskRoot $taskFile.path
        if ((Get-FileHash -LiteralPath $taskFilePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'Cache bytes changed after compression' }
    }
}
$taskReceipt = @{status='PASS_ALL_CACHE_BYTES_UNCHANGED';retired_groups=$taskRetired.Count;current_groups_untouched=2;files_deleted=0;mechanism='NTFS file compression via compact.exe';free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;all_22_group_hashes_verified=$true;utc=[DateTime]::UtcNow.ToString('o')}
$taskReceipt | ConvertTo-Json | Set-Content "$taskOut/core-cache-compression.json"
$taskReceipt | ConvertTo-Json -Compress
