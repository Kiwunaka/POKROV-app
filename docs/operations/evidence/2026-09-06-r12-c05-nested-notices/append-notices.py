from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('E:/r12client')
CORE = Path('E:/r12core-implementation')
OUT = Path('E:/r12-c05-utls-review')
prior = json.loads(Path('E:/r12-c05-go-notices/assembly.json').read_text())
inputs = json.loads((OUT / 'nested-notices.json').read_text())
assert not inputs['unknown_packages'] and not inputs['buildinfo_modules_not_found_in_source_graph']
assert len(inputs['new_notices']) == 28
path = ROOT / prior['notice_asset']['file']
original = path.read_bytes()
assert hashlib.sha256(original).hexdigest() == prior['notice_asset']['sha256']
assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip() == '1032c4801d68b4f67e4a6bc0fdc018f20886d680'
data = bytearray(original)
data.extend(b'\nAdditional selected source-package license and patent notices\n\n'
            b'The following texts are selected from package and embedded-file ancestors\n'
            b'in the Android and Windows source dependency graphs, using recorded Core\n'
            b'build settings. Inclusion does not assert that every optional native\n'
            b'implementation in a package directory was linked. File-header obligations,\n'
            b'other native inputs and corresponding source distribution remain separate.\n')
added = []
for entry in inputs['new_notices']:
    source = Path(entry['path'])
    raw = source.read_bytes()
    raw.decode('utf8')
    assert len(raw) == entry['bytes'] and hashlib.sha256(raw).hexdigest() == entry['sha256']
    if source.is_relative_to(CORE):
        expected = subprocess.check_output(['git', '-C', str(CORE), 'show', prior['source_commit'] + ':' + source.relative_to(CORE).as_posix()])
        assert raw.replace(b'\r\n', b'\n') == expected.replace(b'\r\n', b'\n')
        raw = expected
    data.extend(('\n' + '=' * 78 + '\nSource: ' + entry['source_ref'] + '\n' + '=' * 78 + '\n\n').encode())
    offset = len(data)
    data.extend(raw)
    data.extend(b'\n')
    added.append({'source_ref': entry['source_ref'], 'body_offset': offset, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(), 'observed_workspace_sha256': entry['sha256']})
files = prior['verbatim_files'] + added
assert len(files) == 173 and data[:len(original)] == original
for entry in files:
    assert hashlib.sha256(data[entry['body_offset']:entry['body_offset'] + entry['bytes']]).hexdigest() == entry['sha256']
receipt = {'schema': 'pokrov.native-go-notices/v2', 'client_before': '1032c4801d68b4f67e4a6bc0fdc018f20886d680', 'source_commit': prior['source_commit'], 'go_toolchain': prior['go_toolchain'], 'previous_notice': prior['notice_asset'], 'notice_asset': {'file': prior['notice_asset']['file'], 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}, 'artifact_binding': prior['artifact_binding'], 'verbatim_files': files, 'added_notice_count': len(added), 'module_entries': 128, 'missing_root_license': prior['missing_root_license'], 'complete_license_clearance': False}
(OUT / 'previous-native-go-NOTICES.txt').write_bytes(original)
path.write_bytes(data)
manifest_path = ROOT / 'config/runtime-artifacts.seed.json'
manifest = json.loads(manifest_path.read_text())
manifest['core']['native_go_notices']['sha256'] = receipt['notice_asset']['sha256']
manifest['core']['native_go_notices']['scope'] = 'Verbatim root and selected source-package license/patent notices for recorded Android/Windows Go inputs; other native, file-header and corresponding-source clearance remains separate'
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
(OUT / 'assembly.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'asset': receipt['notice_asset'], 'verbatim_files': len(files), 'added': len(added)}))
