param([ValidateSet('before','after')][string]$Phase)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$expected=[IO.File]::ReadAllText('C:/Users/Public/R126b20260912/expected.json')|ConvertFrom-Json
$matches=0
foreach($item in $expected.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $item.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -eq $item.Value){$matches++}}
if($matches -ne 304){throw 'Installed candidate mismatch'}
$taskBase='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
$sha=[Security.Cryptography.SHA256]::Create()
function Digest([string]$Value){([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant()}
$routes=@(Get-NetRoute -AddressFamily IPv4 -ErrorAction Stop|Where-Object{$_.DestinationPrefix -eq '0.0.0.0/0'}|Sort-Object InterfaceIndex,NextHop|ForEach-Object{"$($_.InterfaceIndex)|$($_.NextHop)|$($_.RouteMetric)"}) -join "`n"
$dns=@(Get-DnsClientServerAddress -ErrorAction Stop|Where-Object{$_.ServerAddresses.Count}|Sort-Object InterfaceIndex,AddressFamily|ForEach-Object{"$($_.InterfaceIndex)|$($_.AddressFamily)|$($_.ServerAddresses -join ',')"}) -join "`n"
$profile='C:/ProgramData/POKROV/ServiceRuntime/working/configs/managed-profile.json'
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');phase=$Phase;client_source=$expected.client_source;core_source=$expected.core_source;installed_hashes_match=$matches;state_sha256=(Get-FileHash -LiteralPath "$taskBase/app-first-session-windows.json").Hash.ToLowerInvariant();secure_store_sha256=(Get-FileHash -LiteralPath "$taskBase/flutter_secure_storage.dat").Hash.ToLowerInvariant();default_routes_digest=(Digest $routes);dns_digest=(Digest $dns);active_pokrov_adapters=@(Get-NetAdapter -IncludeHidden|Where-Object{$_.Name -like 'POKROV*' -and $_.Status -eq 'Up'}).Count;profile_present=(Test-Path -LiteralPath $profile);profile_sha256=if(Test-Path -LiteralPath $profile){(Get-FileHash -LiteralPath $profile).Hash.ToLowerInvariant()}else{$null}}
$r|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "C:/Users/Public/R126b20260912/state-$Phase.json" -Encoding UTF8
$r|ConvertTo-Json -Depth 5
