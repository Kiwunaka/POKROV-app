$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count){throw 'UI already running'}
$n='POKROV-R12-Upgrade904-Launch'
if(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue){throw 'Task exists'}
$a=New-ScheduledTaskAction -Execute 'C:/Program Files/POKROV/pokrov_windows.exe' -WorkingDirectory 'C:/Program Files/POKROV'
$p=New-ScheduledTaskPrincipal -UserId ($env:COMPUTERNAME+'\'+$env:USERNAME) -LogonType Interactive -RunLevel Limited
try{Register-ScheduledTask -TaskName $n -Action $a -Principal $p|Out-Null;Start-ScheduledTask -TaskName $n;Start-Sleep -Seconds 3;Get-Process pokrov_windows|Select-Object Id,SessionId,Path|ConvertTo-Json}finally{Unregister-ScheduledTask -TaskName $n -Confirm:$false}
