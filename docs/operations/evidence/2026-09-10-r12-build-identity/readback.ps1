$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$expected=[IO.File]::ReadAllText('C:/Users/Public/R12BuildIdentity/expected.json')|ConvertFrom-Json
$matched=0;$missing=0;$different=0
foreach($item in $expected.files.PSObject.Properties){
 $path=Join-Path 'C:/Program Files/POKROV' $item.Name
 if(-not(Test-Path -LiteralPath $path)){$missing++;continue}
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $item.Value){$matched++}else{$different++}
}
$service=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');client_source=$expected.client_source;core_source=$expected.core_source;matched_files=$matched;expected_files=$expected.file_count;missing=$missing;different=$different;service_state=$service.State;ui_count=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count;status=$status}|ConvertTo-Json -Depth 8
if($matched -ne $expected.file_count -or $missing -or $different){throw 'Installed bytes differ'}
