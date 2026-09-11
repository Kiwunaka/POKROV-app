from pathlib import Path
import hashlib, json, subprocess, zipfile

out = Path(__file__).parent
root = Path('E:/r12client')
sha = lambda b: hashlib.sha256(b).hexdigest()
binding = json.loads((out / 'source-license-binding.json').read_bytes())
assert subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip() == 'e97ecb10c6db52908a0404831c191a1dc90fa632'
path = root / 'packages/app_shell/assets/licenses/native-go-NOTICES.txt'
original = path.read_bytes()
assert sha(original) == binding['current_asset_sha256']
header = (out / 'u_prng-header.txt').read_bytes()
license_body = (out / 'upstream-LICENSE.txt').read_bytes()
assert header not in original and license_body in original
data = original + b'\n\n' + b'=' * 78 + b'\nPsiphon uTLS file copyright and explicit license reference\n' + b'=' * 78 + b'\n\n'
data += b'Source: github.com/Psiphon-Labs/utls@v0.0.0-20260129182755-24497d415a8d/u_prng.go\n'
data += b'The following original file header refers explicitly to the uTLS license.\n'
data += b'That license text is reproduced above in the section\n'
data += b'github.com/refraction-networking/utls@v1.8.2/LICENSE.\n'
data += b'This file attribution does not replace the missing root license of the\n'
data += b'recorded Psiphon fork or establish complete licensing clearance.\n\n'
offset = len(data)
data += header + b'\n'
assert data[:len(original)] == original and data[offset:offset + len(header)] == header
prior = json.loads((root / 'docs/operations/evidence/2026-09-06-r12-c05-file-headers/assembly.json').read_bytes())
for item in prior['verbatim_files']:
    assert sha(data[item['body_offset']:item['body_offset'] + item['bytes']]) == item['sha256'], item['source_ref']
manifest_path = root / 'config/runtime-artifacts.seed.json'
manifest = json.loads(manifest_path.read_bytes())
assert manifest['core']['native_go_notices']['sha256'] == sha(original)
assert manifest['core']['source_commit'] == binding['core_revision']
manifest['core']['native_go_notices']['sha256'] = sha(data)
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
path.write_bytes(data)
(out / 'previous-native-go-NOTICES.txt').write_bytes(original)
assembly = {'status': 'PASS_NOTICE_ATTRIBUTION_ADDED', 'asset': path.relative_to(root).as_posix(), 'core_revision': binding['core_revision'], 'old_bytes': len(original), 'old_sha256': sha(original), 'bytes': len(data), 'sha256': sha(data), 'previous_asset_prefix_unchanged': True, 'previous_verbatim_blocks_verified': len(prior['verbatim_files']), 'added_file_header': {'source': 'github.com/Psiphon-Labs/utls@24497d415a8de0d11c20c3a47724fb88897ed725/u_prng.go', 'body_offset': offset, 'bytes': len(header), 'sha256': sha(header)}, 'license_body_already_present_sha256': sha(license_body), 'root_license_gap': 'OPEN_PINNED_FORK', 'complete_license_clearance': False}
(out / 'assembly.json').write_text(json.dumps(assembly, indent=2) + '\n', encoding='utf8')
evidence = root / 'docs/operations/evidence/2026-09-11-r12-utls-file-attribution'
evidence.mkdir(exist_ok=False)
for name in ('source-license-binding.json', 'assembly.json', 'u_prng-header.txt', 'upstream-LICENSE.txt'):
    (evidence / name).write_bytes((out / name).read_bytes())
projection = {k: binding[k] for k in ('module_revision', 'official_licensed_branch_revision', 'license_first_commit', 'branches_are_diverged')}
projection['tree_responses'] = [{'file': name, 'sha256': sha((out / name).read_bytes())} for name in ('pinned-tree.json', 'licensed-tree.json')]
projection['comparison_response_sha256'] = sha((out / 'branch-comparison.json').read_bytes())
projection['scope'] = 'Authentic reference license retained; not a grant inferred for every file in the divergent pinned fork.'
(evidence / 'upstream-projection.json').write_text(json.dumps(projection, indent=2) + '\n', encoding='utf8')
(evidence / 'README.md').write_text(f'''# Psiphon uTLS file attribution

Status: source notice correction; exact package checks pending.
Core `{binding['core_revision']}` retains the same five library outputs.

The 77 selected Psiphon uTLS Go files match the exact upstream Git blobs in
all five fresh Core 904 dependency graphs. `u_prng.go` is selected on every
platform and its original header explicitly releases the file under the
[uTLS license](https://github.com/refraction-networking/utls/blob/37f7eb6d8aac00e15d4e4235189a9c5c26616dfb/LICENSE).
The common notice asset contained that exact BSD body already, but omitted
the Psiphon copyright/header. The original header is now appended verbatim,
with a reference to the existing license section. All prior asset bytes and
185 recorded license bodies are unchanged.

The [pinned fork](https://github.com/Psiphon-Labs/utls/tree/24497d415a8de0d11c20c3a47724fb88897ed725)
still lacks a root LICENSE. The official release-branch.go1.26 snapshot
`7a1fc711853d6dd31c10eca10bbd53bf3b082aac` has the authentic root BSD text,
but its history diverges and only 38 of the 77 selected files have identical
Git blobs. This does not establish licensing clearance for the whole older
fork. `missing_root_license_modules` remains unchanged.

[Source binding](source-license-binding.json), [assembly](assembly.json),
[original header](u_prng-header.txt), [reference license](upstream-LICENSE.txt)
and [upstream projection](upstream-projection.json) retain the exact hashes.
Local runners and full public API readbacks: `E:/r12-c05-utls-license-20260911/`.
No dependency, Core bytes, protocol behavior or public release changed.
''', encoding='utf8')
owner = root / 'docs/architecture/bootstrap-workflow.md'
text = owner.read_text(encoding='utf8')
needle = 'This notice binding does not establish complete dependency licensing or\n'
assert text.count(needle) == 1
text = text.replace(needle, 'The asset also preserves the original Psiphon `u_prng.go` copyright and its\nexplicit uTLS license reference, linked to the already included BSD body.\nThe pinned Psiphon fork still lacks a root LICENSE; this file attribution\ndoes not establish clearance for the whole fork.\n' + needle)
owner.write_text(text, encoding='utf8')
for name in ('android-release-audit.md', 'windows-release-readiness.md'):
    p = root / 'docs/operations' / name
    with p.open('a', encoding='utf8') as f:
        f.write('\n## 2026-09-11 Psiphon file attribution\n\nThe shared notice asset appends the original `u_prng.go` Psiphon copyright\nand explicit uTLS license reference. All previous bytes and 185 recorded\nbodies are retained. [Source evidence](evidence/2026-09-11-r12-utls-file-attribution/README.md)\nbinds the 77 selected files to Core 904. The root license gap of the pinned\nfork and full C05 clearance remain open; exact package checks are pending.\n')
print(json.dumps(assembly))
