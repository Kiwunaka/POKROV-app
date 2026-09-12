from pathlib import Path
import hashlib, json, re, subprocess, zipfile

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'wintun-final-880b-20260912'
assert Path(__file__).resolve().parent == work
source = work / 'source'
baseline = base / 'artifact-build-2662f76'
progress = json.loads((work / 'progress.json').read_text())
assert progress['status'] == 'PASS_TWO_BUILDS_PER_PLATFORM'
audit = work / 'audit'; audit.mkdir()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
def parse(raw):
    deps = {}; settings = {}; last = None
    for line in raw.splitlines()[1:]:
        fields = line.strip().split('\t')
        if fields[0] == 'dep':
            last = fields[1]; deps[last] = {'version': fields[2], 'sum': fields[3] if len(fields) > 3 else ''}
        elif fields[0] == '=>':
            deps[last]['replace'] = {'path': fields[1], 'version': fields[2], 'sum': fields[3] if len(fields) > 3 else ''}
        elif fields[0] == 'build':
            key, value = fields[1].split('=', 1); settings[key] = value
    return deps, settings
result = {'status': 'RUNNING', 'source_commit': progress['source_commit'], 'source_tree': progress['source_tree'], 'baseline_source': '2662f76a3303a0518bb07fbbdc449c066de2f95b', 'binaries': [], 'errors': []}
aar = work / 'out/android-a/pokrov-core.aar'
dll = work / 'out/windows-a/pokrov-core.dll'
files = [('final-pokrov-core.buildinfo.log', dll)]
with zipfile.ZipFile(aar) as z, zipfile.ZipFile(baseline / 'out/android-a/pokrov-core.aar') as old:
    assert sorted(z.namelist()) == sorted(old.namelist())
    changed = [name for name in z.namelist() if z.read(name) != old.read(name)]
    natives = [name for name in z.namelist() if name.startswith('jni/') and name.endswith('/libpokrov-core.so')]
    assert sorted(changed) == sorted(natives)
    assert sorted(name.split('/')[1] for name in natives) == ['arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64']
    result['aar_changed_entries'] = changed
    result['aar_other_entries_unchanged'] = len(z.namelist()) - len(changed)
    for name in natives:
        abi = name.split('/')[1]; target = audit / ('libpokrov-core-' + abi + '.so')
        target.write_bytes(z.read(name)); files.append(('final-libpokrov-core-' + abi + '.buildinfo.log', target))
module = 'github.com/sagernet/sing-tun'
union = {}
for name, path in files:
    raw = subprocess.check_output([str(base / 'tools/go/bin/go'), 'version', '-m', str(path)], text=True)
    (audit / name).write_text(raw)
    deps, settings = parse(raw)
    old, old_settings = parse((baseline / 'audit' / name).read_text())
    assert set(deps) == set(old)
    changes = [key for key in deps if deps[key] != old[key]]
    assert changes == [module], changes
    assert deps[module]['version'] == old[module]['version'] == 'v0.8.0-beta.17'
    assert deps[module]['replace']['path'] in ['./engine/sing-box/replace/sing-tun', './replace/sing-tun']
    assert settings == old_settings
    assert raw.splitlines()[0].endswith('go1.26.8')
    union.update(deps)
    result['binaries'].append({'file': path.name, 'bytes': path.stat().st_size, 'sha256': sha(path), 'build_info': name, 'build_info_sha256': sha(audit / name), 'module_count': len(deps), 'changed_module': {'name': module, 'before': old[module], 'after': deps[module]}})
pe = subprocess.check_output([str(base / 'artifact-tools/mingw/usr/bin/x86_64-w64-mingw32-objdump'), '-p', str(dll)], text=True)
imports = sorted(re.findall(r'DLL Name:\s*(\S+)', pe))
assert imports == ['KERNEL32.dll', 'msvcrt.dll']
exports = set(re.findall(r'^\s*\[\s*\d+\]\s+([A-Za-z_][A-Za-z0-9_]*)\s*$', pe, re.M))
expected = json.loads((source / 'config/abi-contract.json').read_text())['desktop_abi']['exports']
assert len(expected) == 15 and set(expected) <= exports
result.update(windows_imports=imports, required_exports=expected, module_union=union)
wintun = (source / 'engine/sing-box/replace/sing-tun/internal/wintun/amd64/wintun.dll').read_bytes()
assert dll.read_bytes().count(wintun) == 1
result['embedded_wintun'] = {'sha256': hashlib.sha256(wintun).hexdigest(), 'bytes': len(wintun), 'exact_occurrences': 1}
for name in ['pokrov-core.h', 'libcronet.dll']:
    assert (work / 'out/windows-a' / name).read_bytes() == (baseline / 'out/windows-a' / name).read_bytes()
assert (work / 'out/android-a/pokrov-core-sources.jar').read_bytes() == (baseline / 'out/android-a/pokrov-core-sources.jar').read_bytes()
result['status'] = 'PASS_EXACT_ARTIFACT_COMPOSITION'
(audit / 'artifact-composition.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: v for k, v in result.items() if k not in ['module_union', 'binaries']}))
