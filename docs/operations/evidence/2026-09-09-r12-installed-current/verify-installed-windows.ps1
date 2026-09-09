$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$dir='C:/Users/Public/R12Current'
$expected=[IO.File]::ReadAllText("$dir/expected.json")|ConvertFrom-Json
$before=[IO.File]::ReadAllText("$dir/before.json")|ConvertFrom-Json
$install=[IO.File]::ReadAllText("$dir/install-result.json")|ConvertFrom-Json
if($install.status -ne 'INSTALLER_EXIT_PASS' -or $install.exit_code -ne 0){throw 'Installer not successful'}
$matched=0;$missing=@();$different=@()
foreach($item in $expected.files.PSObject.Properties){
 $path=Join-Path 'C:/Program Files/POKROV' $item.Name
 if(-not(Test-Path -LiteralPath $path)){$missing+=$item.Name;continue}
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $item.Value){$matched++}else{$different+=$item.Name}
}
$base='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
$stateHash=(Get-FileHash -LiteralPath "$base/app-first-session-windows.json" -Algorithm SHA256).Hash.ToLowerInvariant()
$secureHash=(Get-FileHash -LiteralPath "$base/flutter_secure_storage.dat" -Algorithm SHA256).Hash.ToLowerInvariant()
$service=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');origin='current-origin Windows owned VM';client_source=$expected.client_source;core_source=$expected.core_source;installer=$install;matched_files=$matched;expected_files=$expected.file_count;missing=$missing;different=$different;state_preserved=($stateHash -eq $before.state_sha256);secure_store_preserved=($secureHash -eq $before.secure_store_sha256);service_state=$service.State;service_account=$service.StartName;service_path=$service.PathName;ui_count=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count;adapter_count=@(Get-NetAdapter).Count}
$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$dir/installed-readback.json" -Encoding UTF8
if($matched -ne $expected.file_count -or $missing.Count -or $different.Count -or -not $result.state_preserved -or -not $result.secure_store_preserved -or $service.State -ne 'Running'){throw 'Installed readback mismatch'}
exit 0
