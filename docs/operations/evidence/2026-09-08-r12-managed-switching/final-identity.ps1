$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$expected=[IO.File]::ReadAllText('C:/Users/Public/R12Managed/expected-bundle-v3.json')|ConvertFrom-Json
$matched=0
foreach($f in $expected.files.PSObject.Properties){
 if((Get-FileHash -LiteralPath (Join-Path 'C:/Program Files/POKROV' $f.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $f.Value){throw 'Installed package mismatch'}
 $matched++
}
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');installed_files_verified=$matched;ui_sha256=$expected.files.'pokrov_windows.exe';service_sha256=$expected.files.'pokrov_service.exe';probe_sha256=(Get-FileHash -LiteralPath 'C:/Program Files/POKROV/r12_managed_probe.exe' -Algorithm SHA256).Hash.ToLowerInvariant();sampler_stop_requested=(Test-Path 'C:/Users/Public/R12Managed/profile-sampler.stop');temporary_task_absent=($null -eq (Get-ScheduledTask -TaskName R12-Read-Profile -ErrorAction SilentlyContinue));elevated=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)}
$r|ConvertTo-Json|Set-Content C:/Users/Public/R12Managed/routing-final-identity.json -Encoding UTF8
