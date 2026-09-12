from pathlib import Path
import hashlib,json,subprocess,ctypes,datetime,psutil
assert not any((p.info["name"] or "").lower() in ["java.exe","dart.exe"] for p in psutil.process_iter(["name"]))
out=Path('C:/r12-marker-packages-20260912');root=Path('E:/r12client/apps/android_shell/build/app/intermediates/merged_native_libs/directRelease').resolve()
assert json.loads((out/'android-direct-progress.json').read_bytes())['status']=='STOPPED_STORAGE_GUARD'
assert str(root).lower().startswith('e:\\r12client\\apps\\android_shell\\build\\app\\intermediates\\')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
files=sorted(root.rglob('*.so'));assert files and not any(p.is_symlink() for p in files)
k=ctypes.WinDLL('kernel32',use_last_error=True);k.GetCompressedFileSizeW.argtypes=[ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_ulong)];k.GetCompressedFileSizeW.restype=ctypes.c_ulong
def allocation(p):
 hi=ctypes.c_ulong();lo=k.GetCompressedFileSizeW(str(p),ctypes.byref(hi));assert lo!=0xffffffff or ctypes.get_last_error()==0;return hi.value*2**32+lo
rows=[{'path':str(p),'bytes':p.stat().st_size,'sha256':sha(p),'allocated_before':allocation(p)} for p in files]
(out/'stopped-direct-intermediates-compression-plan.json').write_text(json.dumps(rows,indent=2)+'\n')
for row in rows:
 r=subprocess.run(['compact.exe','/C','/EXE:LZX','/I','/Q','/F',row['path']],capture_output=True)
 assert r.returncode==0
 p=Path(row['path']);assert p.stat().st_size==row['bytes'] and sha(p)==row['sha256'];row['allocated_after']=allocation(p)
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS_ALL_BYTES_PRESERVED','reason':'Terminal Android build exceeded estimated intermediate storage; preserve 40GiB floor without deleting evidence','files':rows,'saved_bytes':sum(x['allocated_before']-x['allocated_after'] for x in rows)}
(out/'stopped-direct-intermediates-compression.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k!='files'}))
