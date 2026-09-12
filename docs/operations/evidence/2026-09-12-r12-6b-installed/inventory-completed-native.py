from pathlib import Path
import ctypes,json,hashlib,shutil
out=Path(__file__).parent;root=Path('E:/r12client/apps/android_shell/build/app/intermediates')
assert json.loads(Path('C:/r12-c05-setup-privacy-20260912/android-build-progress-store-only.json').read_bytes())['status']=='PASS'
k=ctypes.WinDLL('kernel32',use_last_error=True);k.GetCompressedFileSizeW.argtypes=[ctypes.c_wchar_p,ctypes.POINTER(ctypes.c_ulong)];k.GetCompressedFileSizeW.restype=ctypes.c_ulong
def alloc(p):
    hi=ctypes.c_ulong();lo=k.GetCompressedFileSizeW(str(p),ctypes.byref(hi));assert lo!=0xffffffff or ctypes.get_last_error()==0;return hi.value*2**32+lo
rows=[]
for group in ['merged_native_libs','stripped_native_libs']:
    for p in sorted((root/group).rglob('*.so')):
        assert not p.is_symlink();rows.append({'path':str(p),'bytes':p.stat().st_size,'allocated':alloc(p),'group':group})
(out/'completed-native-inventory.json').write_text(json.dumps({'files':rows,'free_c':shutil.disk_usage('C:/').free,'free_e':shutil.disk_usage('E:/').free},indent=2)+'\n')
print(json.dumps({'files':len(rows),'groups':{g:{'bytes':sum(x['bytes'] for x in rows if x['group']==g),'allocated':sum(x['allocated'] for x in rows if x['group']==g)} for g in ['merged_native_libs','stripped_native_libs']}}))
