$ErrorActionPreference='Stop'
$lab='C:/Users/Public/R12DenialFix'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant()-ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
if(Test-Path "$lab/api-expired-account.json"){throw 'Preserve evidence'}
$plain=$null;$store=$null;$pair=$null;$token=$null
try {
 Add-Type -AssemblyName System.Security
 $root='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV'
 $state=[IO.File]::ReadAllText("$root/app-first-session-windows.json")|ConvertFrom-Json
 $cipher=[IO.File]::ReadAllBytes("$root/flutter_secure_storage.dat")
 $plain=[Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
 $store=[Text.Encoding]::UTF8.GetString($plain)|ConvertFrom-Json
 $key='pokrov.app_first.session.windows.'+$state.install_id
 $raw=[string]$store.PSObject.Properties[$key].Value
 $pair=$raw|ConvertFrom-Json
 $token=[string]$pair.access_token
 if([string]::IsNullOrWhiteSpace($token)){throw 'Session credential missing'}
 $results=@()
 foreach($path in @('/api/client/subscription','/api/client/profile/managed')){
  $response=$null;$clock=[Diagnostics.Stopwatch]::StartNew()
  try{
   [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
   $req=[Net.HttpWebRequest]::Create('https://app.pokrov.space'+$path)
   $req.Proxy=$null;$req.Method='GET';$req.Timeout=15000;$req.ReadWriteTimeout=15000;$req.AllowAutoRedirect=$false;$req.Headers['Authorization']='Bearer '+$token
   $response=$req.GetResponse()
   $row=[ordered]@{path=$path;status=[int]$response.StatusCode;elapsed_ms=$clock.ElapsedMilliseconds}
   if($path-eq '/api/client/subscription'){
    $reader=[IO.StreamReader]::new($response.GetResponseStream());$data=$reader.ReadToEnd()|ConvertFrom-Json;$reader.Dispose()
    $lane=[string]$data.lane
    if($lane-notin @('trialPremium','paidUnlimited','freeLimited','expiredOrBlocked','unknown')){throw 'Unexpected lane'}
    $row.lane=$lane;$row.days_left=$data.daysLeft
   }
  }catch [Net.WebException]{
   $row=[ordered]@{path=$path;status=$(if($_.Exception.Response){[int]$_.Exception.Response.StatusCode}else{$null});elapsed_ms=$clock.ElapsedMilliseconds;error=$_.Exception.Status.ToString()}
   if($_.Exception.Response){$_.Exception.Response.Dispose()}
  }finally{if($response){$response.Dispose()}}
  $results+=$row
 }
 $r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');read_only_requests=$true;session_refreshed=$false;raw_exported=$false;results=$results}
 [IO.File]::WriteAllText("$lab/api-expired-account.json",($r|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
 $r|ConvertTo-Json -Depth 5
}catch{Write-Output 'SAFE_API_PROBE_FAILED';exit 1}
finally{if($plain){[Array]::Clear($plain,0,$plain.Length)};$plain=$null;$store=$null;$pair=$null;$token=$null;$raw=$null;[GC]::Collect()}