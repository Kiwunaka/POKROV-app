$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$dir='C:/Users/Public/R12N05Windows20260911'
$expected=[IO.File]::ReadAllText("$dir/expected.json")|ConvertFrom-Json
$matched=0
foreach($item in $expected.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Value){throw 'Installed file mismatch'};$matched++}
$base='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
$before=[IO.File]::ReadAllText("$dir/baseline-resumed.json")|ConvertFrom-Json
$status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');client_source=$expected.client_source;core_source=$expected.core_source;matched_files=$matched;expected_files=$expected.file_count;state_file_present=(Test-Path -LiteralPath "$base/app-first-session-windows.json");secure_store_file_present=(Test-Path -LiteralPath "$base/flutter_secure_storage.dat");outbox_count=@(Get-ChildItem -LiteralPath "$base/support-bundle-outbox" -File -Filter '*.pokrov-support').Count;outbox_count_before=$before.outbox_count;service_state=(Get-Service POKROVService).Status.ToString();status=$status}
$r|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "$dir/final-installed-readback.json" -Encoding UTF8
if($matched -ne 304 -or $status.running -or $status.failure -ne 'none'){throw 'Final readback failed'}
