from pathlib import Path
import hashlib, json, shutil, subprocess

out = Path(__file__).parent
client = Path('E:/r12client')
core = Path('C:/r12corec02')
old = '6b271decead88b708e2fc03984b703b0a4e63ebd'
new = '0138d04e5601a3ab1089cbbe5a73fe8e0aee4126'
family = '2026-09-13-r12-probe-stage-binding'
evidence = client / 'docs/operations/evidence' / family
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
write = lambda p, s: p.write_text(s, encoding='utf8')
assert not evidence.exists()
assert subprocess.check_output(['git', '-C', str(core), 'rev-parse', 'HEAD'], text=True).strip() == new
assert subprocess.check_output(['git', '-C', str(core), 'status', '--porcelain']) == b''
download = read(out / 'download.json')
assert download['status'] == 'PASS_EXACT_DOWNLOADED_LIBRARIES' and download['source_commit'] == new
progress = read(out / 'final-native/progress.json')
assert progress['status'] == 'PASS_TWO_BUILDS_PER_PLATFORM'
assert any(r['stage'] == 'required_core_gate' and r['exit_code'] == 0 for r in progress['commands'])
composition = read(out / 'final-native/audit/artifact-composition.json')
assert composition['status'] == 'PASS_EXACT_ARTIFACT_COMPOSITION'
assert all(r['same_dependency_versions_and_replacements'] for r in composition['binaries'])
assert read(out / 'windows-abi-proxy.json')['status'] == 'PASS_CURRENT_WINDOWS_ABI_AND_100_PROXY_CYCLES'
assert read(out / 'scan-collection.json')['status'].startswith('PASS')
assert subprocess.check_output(['git', '-C', str(core), 'diff', old, new, '--', 'go.mod', 'go.sum', 'engine/sing-box/go.mod', 'engine/sing-box/go.sum']) == b''

manifest = client / 'config/runtime-artifacts.seed.json'
previous = manifest.read_bytes()
data = json.loads(previous)
runtime = data['core']
assert runtime['source_commit'] == old
notice = client / runtime['native_go_notices']['file']
assert sha(notice) == runtime['native_go_notices']['sha256']
body = notice.read_bytes().replace(old.encode(), new.encode())
assert body != notice.read_bytes()
prepared = read(Path('C:/r12-c05-setup-privacy-20260912/notices-preparation.json'))
for row in prepared['verbatim_files']:
    assert hashlib.sha256(body[row['body_offset']:row['body_offset'] + row['bytes']]).hexdigest() == row['sha256']
prepared.update(previous_source=old, source_commit=new, previous_notice_sha256=sha(notice), prepared_notice=dict(file=runtime['native_go_notices']['file'], bytes=len(body), sha256=hashlib.sha256(body).hexdigest()))

replace = {old: new}
provenance = runtime['artifact_provenance']
receipts = {lane: read(out / 'final-native' / (lane + '-evidence-corrected.json')) for lane in ['android', 'windows']}
for lane, receipt in receipts.items():
    assert receipt['source'] == dict(commit=new, clean=True)
    assert receipt['reproducibility']['result'] == 'PASS_BYTE_IDENTICAL_TWO_BUILDS'
    for row in receipt['reproducibility']['files']:
        p = core / 'dist' / lane / row['path']
        assert p.stat().st_size == row['size'] and sha(p) == row['sha256']
    asset = runtime['assets'][lane]
    assert sha(client / asset['sync_destination'] / asset['entry']) == asset['sha256']
    artifact = core / 'dist' / lane / asset['entry']
    digest, size = sha(artifact), artifact.stat().st_size
    replace[asset['sha256']] = digest
    if asset['size'] != size:
        replace[str(asset['size'])] = str(size)
    asset.update(source_commit=new, size=size, sha256=digest)
    provenance['reproducible_build'][lane].update(source_commit=new, size=size, sha256=digest)
    meta = provenance['artifact_evidence'][lane]
    replace[meta['tree_sha256']] = receipt['reproducibility']['tree_sha256']
    receipt_sha = sha(out / 'final-native' / (lane + '-evidence-corrected.json'))
    replace[meta['evidence_sha256']] = receipt_sha
    meta.update(source_commit=new, tree_sha256=receipt['reproducibility']['tree_sha256'], evidence_sha256=receipt_sha)
for row in provenance['artifact_evidence']['sbom']:
    digest = sha(out / 'final-native/sbom/corrected' / row['name'])
    assert all(any(x['name'] == row['name'] and x['sha256'] == digest for x in receipt['sbom']) for receipt in receipts.values())
    replace[row['sha256']] = digest
    row['sha256'] = digest
