param([ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$lab='C:/Users/Public/R12DenialFix'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant()-ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
if(Test-Path "$lab/sample-$Label.json"){throw 'Keep existing result'}
function HashText([string]$value){$h=[Security.Cryptography.SHA256]::Create();try{-join($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))|ForEach-Object ToString x2)}finally{$h.Dispose()}}
function CacheMetadata {
 $path='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/flutter_secure_storage.dat'
 $cipher=$null;$plain=$null;$storage=$null;$cache=$null;$raw=$null
 try{
  if((Get-Item -LiteralPath $path).Length-gt 16777216){throw 'Protected store exceeds capture bound'}
  Add-Type -AssemblyName System.Security
  $cipher=[IO.File]::ReadAllBytes($path)
  $plain=[Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  $storage=[Text.Encoding]::UTF8.GetString($plain)|ConvertFrom-Json
  $property=$storage.PSObject.Properties['pokrov-managed-profile-windows-v1']
  if($null-eq $property){return [ordered]@{available=$false;reason='cache_key_absent'}}
  $raw=[string]$property.Value
  $cache=$raw|ConvertFrom-Json
  if($cache.version-ne 1){return [ordered]@{available=$false;reason='unknown_version'}}
  $rows=@()
  foreach($slot in @('downloaded','proven')){
   $property=$cache.PSObject.Properties[$slot];if($null-eq $property){continue}
   $entry=$property.Value
   $verified=[DateTimeOffset]::Parse([string]$entry.verified_at)
   $rows += [ordered]@{slot=$slot;verified_at=$verified.UtcDateTime.ToString('o');age_seconds=([DateTimeOffset]::UtcNow-$verified).TotalSeconds;binding_sha256=(HashText ([string]$entry.binding));revision_sha256=(HashText ([string]$entry.revision));payload_sha256=(HashText ($entry.payload|ConvertTo-Json -Depth 60 -Compress));cache_entry_id_sha256=(HashText ([string]$entry.payload.cache_entry_id))}
  }
  [ordered]@{available=$true;version=1;records=$rows;raw_exported=$false;store_written=$false}
 }catch{[ordered]@{available=$false;reason='metadata_read_failed';failure_type=$_.Exception.GetType().Name;raw_exported=$false}}
 finally{if($null-ne $plain){[Array]::Clear($plain,0,$plain.Length)};$cipher=$null;$plain=$null;$storage=$null;$cache=$null;$raw=$null;[GC]::Collect()}
}
function HttpStatus {
 $response=$null;$clock=[Diagnostics.Stopwatch]::StartNew()
 try{
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  $req=[Net.HttpWebRequest]::Create('https://app.pokrov.space/health');$req.Proxy=$null;$req.Timeout=8000;$req.ReadWriteTimeout=8000;$req.KeepAlive=$false;$req.ConnectionGroupName=[Guid]::NewGuid().ToString();$req.AllowAutoRedirect=$false
  $response=$req.GetResponse();[ordered]@{status=[int]$response.StatusCode;error=$null;elapsed_ms=$clock.ElapsedMilliseconds}
 }catch [Net.WebException]{[ordered]@{status=$null;error=$_.Exception.Status.ToString();elapsed_ms=$clock.ElapsedMilliseconds}}
 finally{if($null-ne $response){$response.Dispose()}}
}
$admin=([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if($admin){throw 'Ordinary user capture required'}
$routes=@(Get-NetRoute|Select-Object DestinationPrefix,NextHop,InterfaceIndex,RouteMetric,Protocol|Sort-Object DestinationPrefix,NextHop,InterfaceIndex)|ConvertTo-Json -Depth 6 -Compress
$dns=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses|Sort-Object InterfaceIndex,AddressFamily)|ConvertTo-Json -Depth 6 -Compress
$service=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$rawProbe=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status;$probeExit=$LASTEXITCODE
$curl=& 'C:/Windows/System32/curl.exe' --silent --output NUL --write-out '%{http_code}' --max-time 8 --noproxy '*' 'https://app.pokrov.space/health' 2>$null;$curlExit=$LASTEXITCODE
$curlStatus=if([string]$curl-match '^\d{3}$'){[int]$curl}else{$null}
$events=@()
$state=[IO.File]::ReadAllText('C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/pokrov-client-experience-v1.json')|ConvertFrom-Json
foreach($event in @($state.protectionEvents|Where-Object kind -eq 'connected'|Sort-Object occurredAt -Descending|Select-Object -First 3)){
 $events += [ordered]@{occurred_at=$event.occurredAt;id_sha256=(HashText ([string]$event.id));cached_profile=([string]$event.detail).StartsWith('Control plane ')}
}
$r=[ordered]@{schema='pokrov.r12-windows-api-outage-sample/v1';utc=[DateTime]::UtcNow.ToString('o');label=$Label;collector_admin=$admin;ui_pids=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue|ForEach-Object Id);service_pid=$service.ProcessId;service_state=$service.State;probe=($rawProbe|ConvertFrom-Json);probe_exit=$probeExit;tun_count=@(Get-NetAdapter -IncludeHidden|Where-Object {$_.Status-eq 'Up' -and ($_.Name-match '^tun[0-9]*$|pokrov|wintun' -or $_.InterfaceDescription-match 'wintun|pokrov|wireguard tunnel')}).Count;routes_sha256=(HashText $routes);dns_sha256=(HashText $dns);curl_exit=$curlExit;curl_status=$curlStatus;blocked_process_probe=(HttpStatus);cache=(CacheMetadata);connected_events=$events;outage_rule_states=@(Get-NetFirewallRule -PolicyStore ActiveStore|Where-Object Name -in @('R12DenialFix-20260908-Ui','R12DenialFix-20260908-Probe')|Select-Object Name,Enabled|Sort-Object Name)}
[IO.File]::WriteAllText("$lab/sample-$Label.json",($r|ConvertTo-Json -Depth 9),[Text.UTF8Encoding]::new($false))
[ordered]@{label=$Label;running=$r.probe.running;tun_count=$r.tun_count;curl_status=$r.curl_status;blocked_process_status=$r.blocked_process_probe.status;cache_metadata_available=$r.cache.available}|ConvertTo-Json
