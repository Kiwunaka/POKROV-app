$ErrorActionPreference = 'Stop'
$taskOut = 'C:/r12-c05-setup-privacy-20260912'
$taskRoots = @('E:\r12-c05-failed-build-20260911')
$taskRows = [Collections.Generic.List[object]]::new()
foreach ($taskRoot in $taskRoots) {
    if ((Resolve-Path -LiteralPath $taskRoot).Path -ne $taskRoot) { throw 'Unexpected artifact root' }
    $taskItems = @(Get-Item -LiteralPath $taskRoot) + @(Get-ChildItem -LiteralPath $taskRoot -Recurse -Force)
    if (@($taskItems | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count) { throw 'Artifact reparse point' }
    foreach ($taskFile in @($taskItems | Where-Object {-not $_.PSIsContainer})) {
        $taskRows.Add(@{path=$taskFile.FullName;bytes=$taskFile.Length;sha256=(Get-FileHash -LiteralPath $taskFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()})
    }
}
$taskBefore=(Get-PSDrive E).Free
@{status='PREPARED_EXACT_PRIOR_ARTIFACT_COMPRESSION';roots=$taskRoots;files=$taskRows.ToArray();free_e_before=$taskBefore;method='NTFS native compression; no file removal or content edits'}|ConvertTo-Json -Depth 6|Set-Content "$taskOut/failed-build-compression-plan.json"
[Diagnostics.Process]::GetCurrentProcess().PriorityClass='BelowNormal'
foreach ($taskRoot in $taskRoots) {
    & compact.exe /C "/S:$taskRoot" /I /Q *> "$taskOut/compact-$([IO.Path]::GetFileName($taskRoot)).log"
    if ($LASTEXITCODE -ne 0) { throw 'NTFS artifact compression failed' }
}
foreach ($taskFile in $taskRows) {
    if ((Get-FileHash -LiteralPath $taskFile.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskFile.sha256 -or (Get-Item -LiteralPath $taskFile.path).Length -ne $taskFile.bytes) { throw 'Artifact bytes changed' }
}
$taskResult=@{status='PASS_PRIOR_ARTIFACT_BYTES_UNCHANGED';files=$taskRows.Count;files_deleted=0;free_e_before=$taskBefore;free_e_after=(Get-PSDrive E).Free;method='NTFS native compression';utc=[DateTime]::UtcNow.ToString('o')}
$taskResult|ConvertTo-Json|Set-Content "$taskOut/failed-build-compression.json"
$taskResult|ConvertTo-Json -Compress
