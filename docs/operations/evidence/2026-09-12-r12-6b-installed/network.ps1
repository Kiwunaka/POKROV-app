param([Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
function HashText([string]$value){$h=[Security.Cryptography.SHA256]::Create();try{-join($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))|ForEach-Object ToString x2)}finally{$h.Dispose()}}
$routes=@(Get-NetRoute|Select-Object DestinationPrefix,NextHop,InterfaceIndex,RouteMetric,Protocol|Sort-Object DestinationPrefix,NextHop,InterfaceIndex)
$dns=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses|Sort-Object InterfaceIndex,AddressFamily)
$adapters=@(Get-NetAdapter -IncludeHidden|Where-Object {$_.Status -eq 'Up'}|ForEach-Object {
 $idx=$_.ifIndex
 $ni=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()|Where-Object {$_.GetIPProperties().GetIPv4Properties().Index -eq $idx})
 $s=if($ni.Count -eq 1){$ni[0].GetIPv4Statistics()}else{$null}
 [ordered]@{interface_index=$_.ifIndex;is_pokrov_tun=($_.Name -match '^tun[0-9]*$|pokrov|wintun' -or $_.InterfaceDescription -match 'wintun|pokrov|wireguard tunnel');received_bytes=$s.BytesReceived;sent_bytes=$s.BytesSent}
})
$result=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');label=$Label;counter_method="NetworkInterface.GetIPv4Statistics";routes_count=$routes.Count;routes_sha256=(HashText ($routes|ConvertTo-Json -Compress));dns_sha256=(HashText ($dns|ConvertTo-Json -Compress));adapters=$adapters;http_status=$null;marker_valid=$false;http_error=$null;dns_a_count=$null;dns_error=$null;status=$null}
try{$r=Invoke-WebRequest 'https://api.pokrov.space/api/public/authenticated-egress-probe' -UseBasicParsing -TimeoutSec 15;$result.http_status=[int]$r.StatusCode;$result.marker_valid=($r.Headers['x-pokrov-egress-probe'] -eq 'pokrov-authenticated-egress-v1')}catch{$result.http_error=$_.Exception.GetType().Name}
try{$result.dns_a_count=@(Resolve-DnsName api.pokrov.space -Type A -DnsOnly -ErrorAction Stop|Where-Object Type -eq A).Count}catch{$result.dns_error=$_.Exception.GetType().Name}
$result.status=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status|ConvertFrom-Json
$result|ConvertTo-Json -Depth 8
