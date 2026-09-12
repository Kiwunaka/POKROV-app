$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$taskDir='C:/Users/Public/R126b20260912'
& "$taskDir/profile-restoration.ps1"
& "$taskDir/canary-state.ps1" after | Out-File -LiteralPath "$taskDir/canary-recovery-state.json" -Encoding utf8
& "$taskDir/scan-sinks.ps1" | Out-File -LiteralPath "$taskDir/canary-recovery-sinks.json" -Encoding utf8
& "$taskDir/outbox-readback.ps1" | Out-File -LiteralPath "$taskDir/canary-outbox.json" -Encoding utf8
$taskProbe='C:/Program Files/POKROV/r12_v01_probe_6b.exe'
if((Get-FileHash -LiteralPath $taskProbe).Hash.ToLowerInvariant() -ne 'f404cef0e74c6b22dfd55549a11fc2abb1d926ae221f2972317e872c3c86fb01'){throw 'Probe cleanup identity mismatch'}
Remove-Item -LiteralPath $taskProbe
[ordered]@{utc=[DateTime]::UtcNow.ToString('o');task_probe_removed=(-not(Test-Path -LiteralPath $taskProbe));other_installed_files_removed=$false}|ConvertTo-Json|Out-File -LiteralPath "$taskDir/canary-probe-cleanup.json" -Encoding utf8
