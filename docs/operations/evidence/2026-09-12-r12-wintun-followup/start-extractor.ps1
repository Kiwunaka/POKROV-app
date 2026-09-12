$ErrorActionPreference='Stop'
$taskOut='C:/r12-c05-wintun-20260912'
$taskVBox='C:/Program Files/Oracle/VirtualBox/VBoxManage.exe'
$taskVm='POKROV-r12-b08-linux-20260906'
$taskRunning=@(& $taskVBox list runningvms)
if($LASTEXITCODE -ne 0 -or ($taskRunning -join '').Trim()){throw 'Another VM is running'}
$taskInfo=@(& $taskVBox showvminfo $taskVm --machinereadable)
if($LASTEXITCODE -ne 0 -or -not ($taskInfo -contains 'VMState="poweroff"')){throw 'Extractor VM not powered off'}
$taskVolumes=@(Get-Volume -DriveLetter C,E | Select-Object DriveLetter,SizeRemaining)
if(($taskVolumes|Where-Object DriveLetter -eq 'C').SizeRemaining -lt 40GB -or ($taskVolumes|Where-Object DriveLetter -eq 'E').SizeRemaining -lt (40GB+350MB)){throw 'Extractor storage reserve unavailable'}
$taskMemory=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory*1KB
if($taskMemory -lt 8GB){throw 'Host memory reserve unavailable'}
$taskReceipt=@{status='PASS_START_BUDGET';vm=$taskVm;initial_state='poweroff';vm_memory_mib=3072;vm_cpus=2;host_free_memory_bytes=$taskMemory;volumes=$taskVolumes;host_disk_floor_bytes=40GB;guest_disk_growth_budget_bytes=350MB;guest_disk_file='E:/r12-b08-linux-lab/lab.vdi';guest_disk_file_bytes=(Get-Item E:/r12-b08-linux-lab/lab.vdi).Length;operation='Reuse existing extractor for exact setup archive; unprivileged network-isolated extraction, no installer execution';paid_services=$false;utc=[DateTime]::UtcNow.ToString('o')}
$taskReceipt|ConvertTo-Json -Depth 5|Set-Content "$taskOut/extractor-vm-budget.json"
& $taskVBox startvm $taskVm --type headless *> "$taskOut/extractor-vm-start.log"
if($LASTEXITCODE -ne 0){throw 'VM start failed'}
Write-Output 'Started existing extractor lab headless within 350MiB growth and 3GiB RAM budget'
