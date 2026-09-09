param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
function HashText([string]$text){$h=[Security.Cryptography.SHA256]::Create();try{-join($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))|ForEach-Object ToString x2)}finally{$h.Dispose()}}
$routes=Get-NetRoute|Select-Object DestinationPrefix,NextHop,InterfaceIndex,RouteMetric,Protocol|Sort-Object DestinationPrefix,NextHop,InterfaceIndex|ConvertTo-Json -Compress
$dns=Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses|Sort-Object InterfaceIndex,AddressFamily|ConvertTo-Json -Compress
$up=@(Get-NetAdapter|Where-Object Status -eq Up)
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');label=$Label;routes_sha256=(HashText $routes);dns_sha256=(HashText $dns);up_adapter_count=$up.Count
 tun_count=@(Get-NetAdapter -IncludeHidden|Where-Object {$_.Status -eq 'Up' -and ($_.Name -match '^tun[0-9]*$|pokrov|wintun' -or $_.InterfaceDescription -match 'wintun|pokrov|wireguard tunnel')}).Count
 health_status=$null;egress_sha256=$null;egress_error=$null;dns_a_count=$null;probe=$null}
try{$r.health_status=[int](Invoke-WebRequest 'https://app.pokrov.space/health' -UseBasicParsing -TimeoutSec 10).StatusCode}catch{$r.health_error=$_.Exception.GetType().Name}
try{$ip=([string](Invoke-WebRequest 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 10).Content).Trim();$parsed=$null;if(-not[Net.IPAddress]::TryParse($ip,[ref]$parsed)){throw 'Invalid IP response'};$r.egress_sha256=HashText $ip;$ip=$null;$parsed=$null}catch{$r.egress_error=$_.Exception.GetType().Name}
try{$r.dns_a_count=@(Resolve-DnsName api.pokrov.space -Type A -DnsOnly -ErrorAction Stop|Where-Object Type -eq A).Count}catch{$r.dns_error=$_.Exception.GetType().Name}
$probe=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status
$r.probe_exit_code=$LASTEXITCODE
$r.probe=$probe|ConvertFrom-Json
$r|ConvertTo-Json -Depth 6|Set-Content -LiteralPath "C:/Users/Public/R12Managed/network-$Label.json" -Encoding UTF8
