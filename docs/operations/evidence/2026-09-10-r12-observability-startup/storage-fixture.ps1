param([ValidateSet('prepare','verify','restore')][string]$Mode)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$base=[IO.Path]::GetFullPath('C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV')
$store=[IO.Path]::GetFullPath((Join-Path $base 'pokrov-observability'))
$backup=[IO.Path]::GetFullPath((Join-Path $base 'pokrov-observability-r12-20260910-preserved'))
$fixtureRoot='C:/Users/Public/R12ObservabilityStartup'
$receiptPath="$fixtureRoot/storage-before.json"
foreach($path in @($store,$backup)){if([IO.Path]::GetDirectoryName($path) -ne $base){throw 'Path escaped owned app data'}}
$fixtureText='R12-owned diagnostic storage path-conflict fixture 20260910'
function Get-SafeInventory([string]$directory){
 $records=@()
 foreach($item in Get-ChildItem -LiteralPath $directory -File -Recurse){
  if(-not $item.FullName.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Inventory path escaped diagnostic directory'}
  $records+=@{path=$item.FullName.Substring($directory.Length+1);bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 return @($records|Sort-Object {$_.path})
}
if($Mode -eq 'prepare'){
 if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count){throw 'UI must be stopped before fixture move'}
 if(Test-Path -LiteralPath $receiptPath){throw 'Fixture already prepared'}
 if(Test-Path -LiteralPath $backup){throw 'Preserved target already exists'}
 if(-not(Test-Path -LiteralPath $store -PathType Container)){throw 'Expected diagnostic directory missing'}
 $status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
 if($status.running){throw 'VPN must be stopped before fixture setup'}
 $records=Get-SafeInventory $store
 if(-not $records.Count){throw 'Expected existing diagnostic evidence'}
 $result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');mode='prepare';files=$records;account_state_sha256=(Get-FileHash -LiteralPath "$base/app-first-session-windows.json").Hash;secure_store_sha256=(Get-FileHash -LiteralPath "$base/flutter_secure_storage.dat").Hash;backup_path=$backup}
 $result|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $receiptPath -Encoding UTF8
 [IO.Directory]::Move($store,$backup)
 [IO.File]::WriteAllText($store,$fixtureText)
}
$before=[IO.File]::ReadAllText($receiptPath)|ConvertFrom-Json
$preserved=Get-SafeInventory $backup
if($preserved.Count -ne $before.files.Count){throw 'Preserved inventory count differs'}
foreach($old in $before.files){$new=@($preserved|Where-Object path -eq $old.path);if($new.Count -ne 1 -or $new[0].sha256 -ne $old.sha256){throw 'Preserved bytes changed'}}
if(-not(Test-Path -LiteralPath $store -PathType Leaf) -or [IO.File]::ReadAllText($store) -ne $fixtureText){throw 'Owned fixture identity differs'}
if($Mode -eq 'restore'){
 if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count){throw 'UI must be stopped before restore'}
 $status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
 if($status.running){throw 'VPN must be stopped before restore'}
 [IO.File]::Delete($store)
 [IO.Directory]::Move($backup,$store)
 $restored=Get-SafeInventory $store
 foreach($old in $before.files){$new=@($restored|Where-Object path -eq $old.path);if($new.Count -ne 1 -or $new[0].sha256 -ne $old.sha256){throw 'Restored bytes differ'}}
}
[ordered]@{status='PASS';utc=[DateTime]::UtcNow.ToString('o');mode=$Mode;preserved_files=$preserved.Count;fixture_text_only=$true;original_diagnostic_hashes_match=$true;raw_diagnostics_exported=$false}|ConvertTo-Json
