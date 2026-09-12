$ErrorActionPreference='Stop'
$taskOut='C:/r12-c05-wintun-20260912'
$taskReport=[IO.File]::ReadAllText("$taskOut/source-archive-retention.json")|ConvertFrom-Json
$taskAllowed=@(
 'E:\r12-2662-source-20260911\pokrov-core-2662f76-source-review.zip',
 'E:\r12-904-source-20260911\pokrov-core-904e440-source-review.zip',
 'E:\r12-c05-source-packet\pokrov-core-8dc57a8-source-review-compact.zip',
 'E:\r12-c05-source-packet\pokrov-core-8dc57a8-source-review.zip',
 'E:\r12-current-source-20260910\pokrov-core-c7a11f7-source-review.zip')
$taskReceiptPath="$taskOut/source-archive-relocation.json"
$taskDone=@()
if(Test-Path -LiteralPath $taskReceiptPath){$taskDone=@(([IO.File]::ReadAllText($taskReceiptPath)|ConvertFrom-Json).files)}
foreach($taskRow in $taskReport.files){
 if($taskDone.local_path -contains $taskRow.local_path){continue}
 if($taskRow.status -ne 'PASS_REMOTE_BYTES_VERIFIED' -or $taskAllowed -notcontains $taskRow.local_path){throw 'Archive not verified or outside exact scope'}
 $taskResolved=(Resolve-Path -LiteralPath $taskRow.local_path).Path
 if($taskResolved -ne $taskRow.local_path -or (Get-Item -LiteralPath $taskResolved).LinkType){throw 'Unexpected archive path'}
 if((Get-Item -LiteralPath $taskResolved).Length -ne $taskRow.bytes -or (Get-FileHash -LiteralPath $taskResolved -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskRow.sha256){throw 'Archive changed since retention'}
 Remove-Item -LiteralPath $taskResolved
 if(Test-Path -LiteralPath $taskResolved){throw 'Local archive still present'}
 $taskDone+=@{local_path=$taskRow.local_path;remote_host='pokrov-de';remote_path=$taskRow.remote_path;sha256=$taskRow.sha256;bytes=$taskRow.bytes;status='PASS_RELOCATED_WITH_REMOTE_HASH_PROOF';utc=[DateTime]::UtcNow.ToString('o')}
 @{status='PARTIAL_OR_COMPLETE_RELOCATION';files=$taskDone;historical_metadata_unchanged=$true;free_e_bytes=(Get-Volume -DriveLetter E).SizeRemaining}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $taskReceiptPath
}
Write-Output "Verified archives relocated: $($taskDone.Count)"
Get-Volume -DriveLetter C,E | Select-Object DriveLetter,SizeRemaining
