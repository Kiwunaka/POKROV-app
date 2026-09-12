from pathlib import Path
import ctypes, hashlib, json, zipfile

out = Path(__file__).parent
root = Path('E:/POKROV-workspace-cache/gradle-user-home/caches/8.11.1/transforms').resolve()
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.GetCompressedFileSizeW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_ulong)]
kernel.GetCompressedFileSizeW.restype = ctypes.c_ulong
def allocated(p):
    high = ctypes.c_ulong()
    low = kernel.GetCompressedFileSizeW(str(p), ctypes.byref(high))
    assert low != 0xFFFFFFFF or ctypes.get_last_error() == 0
    return (high.value << 32) | low
def sha(p):
    with p.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()
with zipfile.ZipFile('C:/r12corec02/dist/android/pokrov-core.aar') as archive:
    current = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in archive.namelist() if name.startswith('jni/') and name.endswith('/libpokrov-core.so')}
assert len(current) == 4
groups = []
for directory in sorted(root.iterdir()):
    native = directory / 'transformed/jetified-pokrov-core'
    aar = directory / 'transformed/jetified-pokrov-core.aar'
    if native.is_dir():
        hashes = {name: sha(native / name) for name in current}
        kind = 'extracted_core'
    elif aar.is_file():
        with zipfile.ZipFile(aar) as archive:
            hashes = {name: hashlib.sha256(archive.read(name)).hexdigest() for name in current}
        kind = 'jetified_aar'
    else:
        continue
    files = []
    for p in directory.rglob('*'):
        assert p.resolve().is_relative_to(root) and not p.is_symlink() and not p.is_junction()
        if p.is_file():
            assert p.suffix.lower() not in ['.jks', '.key', '.pem', '.pfx', '.keystore']
            files.append({'path': p.relative_to(root).as_posix(), 'bytes': p.stat().st_size, 'allocated': allocated(p), 'sha256': sha(p)})
    groups.append({'directory': str(directory), 'kind': kind, 'current_core': hashes == current, 'native_sha256': hashes, 'files': files, 'bytes': sum(x['bytes'] for x in files), 'allocated': sum(x['allocated'] for x in files)})
report = {'status': 'READ_ONLY_RETIRED_CORE_CACHE_INVENTORY', 'root': str(root), 'current_core_source': '6b271decead88b708e2fc03984b703b0a4e63ebd', 'current_native_hashes': current, 'groups': groups}
(out / 'core-cache-inventory.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
old = [g for g in groups if not g['current_core']]
print(json.dumps({'groups': len(groups), 'current_groups': len(groups) - len(old), 'retired_groups': len(old), 'retired_bytes': sum(g['bytes'] for g in old), 'retired_allocated': sum(g['allocated'] for g in old), 'retired_files': sum(len(g['files']) for g in old)}, indent=2))
