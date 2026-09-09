$ErrorActionPreference='Stop'
$lab='C:/Users/Public/R12Managed'
if((Get-CimInstance Win32_ComputerSystemProduct).UUID.ToLowerInvariant() -ne 'e42043a3-dd4d-452b-b151-410ad5d49543'){throw 'Wrong VM'}
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class R12Session {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls,string title);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll",SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr h,uint msg,UIntPtr w,IntPtr l,uint flags,uint timeout,out UIntPtr result);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int mode);
}
'@
$h=[R12Session]::FindWindow('POKROV_WINDOWS_UI_WINDOW_V1','POKROV')
if($h -eq [IntPtr]::Zero){throw 'UI missing'}
[uint32]$uiPid=0
$null=[R12Session]::GetWindowThreadProcessId($h,[ref]$uiPid)
$p=Get-Process -Id $uiPid
if($p.Path -ne 'C:\Program Files\POKROV\pokrov_windows.exe'){throw 'Wrong UI'}
function Send([uint32]$message,[uint64]$w,[int64]$l){
 [UIntPtr]$result=[UIntPtr]::Zero
 $ok=[R12Session]::SendMessageTimeout($h,$message,[UIntPtr]$w,[IntPtr]$l,2,5000,[ref]$result)
 if($ok -eq [IntPtr]::Zero){throw 'Window message timeout'}
 return $result.ToUInt64()
}
$r=[ordered]@{utc=[DateTime]::UtcNow.ToString('o');ui_sha256=(Get-FileHash -LiteralPath $p.Path -Algorithm SHA256).Hash.ToLowerInvariant();ui_pid=$uiPid}
$r.query_accepted=((Send 0x11 0 1) -eq 1)
$p.Refresh();$r.query_did_not_exit=(-not $p.HasExited)
$null=Send 0x16 0 1
Start-Sleep -Milliseconds 300
$p.Refresh();$r.cancelled_end_did_not_exit=(-not $p.HasExited)
$null=Send 0x10 0 0
Start-Sleep -Seconds 1
$p.Refresh();$r.normal_close_hides_without_exit=(-not $p.HasExited -and -not [R12Session]::IsWindowVisible($h))
[R12Session]::ShowWindow($h,9)|Out-Null
$r.restored_same_process=(-not $p.HasExited -and [R12Session]::IsWindowVisible($h))
$r.status=if($r.query_accepted -and $r.query_did_not_exit -and $r.cancelled_end_did_not_exit -and $r.normal_close_hides_without_exit -and $r.restored_same_process){'PASS'}else{'FAIL'}
$r|ConvertTo-Json|Set-Content -LiteralPath "$lab/session-end-probe.json" -Encoding UTF8
if($r.status -ne 'PASS'){throw 'Session-end behavior failed'}
