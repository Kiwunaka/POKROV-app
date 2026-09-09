$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$probe='C:/Program Files/POKROV/r12_managed_probe.exe'
$before=& $probe status|ConvertFrom-Json
if(-not $before.running -or -not $before.effective_matches_staged){throw 'Connected baseline required'}
$ui=@(Get-Process pokrov_windows -ErrorAction Stop)
if($ui.Count -ne 1 -or $ui[0].SessionId -ne 1){throw 'Unique interactive UI required'}
if([IO.Path]::GetFullPath($ui[0].Path) -ne 'C:\Program Files\POKROV\pokrov_windows.exe'){throw 'Wrong UI path'}
if((Get-FileHash -LiteralPath $ui[0].Path -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c8e1f31696525f50a108d5fb7f5f310423e08061e4bc825f7f23204fa150d515'){throw 'Wrong UI bytes'}
$serviceBefore=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');ui_pid=$ui[0].Id;service_pid_before=$serviceBefore.ProcessId;method='Stop-Process exact UI PID Force';before=$before}
Stop-Process -Id $ui[0].Id -Force
Start-Sleep -Seconds 2
$r.after=& $probe status|ConvertFrom-Json
$r.ui_count_after=@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count
$r.service_pid_after=(Get-CimInstance Win32_Service -Filter "Name='POKROVService'").ProcessId
$r.service_pid_unchanged=($r.service_pid_before -eq $r.service_pid_after)
$r|ConvertTo-Json -Depth 5|Set-Content C:/Users/Public/R12Managed/ui-termination.json -Encoding UTF8
