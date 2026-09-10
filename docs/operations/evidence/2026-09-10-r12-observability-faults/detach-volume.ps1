$ErrorActionPreference='Stop'
$root='C:/Users/Public/R12ObservabilityFaults'
try {
 if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
 $store='C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/pokrov-observability'
 if((Get-Item -LiteralPath $store -Force).LinkType){throw 'Restore diagnostic directory before detaching'}
 if(Test-Path -LiteralPath 'C:/Users/pokrovtest/AppData/Roaming/space.pokrov/POKROV/pokrov-observability-r12-diskfull-preserved'){throw 'Original directory still preserved rather than restored'}
 $image=[IO.Path]::GetFullPath("$root/diagnostic-fault.vhd")
 if([IO.Path]::GetDirectoryName($image) -ne [IO.Path]::GetFullPath($root)){throw 'Image escaped fixture directory'}
 @"
select vdisk file="$image"
detach vdisk
exit
"@|Set-Content -LiteralPath "$root/detach-volume.diskpart" -Encoding ASCII
 & diskpart.exe /s "$root/detach-volume.diskpart" *> "$root/detach-volume.log"
 if($LASTEXITCODE -ne 0 -or (Get-DiskImage -ImagePath $image).Attached){throw 'VHD still attached'}
 [ordered]@{status='PASS';utc=[DateTime]::UtcNow.ToString('o');image_retained=$true;image_attached=$false;drive_r_present=[bool](Get-Volume -DriveLetter R -ErrorAction SilentlyContinue)}|ConvertTo-Json|Set-Content -LiteralPath "$root/volume-detached.json" -Encoding UTF8
} catch {
 [ordered]@{status='FAIL';utc=[DateTime]::UtcNow.ToString('o');error=$_.Exception.Message}|ConvertTo-Json|Set-Content -LiteralPath "$root/volume-detach-error.json" -Encoding UTF8
 exit 1
}
