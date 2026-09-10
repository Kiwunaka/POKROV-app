import ctypes
import hashlib
import io
import json
import pathlib
import struct
import subprocess
import zipfile
from datetime import datetime, timezone

OUT = pathlib.Path(__file__).parent
CLIENT = pathlib.Path('E:/r12client')
CORE = pathlib.Path('C:/r12coreprivacy')
OLD = pathlib.Path('C:/r12-v01-core-20260910')
CRASH = pathlib.Path('C:/r12-crash-preview-20260910')
SOURCE = 'e18fa6073d310623fae003689af439fb11d4dc5e'
PIN = 'c8b0461c1975ef96e32024774300a5829b9fdc43'

def read(path):
    return json.loads(path.read_bytes())

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], text=True).strip()

seed = read(CLIENT / 'config/runtime-artifacts.seed.json')
assert seed['core']['source_commit'] == PIN == git(CORE, 'rev-parse', 'HEAD')
comparisons = []
for path in ['config/runtime-artifacts.seed.json', 'packages/runtime_engine',
             'packages/observability_contracts', 'apps/android_shell/android/app',
             'apps/windows_shell/windows/runner', 'apps/windows_shell/windows/service',
             '.github/workflows/release-v2-contract.yml', 'scripts/run-tests.ps1']:
    current = git(CLIENT, 'rev-parse', f'HEAD:{path}')
    exact = git(CLIENT, 'rev-parse', f'{SOURCE}:{path}')
    assert current == exact, path
    assert not git(CLIENT, 'diff', '--numstat', '--', path), path
    comparisons.append({'path': path, 'git_object': current})

binding = read(CLIENT / 'docs/operations/evidence/2026-09-10-r12-core-privacy-binding/binding.json')
artifacts = []
for lane in ['android', 'windows']:
    evidence = read(OLD / f'{lane}-evidence.json')
    assert evidence['source']['commit'] == PIN
    for rel, sha in evidence['contracts'].items():
        # Build evidence binds the exact committed source bytes.
        raw = subprocess.check_output(['git', '-C', str(CORE), 'show', f'{PIN}:{rel}'])
        assert hashlib.sha256(raw).hexdigest() == sha, rel
    for record in evidence['reproducibility']['files']:
        for suffix in ['a', 'b']:
            path = OLD / f'{lane}-{suffix}' / record['path']
            assert digest(path) == record['sha256'], path
        artifacts.append({'lane': lane, **record})

aar = CLIENT / 'apps/android_shell/android/app/libs/pokrov-core.aar'
dll = CLIENT / 'apps/windows_shell/windows/runner/resources/runtime/pokrov-core.dll'
assert digest(aar) == seed['core']['artifact_provenance']['reproducible_build']['android']['sha256']
assert digest(dll) == seed['core']['artifact_provenance']['reproducible_build']['windows']['sha256']
abis = {'armeabi-v7a': (1, 40), 'arm64-v8a': (2, 183), 'x86': (1, 3), 'x86_64': (2, 62)}
android = []
with zipfile.ZipFile(aar) as archive:
    for abi, (bits, machine) in abis.items():
        raw = archive.read(f'jni/{abi}/libpokrov-core.so')
        assert raw[:4] == b'\x7fELF' and raw[4] == bits
        assert struct.unpack_from('<H', raw, 18)[0] == machine
        android.append({'abi': abi, 'elf_class': bits, 'machine': machine,
                        'sha256': hashlib.sha256(raw).hexdigest()})
    with zipfile.ZipFile(io.BytesIO(archive.read('classes.jar'))) as classes:
        required = ['space/pokrov/core/libbox/Libbox.class',
                    'space/pokrov/core/libbox/CommandServer.class',
                    'space/pokrov/core/libbox/OperationalEvent.class',
                    'space/pokrov/core/libbox/OperationalEventHandler.class']
        for name in required:
            assert name in classes.namelist(), name

contract = read(CORE / 'config/abi-contract.json')
library = ctypes.CDLL(str(dll))
for name in contract['desktop_abi']['exports']:
    getattr(library, name)
library.pokrovCoreAbiVersion.restype = ctypes.c_int
assert library.pokrovCoreAbiVersion() == 2
library.pokrovCoreCapabilities.restype = ctypes.c_void_p
library.freeString.argtypes = [ctypes.c_void_p]
pointer = library.pokrovCoreCapabilities()
assert pointer
try:
    descriptor = json.loads(ctypes.string_at(pointer))
