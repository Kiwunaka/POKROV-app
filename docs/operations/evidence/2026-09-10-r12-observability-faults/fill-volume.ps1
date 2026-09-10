$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
$root='C:/Users/Public/R12ObservabilityFaults'
$created=[IO.File]::ReadAllText("$root/volume-created.json")|ConvertFrom-Json
$volume=Get-Volume -DriveLetter R
$disk=Get-Partition -DriveLetter R|Get-Disk
if($volume.FileSystemLabel -ne 'R12_OBS_FAULT' -or $disk.Number -ne $created.disk_number -or $disk.Size -ne 33554432){throw 'Wrong volume'}
if([IO.File]::ReadAllText('R:/owned-volume.marker') -ne 'R12 diagnostic disk-full isolated volume 20260910'){throw 'Marker mismatch'}
if(Test-Path -LiteralPath 'R:/fill.bin'){throw 'Already filled'}
$total=0L;$errors=@();$stream=[IO.File]::Open('R:/fill.bin',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
try {
 foreach($size in @(1048576,4096)){
  $buffer=New-Object byte[] $size
  while($total -le 33554432){
   try{$stream.Write($buffer,0,$buffer.Length);$stream.Flush($true);$total+=$size}
   catch [IO.IOException]{$errors+=($_.Exception.InnerException.HResult -band 0xFFFF);if(-not $_.Exception.InnerException){$errors[-1]=$_.Exception.HResult -band 0xFFFF};break}
  }
 }
} finally {$stream.Dispose()}
$probeError=0
try {[IO.File]::WriteAllBytes('R:/pokrov-observability/diskfull-probe.bin',(New-Object byte[] 8192))}
catch [IO.IOException]{$exception=$_.Exception;if($exception.InnerException){$exception=$exception.InnerException};$probeError=$exception.HResult -band 0xFFFF}
$remaining=(Get-Volume -DriveLetter R).SizeRemaining
if($probeError -ne 112 -or $remaining -ge 8192){throw "Expected ERROR_DISK_FULL; got $probeError free $remaining"}
[ordered]@{status='PASS_ACTUAL_ERROR_DISK_FULL';utc=[DateTime]::UtcNow.ToString('o');drive_letter='R';volume_size_bytes=$volume.Size;filled_bytes=$total;remaining_bytes=$remaining;probe_error_win32=$probeError;filler_error_codes=$errors;system_free_bytes=(Get-Volume -DriveLetter C).SizeRemaining}|ConvertTo-Json|Set-Content -LiteralPath "$root/disk-full.json" -Encoding UTF8