validator = client / 'scripts/validate-seed.ps1'
validation = validator.read_text(encoding='utf8')
for a, b in replace.items():
    assert a in validation, a
    validation = validation.replace(a, b)
assert shutil.disk_usage('C:/').free > 40 * 2**30 + 256 * 2**20
assert shutil.disk_usage('E:/').free > 40 * 2**30 + 256 * 2**20

evidence.mkdir()
(evidence / 'previous-runtime-binding.json').write_bytes(previous)
for source, target in [('final-native', 'native'), ('binary-scans', 'binary-scans')]:
    shutil.copytree(out / source, evidence / target)
for name in ['final-source.json', 'windows-abi-proxy.json', 'proxy-100-cycles.log', 'download.json', 'scan-collection.json', 'core-regression-before.log', 'core-regression-after.log', 'native-final-build.py', 'native-audit.py', 'correct-local-sbom.py', 'bind-client.py']:
    shutil.copyfile(out / name, evidence / name)
(evidence / 'source-delta.patch').write_bytes(subprocess.check_output(['git', '-C', str(core), 'diff', old, new]))
write(evidence / 'notices-preparation.json', json.dumps(prepared, indent=2) + '\n')
write(evidence / 'binding.json', json.dumps(dict(status='PASS_EXACT_CORE_PROBE_STAGE_BINDING', previous_source=old, source=new, source_tree=progress['source_tree'], regression='Endpoint TLS deadline regression failed before fix; affected urltest/daemon packages pass after fix; required native Core gate PASS.', native_abis=4, windows_exports=15, desktop_abi=2, event_abi=1, notice_bodies_unchanged=len(prepared['verbatim_files']), dependencies_and_build_settings_unchanged=True, consumer_checks='PENDING', installed_proof='PENDING', previous_evidence='Prior unrelated Core6b privacy/lifecycle/source receipts retain their original binary identities; no new corresponding-source or licensing clearance inferred.', rollback=download['rollback_root']), indent=2) + '\n')
attributes = client / '.gitattributes'
write(attributes, attributes.read_text(encoding='utf8') + '\ndocs/operations/evidence/' + family + '/** -text\ndocs/operations/evidence/' + family + '/**/*.log -whitespace\n')
runtime['source_commit'] = new
runtime['native_go_notices'].update(source_commit=new, sha256=hashlib.sha256(body).hexdigest())
notice.write_bytes(body)
write(manifest, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
write(validator, validation)
for relative in ['test/fixtures/release-handoff-v2/synthetic-candidate-input.json', 'docs/architecture/bootstrap-workflow.md']:
    p = client / relative
    content = p.read_text(encoding='utf8')
    assert old in content
    write(p, content.replace(old, new))
owner = client / 'docs/decisions/2026-08-23-pokrov-core-1.1.0-pre-candidate-binding.md'
content = owner.read_text(encoding='utf8').replace('## Current setup privacy binding', '## Previous setup privacy binding', 1)
heading, rest = content.split('\n', 1)
entry = '''## Current probe-stage binding — 2026-09-13

Core `0138d04e5601a3ab1089cbbe5a73fe8e0aee4126` preserves the observed TLS or
response stage when a URL probe expires. The timeout boundary now lives beside
the stage observation; endpoint/background callers consume that bounded result.
The installed Core6b regression lost this stage, producing a generic deadline.

[Binding evidence](../operations/evidence/2026-09-13-r12-probe-stage-binding/README.md)
retains the failing regression, affected package checks, required native Core
gate and two byte-identical builds per platform. Four Android ABIs, Java wrappers,
desktop ABI2/event ABI1, 15 exports, dependencies and 191 license bodies remain
unchanged. Existing Android diagnostic codes accept the more precise outcome.
Current package/install confirmation is pending; no release or licensing claim.

'''
write(owner, heading + '\n\n' + entry + rest.lstrip('\n'))
write(evidence / 'README.md', '''# URL probe deadline stage — 2026-09-13

Core0138 moves the existing bounded deadline into URLTest so its atomic observed
TLS/response stage survives timeout. The installed Core6b failure and source
regression justify this change; no protocol or UI feature is added.

`binding.json`, `native/`, the red/green logs, binary scans and unchanged notice
bodies bind the exact source and native bytes. Existing unrelated privacy,
lifecycle and source-delivery records retain their original candidate identities.
Consumer/install confirmation is pending. Complete license/source obligations,
physical-device and public release gates remain separate.
''')
print('PASS exact native binding prepared; synchronization and consumer validation pending')
