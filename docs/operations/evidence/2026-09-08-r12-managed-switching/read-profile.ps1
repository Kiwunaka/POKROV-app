param([ValidatePattern('^[a-z0-9-]+$')][string]$Label)
$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$p='C:/ProgramData/POKROV/ServiceRuntime/working/configs/managed-profile.json'
$last='';$count=0
for($i=0;$i -lt 900;$i++){
 if(Test-Path -LiteralPath 'C:/Users/Public/R12Managed/profile-sampler.stop'){break}
 if(Test-Path -LiteralPath $p){
  $bytes=[IO.File]::ReadAllBytes($p)
  $hasher=[Security.Cryptography.SHA256]::Create()
  try{$digest=-join($hasher.ComputeHash($bytes)|ForEach-Object ToString x2)}finally{$hasher.Dispose()}
  if($digest -ne $last){
   $j=[Text.Encoding]::UTF8.GetString($bytes)|ConvertFrom-Json
   $contracts=@($j.endpoints|ForEach-Object {$_.contract_id}|Where-Object {$_ -match '^pokrov\.awg(2|31)\.endpoint\.v1$'})
   $r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');label=$Label;profile_sha256=$digest;root_keys=@($j.PSObject.Properties.Name);outbound_types=@($j.outbounds.type);endpoint_types=@($j.endpoints.type);endpoint_contracts=$contracts;outbound_field_names=@($j.outbounds|ForEach-Object {@($_.PSObject.Properties.Name)}|Sort-Object -Unique);endpoint_field_names=@($j.endpoints|ForEach-Object {@($_.PSObject.Properties.Name)}|Sort-Object -Unique);raw_profile_returned=$false}
   $count++;$out=('C:/Users/Public/R12Managed/profile-'+$Label+'-'+$count+'.json')
   if(Test-Path -LiteralPath $out){throw 'Output exists'}
   $r|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $out -Encoding UTF8
   $last=$digest
  }
 }
 Start-Sleep -Seconds 1
}
