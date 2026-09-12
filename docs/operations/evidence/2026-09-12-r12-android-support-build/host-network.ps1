param([ValidateSet('before','after')][string]$Phase='before')
$ErrorActionPreference='Stop'
$dir='C:\r12-6b-android-support-20260912'
function HashText([string]$text){$h=[Security.Cryptography.SHA256]::Create();try{-join($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($text))|ForEach-Object ToString x2)}finally{$h.Dispose()}}
$routes=Get-NetRoute|Select-Object DestinationPrefix,NextHop,InterfaceIndex,RouteMetric,Protocol|Sort-Object DestinationPrefix,NextHop,InterfaceIndex|ConvertTo-Json -Compress
$dns=Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses|Sort-Object InterfaceIndex,AddressFamily|ConvertTo-Json -Compress
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');routes_sha256=(HashText $routes);dns_sha256=(HashText $dns)}
if($Phase -eq 'after'){$old=[IO.File]::ReadAllText('C:/r12-6b-android-20260912/host-network-after.json')|ConvertFrom-Json;$r.routes_match_before=$r.routes_sha256 -eq $old.routes_sha256;$r.dns_match_before=$r.dns_sha256 -eq $old.dns_sha256}
$r|ConvertTo-Json|Set-Content "$dir/host-network-installed-$Phase.json" -Encoding UTF8
