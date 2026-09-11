$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$probe='C:/Program Files/POKROV/r12_managed_probe.exe'
$before=& $probe status|ConvertFrom-Json
if(-not($before.running -and $before.egress_validated -and $before.effective_matches_staged)){throw 'Tunnel not verified'}
$tun=@(Get-NetAdapter|Where-Object {$_.Status -eq 'Up' -and ($_.Name -match '^tun[0-9]*$|pokrov|wintun' -or $_.InterfaceDescription -match 'wintun|pokrov|wireguard tunnel')})
if($tun.Count -ne 1){throw 'Expected one owned TUN'}
$index=$tun[0].ifIndex
$ni=@([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()|Where-Object {$_.GetIPProperties().GetIPv4Properties().Index -eq $index})
if($ni.Count -ne 1){throw 'Counter unavailable'}
$start=$ni[0].GetIPv4Statistics()
$results=@()
for($i=0;$i -lt 10;$i++){
 $timer=[Diagnostics.Stopwatch]::StartNew()
 $r=Invoke-WebRequest 'https://api.pokrov.space/api/public/authenticated-egress-probe' -UseBasicParsing -TimeoutSec 15 -DisableKeepAlive
 $timer.Stop()
 $results += [ordered]@{status=[int]$r.StatusCode;marker_valid=($r.Headers['x-pokrov-egress-probe'] -eq 'pokrov-authenticated-egress-v1');elapsed_ms=$timer.ElapsedMilliseconds}
}
$end=$ni[0].GetIPv4Statistics()
$after=& $probe status|ConvertFrom-Json
$rx=$end.BytesReceived-$start.BytesReceived;$tx=$end.BytesSent-$start.BytesSent
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');counter_method='NetworkInterface.GetIPv4Statistics';tun_count=1;tun_received_delta=$rx;tun_sent_delta=$tx;requests=$results;before=$before;after=$after;scope='Current-origin installed service with ambient guest traffic; NIC deltas not per-request attribution'}|ConvertTo-Json -Depth 8
if($rx -le 0 -or $tx -le 0 -or @($results|Where-Object {$_.status -ne 204 -or -not $_.marker_valid}).Count -or -not($after.running -and $after.egress_validated -and $after.effective_matches_staged)){throw 'Tunnel traffic check failed'}
