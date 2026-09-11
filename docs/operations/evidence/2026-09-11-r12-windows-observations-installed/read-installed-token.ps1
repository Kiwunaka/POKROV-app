$ErrorActionPreference='Stop'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
Add-Type @"
using System;using System.Runtime.InteropServices;using System.ComponentModel;
public static class R12TokenRead {
 [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr OpenProcess(uint a,bool i,int p);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,uint a,out IntPtr t);
 [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr t,int c,out int v,int n,out int r);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
 public static bool Elevated(int pid){IntPtr p=OpenProcess(0x1000,false,pid);if(p==IntPtr.Zero)throw new Win32Exception();try{IntPtr t;if(!OpenProcessToken(p,8,out t))throw new Win32Exception();try{int v,r;if(!GetTokenInformation(t,20,out v,4,out r))throw new Win32Exception();return v!=0;}finally{CloseHandle(t);}}finally{CloseHandle(p);}}
}
"@
$ui=@(Get-Process pokrov_windows -ErrorAction Stop)
if($ui.Count -ne 1 -or $ui[0].Path -ne 'C:\Program Files\POKROV\pokrov_windows.exe'){throw 'Wrong UI'}
$elevated=[R12TokenRead]::Elevated($ui[0].Id)
$service=Get-CimInstance Win32_Service -Filter "Name='POKROVService'"
$acl=& sc.exe sdshow POKROVService
if($LASTEXITCODE -ne 0){throw 'SCM read failed'}
$descriptor=[Security.AccessControl.RawSecurityDescriptor]::new(($acl -join '').Trim())
$publicWrite=$false
foreach($ace in $descriptor.DiscretionaryAcl){if($ace.AceQualifier -eq 'AccessAllowed' -and $ace.SecurityIdentifier.Value -in @('S-1-1-0','S-1-5-11','S-1-5-32-545') -and ($ace.AccessMask -band 0x100D0172)){$publicWrite=$true}}
$sha=[Security.Cryptography.SHA256]::Create()
try{$aclHash=-join($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($acl -join '').Trim()))|ForEach-Object ToString x2)}finally{$sha.Dispose()}
$before=[IO.File]::ReadAllText('C:/Users/Public/R12Upgrade90420260911/pre-upgrade-connected.json')|ConvertFrom-Json
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');ui_pid=$ui[0].Id;ui_session=$ui[0].SessionId;ui_elevated=$elevated;service_state=$service.State;service_account=$service.StartName;service_acl_sha256=$aclHash;service_acl_matches_previous_retained=($aclHash -eq $before.service_acl_sha256);service_broad_group_mutation_allowed=$publicWrite;ui_loaded_core=@($ui[0].Modules|Where-Object ModuleName -eq 'pokrov-core.dll').Count -gt 0;ui_launch='installer_finish_default'}
$r|ConvertTo-Json -Depth 6|Set-Content -LiteralPath 'C:/Users/Public/R12N05Windows20260911/installed-ui-token.json' -Encoding UTF8
if($elevated -or $publicWrite -or $r.ui_loaded_core){throw 'Installed UI/service boundary failed'}
