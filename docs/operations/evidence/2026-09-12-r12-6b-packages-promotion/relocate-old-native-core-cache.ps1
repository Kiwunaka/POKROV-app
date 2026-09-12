$ErrorActionPreference = 'Stop'
$taskOut = 'C:/r12-c05-setup-privacy-20260912'
$taskPlan = [IO.File]::ReadAllText("$taskOut/old-native-core-cache-retention-plan.json") | ConvertFrom-Json
$taskReceipt = [IO.File]::ReadAllText("$taskOut/old-native-core-cache-retention.json") | ConvertFrom-Json
if ($taskReceipt.status -ne 'PASS_EXACT_RETIRED_NATIVE_CORE_CACHE_ARCHIVE' -or $taskReceipt.files -ne 100 -or $taskPlan.groups.Count -ne 10) { throw 'Exact archive verification missing' }
$taskRoot = [IO.Path]::GetFullPath('E:/POKROV-workspace-cache/gradle-user-home/caches/8.11.1/transforms')
if ($taskPlan.root -ne $taskRoot) { throw 'Unexpected cache root' }
if (@(Get-Process java -ErrorAction SilentlyContinue).Count) { throw 'Gradle may still be active' }
$taskRemoteHash = (& ssh -o BatchMode=yes -o ConnectTimeout=8 pokrov-de "sha256sum $($taskReceipt.archive)")
if ($LASTEXITCODE -ne 0 -or -not $taskRemoteHash.StartsWith($taskReceipt.archive_sha256+' ')) { throw 'Retained archive changed' }
foreach ($taskGroup in $taskPlan.groups) {
    $taskDirectory = [IO.Path]::GetFullPath($taskGroup.directory)
    if ([IO.Path]::GetDirectoryName($taskDirectory) -ne $taskRoot -or [IO.Path]::GetFileName($taskDirectory) -notmatch '^[0-9a-f]{32}$' -or $taskGroup.current_core -or $taskGroup.kind -ne 'extracted_core') { throw 'Unexpected transform scope' }
    $taskItems = @(Get-Item -LiteralPath $taskDirectory) + @(Get-ChildItem -LiteralPath $taskDirectory -Recurse -Force)
    if (@($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Cache reparse point' }
    $taskPaths = @($taskItems | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName} | Sort-Object)
    $taskExpected = @($taskGroup.files | ForEach-Object {[IO.Path]::GetFullPath((Join-Path $taskRoot $_.path))} | Sort-Object)
    if (($taskPaths -join "`n") -ne ($taskExpected -join "`n")) { throw 'Transform file set changed' }
    foreach ($taskFile in $taskGroup.files) {
        $taskPath = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskFile.path))
        if (-not $taskPath.StartsWith($taskDirectory+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'File outside selected transform' }
        if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'Cache file changed since archive' }
    }
}
$taskBefore = (Get-PSDrive E).Free
$taskRemoved = [Collections.Generic.List[string]]::new()
foreach ($taskGroup in $taskPlan.groups) {
    $taskDirectory = [IO.Path]::GetFullPath($taskGroup.directory)
    foreach ($taskFile in $taskGroup.files) {
        $taskPath = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskFile.path))
        if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'File changed before removal' }
        Remove-Item -LiteralPath $taskPath -Force
        $taskRemoved.Add($taskFile.path)
        @{status='RELOCATING_VERIFIED_FILES';archive=$taskReceipt.archive;archive_sha256=$taskReceipt.archive_sha256;removed=$taskRemoved.ToArray()} | ConvertTo-Json -Depth 4 | Set-Content "$taskOut/old-native-core-cache-relocation-progress.json"
    }
    $taskDirectories = @(Get-ChildItem -LiteralPath $taskDirectory -Recurse -Directory -Force | Sort-Object {$_.FullName.Length} -Descending)
    foreach ($taskChild in $taskDirectories) {
        if (@(Get-ChildItem -LiteralPath $taskChild.FullName -Force).Count) { throw 'Unexpected nonempty directory retained' }
        Remove-Item -LiteralPath $taskChild.FullName
    }
    if (@(Get-ChildItem -LiteralPath $taskDirectory -Force).Count) { throw 'Unexpected transform contents retained' }
    Remove-Item -LiteralPath $taskDirectory
}
$taskInventory = [IO.File]::ReadAllText("$taskOut/core-cache-inventory.json") | ConvertFrom-Json
foreach ($taskGroup in @($taskInventory.groups | Where-Object {$_.current_core})) {
    foreach ($taskFile in $taskGroup.files) {
        $taskPath = Join-Path $taskRoot $taskFile.path
        if ((Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'Current Core cache changed' }
    }
}
$taskResult = @{status='PASS_TEN_RETIRED_NATIVE_CORE_CACHES_RELOCATED';archive=$taskReceipt.archive;archive_sha256=$taskReceipt.archive_sha256;remote_host='pokrov-de';removed=$taskRemoved.ToArray();current_core_groups_unchanged=2;free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;utc=[DateTime]::UtcNow.ToString('o')}
$taskResult | ConvertTo-Json -Depth 4 | Set-Content "$taskOut/old-native-core-cache-relocation.json"
$taskResult | Select-Object status,current_core_groups_unchanged,free_e_before,free_e_after | ConvertTo-Json -Compress
