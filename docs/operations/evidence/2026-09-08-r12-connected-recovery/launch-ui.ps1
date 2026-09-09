$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$path='C:/Program Files/POKROV/pokrov_windows.exe'
if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'c8e1f31696525f50a108d5fb7f5f310423e08061e4bc825f7f23204fa150d515'){throw 'Wrong UI bytes'}
if(@(Get-Process pokrov_windows -ErrorAction SilentlyContinue).Count -ne 0){throw 'UI already running'}
$n='R12RecoveryLaunch'
if(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue){throw 'Task already exists'}
$a=New-ScheduledTaskAction -Execute $path
$p=New-ScheduledTaskPrincipal -UserId ($env:COMPUTERNAME+'\'+$env:USERNAME) -LogonType Interactive -RunLevel Limited
try{Register-ScheduledTask -TaskName $n -Action $a -Principal $p|Out-Null;Start-ScheduledTask -TaskName $n;Start-Sleep -Seconds 1}finally{Unregister-ScheduledTask -TaskName $n -Confirm:$false}
