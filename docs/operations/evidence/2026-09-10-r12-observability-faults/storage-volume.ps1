param([ValidateSet('prepare','verify','restore')][string]$Mode)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$base=[IO.Path]::GetFullPath('C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV')
$store=[IO.Path]::GetFullPath((Join-Path $base 'pokrov-observability'))
$backup=[IO.Path]::GetFullPath((Join-Path $base 'pokrov-observability-r12-diskfull-preserved'))
$root='C:/Users/Public/R12ObservabilityFaults'
$receiptPath="$root/storage-before.json"
$target='R:/pokrov-observability'
foreach($path in @($store,$backup)){if([IO.Path]::GetDirectoryName($path) -ne $base){throw 'Path escaped owned app data'}}
function Get-SafeInventory([string]$directory){
 $records=@()
 foreach($item in Get-ChildItem -LiteralPath $directory -File -Recurse){
  if(-not $item.FullName.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Inventory escaped diagnostic directory'}
  $records+=@{path=$item.FullName.Substring($directory.Length+1);bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 return @($records|Sort-Object {$_.path})
}
$volume=Get-Volume -DriveLetter R
$disk=Get-Partition -DriveLetter R|Get-Disk
$created=[IO.File]::ReadAllText("$root/volume-created.json")|ConvertFrom-Json
if($volume.FileSystemLabel -ne 'R12_OBS_FAULT' -or $disk.Number -ne $created.disk_number -or $disk.Size -ne $created.disk_size_bytes){throw 'Fixture volume identity changed'}
if($Mode -eq 'prepare'){
 if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count){throw 'Stop UI before fixture preparation'}
 $status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
 if($status.running){throw 'Stop VPN before fixture preparation'}
 if((Test-Path -LiteralPath $receiptPath) -or (Test-Path -LiteralPath $backup) -or (Test-Path -LiteralPath $target)){throw 'Fixture already exists'}
 if(-not(Test-Path -LiteralPath $store -PathType Container)){throw 'Diagnostic directory absent'}
 $records=Get-SafeInventory $store
 if(-not $records.Count){throw 'Original evidence absent'}
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');mode='prepare';files=$records;account_state_sha256=(Get-FileHash -LiteralPath "$base/app-first-session-windows.json").Hash;secure_store_sha256=(Get-FileHash -LiteralPath "$base/flutter_secure_storage.dat").Hash;backup_path=$backup;target=$target}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $receiptPath -Encoding UTF8
 New-Item -ItemType Directory -Path $target|Out-Null
 [IO.File]::WriteAllText('R:/owned-volume.marker','R12 diagnostic disk-full isolated volume 20260910')
 [IO.Directory]::Move($store,$backup)
 New-Item -ItemType Junction -Path $store -Target $target|Out-Null
}
$before=[IO.File]::ReadAllText($receiptPath)|ConvertFrom-Json
$preserved=Get-SafeInventory $backup
if($preserved.Count -ne $before.files.Count){throw 'Preserved file count changed'}
foreach($old in $before.files){$new=@($preserved|Where-Object path -eq $old.path);if($new.Count -ne 1 -or $new[0].sha256 -ne $old.sha256){throw 'Preserved bytes changed'}}
$link=Get-Item -LiteralPath $store -Force
if($link.LinkType -ne 'Junction' -or [IO.Path]::GetFullPath($link.Target[0]) -ne [IO.Path]::GetFullPath($target)){throw 'Unexpected diagnostic link'}
if($Mode -eq 'restore'){
 if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count){throw 'Stop UI before restoration'}
 $status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
 if($status.running){throw 'Stop VPN before restoration'}
 [IO.Directory]::Delete($store,$false)
 [IO.Directory]::Move($backup,$store)
 $restored=Get-SafeInventory $store
 if($restored.Count -ne $before.files.Count){throw 'Restored count differs'}
 foreach($old in $before.files){$new=@($restored|Where-Object path -eq $old.path);if($new.Count -ne 1 -or $new[0].sha256 -ne $old.sha256){throw 'Restored bytes differ'}}
}
[ordered]@{status='PASS';utc=[DateTime]::UtcNow.ToString('o');mode=$Mode;preserved_files=$preserved.Count;original_diagnostic_hashes_match=$true;raw_diagnostics_exported=$false;volume_free_bytes=(Get-Volume -DriveLetter R).SizeRemaining}|ConvertTo-Json