finally:
    library.freeString(pointer)
assert descriptor == contract['descriptor'], descriptor

ffi = read(OLD / 'fixed/child-receipt.json')
assert ffi['dll_sha256'] == digest(dll)
assert ffi['setup_ok'] and ffi['config_rejected']
events = ffi['structured_events']
assert all(e['abi'] == 1 and e['schema'] == 1 for e in events)
assert any(e['outcome'] == 'failed' and e['code'] == 'CORE-005' for e in events)

ci = read(CRASH / 'client-ci-merge.json')
assert ci['source'] == '503979fd1f12f2586e33064386d7f3375425ad0a'
run = ci['runs'][0]
assert run['conclusion'] == 'success'
steps = run['jobs'][0]['steps']
assert any(s['name'] == 'Run client unit and Android flavor tests' and s['conclusion'] == 'success' for s in steps)
assert git(CLIENT, 'rev-parse', SOURCE + '^{tree}') == git(CLIENT, 'rev-parse', ci['source'] + '^{tree}')
expected = read(CRASH / 'windows-expected.json')
assert expected['client_source'] == SOURCE and expected['core_source'] == PIN
assert expected['files']['pokrov-core.dll'] == digest(dll)
wizard = read(CRASH / 'wizard-readback.json')
assert wizard['client_source'] == SOURCE and wizard['core_source'] == PIN
assert wizard['matched_files'] == 304
runtime = read(CRASH / 'runtime-verification.json')
assert runtime['client_source'] == SOURCE and all(runtime['checks'].values())
core_ci = read(OLD / 'core-ci-merge.json')
assert core_ci['status'] == 'PASS'
assert git(CORE, 'rev-parse', PIN + '^{tree}') == git(CORE, 'rev-parse', core_ci['source'] + '^{tree}')
for name, marker in [('abi-contract.log', 'desktop=2 descriptor=1 events=1 exports=15'),
                     ('observability-contract.log', 'contracts=2'),
                     ('awg2-contract.log', 'contract OK'), ('awg31-contract.log', 'contract OK'),
                     ('hy2-contract.log', 'contract OK'), ('consumer-abi-tests.log', '+6: All tests passed!')]:
    assert marker in (OUT / name).read_text(encoding='utf-8-sig'), name

inputs = [OLD / 'android-evidence.json', OLD / 'windows-evidence.json',
          OLD / 'fixed/child-receipt.json', CRASH / 'client-ci-merge.json',
          CRASH / 'windows-expected.json', CRASH / 'wizard-readback.json',
          CRASH / 'runtime-verification.json', CRASH / 'crash-client-windows-build.log',
          OLD / 'full-test.log', OLD / 'windows-100-cycle.log', OLD / 'core-ci-merge.json',
          *sorted(OUT.glob('*.log'))]
for entry in binding['logs']:
    path = pathlib.Path(entry['local_path'])
    assert digest(path) == entry['sha256'], path
result = {
    'status': 'PASS_C01_SOURCE_ARTIFACT_CONSUMER_MATRIX',
    'captured_at': datetime.now(timezone.utc).isoformat(),
    'origin': 'current-origin local; retained exact hosted CI and owned Win11 VM evidence',
    'client_source': SOURCE, 'client_merge': ci['source'], 'core_source': PIN,
    'source_comparisons': comparisons, 'reproduced_artifacts': artifacts,
    'android_native_architectures': android, 'android_generated_classes': required,
    'windows_descriptor': descriptor, 'windows_resolved_exports': contract['desktop_abi']['exports'],
    'retained_events': events, 'ci_run': run['html_url'],
    'inputs': [{'path': str(p), 'sha256': digest(p)} for p in inputs],
    'boundaries': ['No new build, device run, lifecycle run or hosted CI run',
                   'No Android JNI execution on a physical device for this Core',
                   'No public release, signing, Win10 or network matrix acceptance',
                   'C02 lifecycle/resource and C05 license/privacy gates remain separate'],
}
(OUT / 'audit.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'status': result['status'], 'source_comparisons': len(comparisons),
                  'artifacts': len(artifacts), 'android_abis': len(android), 'exports': 15}))
