$ErrorActionPreference='Stop'
$root='C:/Users/Public/R12ObservabilityFaults'
try {
 if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
 $principal=[Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
 if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevation required for isolated VHD creation'}
 $image=[IO.Path]::GetFullPath("$root/diagnostic-fault.vhd")
 if([IO.Path]::GetDirectoryName($image) -ne [IO.Path]::GetFullPath($root)){throw 'Image outside owned fixture directory'}
 if(Test-Path -LiteralPath $image){throw 'Fixture image already exists'}
 if(Get-Volume -DriveLetter R -ErrorAction SilentlyContinue){throw 'Drive R already exists'}
 @"
create vdisk file="$image" maximum=32 type=expandable
select vdisk file="$image"
attach vdisk
create partition primary
format fs=ntfs quick label=R12_OBS_FAULT
assign letter=R
exit
"@ | Set-Content -LiteralPath "$root/create-volume.diskpart" -Encoding ASCII
 & diskpart.exe /s "$root/create-volume.diskpart" *> "$root/create-volume.log"
 if($LASTEXITCODE -ne 0){throw 'Diskpart failed'}
 $diskImage=Get-DiskImage -ImagePath $image
 $volume=Get-Volume -DriveLetter R
 $disk=Get-Partition -DriveLetter R|Get-Disk
 if(-not $diskImage.Attached -or $volume.FileSystemLabel -ne 'R12_OBS_FAULT' -or $disk.Size -gt 33554432 -or $disk.Size -lt 30000000){throw 'Unexpected isolated disk identity'}
 [ordered]@{status='PASS';utc=[DateTime]::UtcNow.ToString('o');image_path=$image;image_attached=$diskImage.Attached;device_path=$diskImage.DevicePath;disk_number=$disk.Number;disk_size_bytes=$disk.Size;volume_label=$volume.FileSystemLabel;volume_size_bytes=$volume.Size;volume_free_bytes=$volume.SizeRemaining;drive_letter='R';system_disk_changed=$false}|ConvertTo-Json|Set-Content -LiteralPath "$root/volume-created.json" -Encoding UTF8
} catch {
 [ordered]@{status='FAIL';utc=[DateTime]::UtcNow.ToString('o');error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath "$root/volume-create-error.json" -Encoding UTF8
 exit 1
}
