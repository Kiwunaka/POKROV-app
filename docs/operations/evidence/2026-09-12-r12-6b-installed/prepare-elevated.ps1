$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
if((Get-FileHash -LiteralPath C:/Users/Public/R126b20260912/r12_v01_probe_6b.exe).Hash -ne 'F404CEF0E74C6B22DFD55549A11FC2ABB1D926AE221F2972317E872C3C86FB01'){throw 'Probe bytes mismatch'}
if(Test-Path -LiteralPath 'C:/Program Files/POKROV/r12_v01_probe_6b.exe'){throw 'Probe target already exists'}
Copy-Item -LiteralPath C:/Users/Public/R126b20260912/r12_v01_probe_6b.exe -Destination 'C:/Program Files/POKROV/r12_v01_probe_6b.exe'
& C:/Users/Public/R126b20260912/canary-state.ps1 before | Out-File -LiteralPath C:/Users/Public/R126b20260912/state-before-capture.json -Encoding utf8
& C:/Users/Public/R126b20260912/scan-sinks.ps1 | Out-File -LiteralPath C:/Users/Public/R126b20260912/scan-before.json -Encoding utf8
[ordered]@{status='PASS_PREPARED';utc=[DateTime]::UtcNow.ToString('o');probe_sha256=(Get-FileHash -LiteralPath 'C:/Program Files/POKROV/r12_v01_probe_6b.exe').Hash.ToLowerInvariant()}|ConvertTo-Json|Out-File -LiteralPath C:/Users/Public/R126b20260912/prepared.json -Encoding utf8
