$ErrorActionPreference = 'Stop'
$taskOut = 'C:/r12-6b-installed-20260912'
$taskPlan = [IO.File]::ReadAllText("$taskOut/completed-intermediate-retention-plan.json") | ConvertFrom-Json
$taskReceipt = [IO.File]::ReadAllText("$taskOut/completed-intermediate-retention.json") | ConvertFrom-Json
$taskRoot = [IO.Path]::GetFullPath('E:/r12client/apps/android_shell/build/app/intermediates')
$taskGroups = @('merged_native_libs','stripped_native_libs','intermediary_bundle','module_bundle')
if ($taskReceipt.status -ne 'PASS_EXACT_COMPLETED_ANDROID_INTERMEDIATE_ARCHIVE' -or $taskReceipt.files -ne 42 -or $taskPlan.files.Count -ne 42 -or $taskPlan.groups.Count -ne 4 -or $taskPlan.root -ne $taskRoot) { throw 'Exact archive scope verification missing' }
if (@(Get-Process java,VirtualBoxVM,VBoxHeadless,dnplayer -ErrorAction SilentlyContinue).Count) { throw 'Build or VM active' }
if ($taskReceipt.archive -ne '/tmp/pokrov-r12-core-validation-1c8b33f6a771409a/retained-completed-android-intermediates-6b-20260912/cache.tar.gz') { throw 'Unexpected archive' }
$taskRemoteHash = (& ssh -o BatchMode=yes -o ConnectTimeout=8 pokrov-de "sha256sum $($taskReceipt.archive)")
if ($LASTEXITCODE -ne 0 -or -not $taskRemoteHash.StartsWith($taskReceipt.archive_sha256+' ')) { throw 'Retained archive changed' }
$taskPackages = ([IO.File]::ReadAllText('C:/r12-c05-setup-privacy-20260912/package-receipt.json') | ConvertFrom-Json).artifacts
function Assert-Packages {
    if ($taskPackages.Count -ne 6) { throw 'Expected six finished packages' }
    foreach ($taskPackage in $taskPackages) {
        if ((Get-Item -LiteralPath $taskPackage.path).Length -ne $taskPackage.size -or (Get-FileHash -LiteralPath $taskPackage.path).Hash.ToLowerInvariant() -ne $taskPackage.sha256) { throw 'Finished package changed' }
    }
}
Assert-Packages
foreach ($taskGroup in $taskPlan.groups) {
    if ($taskGroup.path -notin $taskGroups -or $taskGroup.current_core -or $taskGroup.kind -ne 'completed_intermediate') { throw 'Unexpected group' }
    $taskDirectory = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskGroup.path))
    if ([IO.Path]::GetDirectoryName($taskDirectory) -ne $taskRoot) { throw 'Group outside root' }
    $taskItems = @(Get-Item -LiteralPath $taskDirectory) + @(Get-ChildItem -LiteralPath $taskDirectory -Recurse -Force)
    if (@($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Reparse point in selected group' }
    $taskPaths = @($taskItems | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName} | Sort-Object)
    $taskExpected = @($taskGroup.files | ForEach-Object {[IO.Path]::GetFullPath((Join-Path $taskRoot $_.path))} | Sort-Object)
    if (($taskPaths -join "`n") -ne ($taskExpected -join "`n")) { throw 'Group file set changed' }
    foreach ($taskFile in $taskGroup.files) {
        $taskPath = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskFile.path))
        if (-not $taskPath.StartsWith($taskDirectory+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'File outside selected group' }
        if ((Get-Item -LiteralPath $taskPath).Length -ne $taskFile.bytes -or (Get-FileHash -LiteralPath $taskPath).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'Intermediate changed since archive' }
    }
}
$taskBefore = (Get-PSDrive E).Free
$taskRemoved = [Collections.Generic.List[string]]::new()
foreach ($taskGroup in $taskPlan.groups) {
    $taskDirectory = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskGroup.path))
    foreach ($taskFile in $taskGroup.files) {
        $taskPath = [IO.Path]::GetFullPath((Join-Path $taskRoot $taskFile.path))
        if ((Get-FileHash -LiteralPath $taskPath).Hash.ToLowerInvariant() -ne $taskFile.sha256) { throw 'File changed immediately before removal' }
        Remove-Item -LiteralPath $taskPath -Force
        $taskRemoved.Add($taskFile.path)
        @{status='RELOCATING_VERIFIED_FILES';archive=$taskReceipt.archive;archive_sha256=$taskReceipt.archive_sha256;removed=$taskRemoved.ToArray()} | ConvertTo-Json -Depth 4 | Set-Content "$taskOut/completed-intermediate-relocation-progress.json"
    }
    foreach ($taskChild in @(Get-ChildItem -LiteralPath $taskDirectory -Recurse -Directory -Force | Sort-Object {$_.FullName.Length} -Descending)) {
        if (@(Get-ChildItem -LiteralPath $taskChild.FullName -Force).Count) { throw 'Unexpected contents retained' }
        Remove-Item -LiteralPath $taskChild.FullName
    }
    if (@(Get-ChildItem -LiteralPath $taskDirectory -Force).Count) { throw 'Unexpected group contents retained' }
    Remove-Item -LiteralPath $taskDirectory
}
Assert-Packages
$taskResult = @{status='PASS_42_COMPLETED_INTERMEDIATES_RELOCATED';archive=$taskReceipt.archive;archive_sha256=$taskReceipt.archive_sha256;remote_host='pokrov-de';removed=$taskRemoved.ToArray();six_finished_packages_unchanged=$true;free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;rollback='Restore only listed members from retained archive into original root, verifying their SHA256 against retained plan';utc=[DateTime]::UtcNow.ToString('o')}
$taskResult | ConvertTo-Json -Depth 4 | Set-Content "$taskOut/completed-intermediate-relocation.json"
$taskResult | Select-Object status,six_finished_packages_unchanged,free_e_before,free_e_after | ConvertTo-Json -Compress
