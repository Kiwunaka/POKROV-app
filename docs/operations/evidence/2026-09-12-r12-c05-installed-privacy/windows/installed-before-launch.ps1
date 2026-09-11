$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$dir='C:/Users/Public/R12C05266220260912'
$old=[IO.File]::ReadAllText("$dir/expected.json")|ConvertFrom-Json
if($old.client_source -ne '212bd2f30c9f91d80fd3a6c08fb5557be8457f1c'){throw 'Wrong previous source'}
$matched=0
foreach($item in $old.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -eq $item.Value){$matched++}}
if($matched -ne 304){throw 'Current installed package mismatch'}
$base='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
$service=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$new=[IO.File]::ReadAllText("$dir/expected.json")|ConvertFrom-Json
if((Get-FileHash -LiteralPath "$dir/setup.exe").Hash.ToLowerInvariant() -ne $new.installer_sha256){throw 'Setup copy mismatch'}
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');client_source=$old.client_source;core_source=$old.core_source;matched_files=$matched;state_sha256=(Get-FileHash -LiteralPath "$base/app-first-session-windows.json").Hash.ToLowerInvariant();secure_store_sha256=(Get-FileHash -LiteralPath "$base/flutter_secure_storage.dat").Hash.ToLowerInvariant();outbox_count=@(Get-ChildItem -LiteralPath "$base/support-bundle-outbox" -File -Filter '*.pokrov-support').Count;service_state=$service.State;service_account=$service.StartName;ui_count=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count;new_setup_sha256=$new.installer_sha256;os=(Get-CimInstance Win32_OperatingSystem).Caption;build=(Get-CimInstance Win32_OperatingSystem).BuildNumber}
$r|ConvertTo-Json|Set-Content -LiteralPath "$dir/installed-before-launch.json" -Encoding UTF8
$r|ConvertTo-Json
