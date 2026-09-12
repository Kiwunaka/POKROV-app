$ErrorActionPreference='Stop'
$root='C:/r12-c05-setup-privacy-20260912/V01_CANARY_SETUP_PATH'
$dll='C:/r12corec02/dist/windows/pokrov-core.dll'
$hash=(Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash.ToLowerInvariant()
if($hash -ne '40101389b7713b869a9472bd3afe3aa19000b1d98f79d50cb88b61a235be531e'){throw 'Wrong packaged DLL'}
New-Item -ItemType Directory -Path "$root/fixture" -ErrorAction Stop|Out-Null
foreach($part in 'base','working','temp','working/data'){New-Item -ItemType Directory -Path "$root/fixture/$part" -ErrorAction Stop|Out-Null}
$markers=[ordered]@{credentials='V01_CANARY_CREDENTIAL_7bd2';config='V01_CANARY_CONFIG_b861';url='https://v01.invalid/private';ip='203.0.113.71';path='V01_CANARY_SETUP_PATH';pii='v01@example.invalid'}
$config=@{outbounds=@(@{type=($markers.Values -join ' ')})}|ConvertTo-Json -Depth 5 -Compress
[IO.File]::WriteAllText("$root/fixture/input.json",$config,[Text.UTF8Encoding]::new($false))
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class R12PrivacyFfi {
 [DllImport("C:/r12corec02/dist/windows/pokrov-core.dll",CallingConvention=CallingConvention.Cdecl,CharSet=CharSet.Ansi)]
 public static extern IntPtr setup(string b,string w,string t,int mode,string listen,string secret,long port,byte debug);
 [DllImport("C:/r12corec02/dist/windows/pokrov-core.dll",CallingConvention=CallingConvention.Cdecl,CharSet=CharSet.Ansi)]
 public static extern IntPtr start(string path,byte disableMemoryLimit);
 [DllImport("C:/r12corec02/dist/windows/pokrov-core.dll",CallingConvention=CallingConvention.Cdecl)]
 public static extern void freeString(IntPtr value);
 public static string Read(IntPtr value) {
  if(value==IntPtr.Zero)return "";
  try{return Marshal.PtrToStringAnsi(value);}finally{freeString(value);}
 }
}
'@
$setup=[R12PrivacyFfi]::Read([R12PrivacyFfi]::setup("$root/fixture/base","$root/fixture/working","$root/fixture/temp",0,'','',0,0))
if($setup.Length -ne 0){throw 'FFI setup failed'}
$result=[R12PrivacyFfi]::Read([R12PrivacyFfi]::start("$root/fixture/input.json",0))
if($result.Length -eq 0){throw 'Expected rejected config'}
$contains=[ordered]@{}
foreach($entry in $markers.GetEnumerator()){$contains[$entry.Key]=$result.Contains($entry.Value)}
$record=[ordered]@{setup_ok=$true;config_rejected=$true;dll_sha256=$hash;ffi_return_contains=$contains;closed_core_code=$result.Contains('CORE-005');debug=$false;live_profile_used=$false}
$record|ConvertTo-Json -Depth 5|Set-Content -LiteralPath "$root/child-receipt.json" -Encoding UTF8
