from pathlib import Path
import ctypes, json

root = Path('E:/r12client/apps/android_shell')
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.GetCompressedFileSizeW.argtypes = [ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_ulong)]
kernel.GetCompressedFileSizeW.restype = ctypes.c_ulong
def allocated(path):
    high = ctypes.c_ulong()
    low = kernel.GetCompressedFileSizeW(str(path), ctypes.byref(high))
    assert low != 0xFFFFFFFF or ctypes.get_last_error() == 0
    return (high.value << 32) | low
rows = []
for directory in ['build', '.dart_tool/flutter_build']:
    folder = root / directory
    for p in folder.rglob('*'):
        if p.is_file():
            assert p.resolve().is_relative_to(root.resolve()) and not p.is_symlink() and not p.is_junction()
            stat = p.stat()
            rows.append({'path': p.relative_to(root).as_posix(), 'bytes': stat.st_size, 'allocated': allocated(p), 'compressed': bool(stat.st_file_attributes & 0x800)})
groups = {}
for row in rows:
    parts = row['path'].split('/')
    name = '/'.join(parts[:4]) if parts[0] == 'build' else '/'.join(parts[:2])
    group = groups.setdefault(name, {'path': name, 'files': 0, 'bytes': 0, 'allocated': 0, 'uncompressed_files': 0})
    for key in ['bytes', 'allocated']:
        group[key] += row[key]
    group['files'] += 1
    group['uncompressed_files'] += not row['compressed']
report = {'status': 'READ_ONLY', 'files': rows, 'groups': sorted(groups.values(), key=lambda r: r['allocated'], reverse=True)}
(Path(__file__).parent / 'android-storage-inventory.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
print(json.dumps({'files': len(rows), 'allocated': sum(r['allocated'] for r in rows), 'bytes': sum(r['bytes'] for r in rows), 'largest_groups': report['groups'][:20]}, indent=2))
