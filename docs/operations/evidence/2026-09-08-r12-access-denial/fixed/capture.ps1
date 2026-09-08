param([ValidatePattern('^[a-z0-9-]+$')][string]$Label,[ValidateSet('before','after')][string]$Bundle='before')
$ErrorActionPreference='Stop'
$lab='C:/Users/Public/R12DenialFix'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant()-ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
if(Test-Path "$lab/$Label.json"){throw 'Preserve evidence'}
function HashText([string]$v){$h=[Security.Cryptography.SHA256]::Create();try{-join($h.ComputeHash([Text.Encoding]::UTF8.GetBytes($v))|ForEach-Object ToString x2)}finally{$h.Dispose()}}
$expected=[IO.File]::ReadAllText("$lab/expected-$Bundle.json")|ConvertFrom-Json
$matched=0
foreach($f in $expected.files.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $f.Name)).Hash.ToLowerInvariant()-ne $f.Value){throw 'Installed mismatch'};$matched++}
$root='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
$experience=[IO.File]::ReadAllText("$root/pokrov-client-experience-v1.json")|ConvertFrom-Json
$routes=@(Get-NetRoute|Select-Object DestinationPrefix,NextHop,InterfaceIndex,RouteMetric,Protocol|Sort-Object DestinationPrefix,NextHop,InterfaceIndex)|ConvertTo-Json -Depth 6 -Compress
$dns=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,AddressFamily,ServerAddresses|Sort-Object InterfaceIndex,AddressFamily)|ConvertTo-Json -Depth 6 -Compress
$probe=& 'C:/Program Files/POKROV/r12_managed_probe.exe' status;$code=$LASTEXITCODE
$s=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');label=$Label;bundle=$Bundle;client_source=$expected.client_source;core_source=$expected.core_source;files_verified=$matched;installer_sha256=$expected.installer_sha256;state_sha256=(Get-FileHash "$root/app-first-session-windows.json").Hash.ToLowerInvariant();experience_sha256=(Get-FileHash "$root/pokrov-client-experience-v1.json").Hash.ToLowerInvariant();routing_preferences=$experience.routingPreferences;selected_apps_count=@($experience.selectedAppIds).Count;routes_sha256=(HashText $routes);dns_sha256=(HashText $dns);ui_count=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count;service_state=$s.State;service_account=$s.StartName;service_start_mode=$s.StartMode;probe_exit=$code;probe=($probe|ConvertFrom-Json)}
$logPath="$lab/install-$Bundle.log"
if(Test-Path $logPath){$log=[IO.File]::ReadAllText($logPath);$r.install_succeeded=($log-match 'Installation process succeeded\.');$r.log_closed=($log-match 'Log closed\.');$r.restart_required=($log-match 'Need to restart Windows\? Yes')}
[IO.File]::WriteAllText("$lab/$Label.json",($r|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
