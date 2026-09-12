from pathlib import Path
import hashlib, json, shutil, subprocess

out = Path(__file__).parent
client = Path('E:/r12client')
core = Path('C:/r12corec02')
old = '880bff65ad665844828fe50fc395e9cfc1cd81b4'
new = '6b271decead88b708e2fc03984b703b0a4e63ebd'
family = '2026-09-12-r12-setup-privacy-binding'
evidence = client / 'docs/operations/evidence' / family
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
write = lambda p, s: p.write_text(s, encoding='utf8')
git = lambda *a: subprocess.check_output(['git', '-C', str(core), *a], text=True).strip()
assert git('rev-parse', 'HEAD') == new and not git('status', '--porcelain')
assert not evidence.exists()
download = read(out / 'download.json')
assert download['status'] == 'PASS_EXACT_DOWNLOADED_LIBRARIES' and download['source_commit'] == new
for name, status in [('native-test-result.json', 'PASS'), ('static-triage-binding.json', 'PASS_BOUNDED_ADVISORY_DELTA_REVIEW'), ('windows-abi-proxy.json', 'PASS_CURRENT_WINDOWS_ABI_AND_100_PROXY_CYCLES')]:
    assert read(out / name)['status'] == status
host = read(out / 'host-network-resumed-after.json')
assert host['routes_match_before'] and host['dns_match_before']
ffi = read(out / 'V01_CANARY_SETUP_PATH/receipt.json')
assert ffi['status'] == 'PASS_BOUNDED_SOURCE_DLL_FFI' and ffi['core_source'] == new
assert read(out / 'V01_CANARY_SETUP_PATH/persisted-sinks.json')['status'] == 'PASS_BOUNDED_PERSISTED_SINKS'
manifest = client / 'config/runtime-artifacts.seed.json'
previous = manifest.read_bytes()
data = json.loads(previous)
runtime = data['core']
assert runtime['source_commit'] == old
notice = client / runtime['native_go_notices']['file']
assert sha(notice) == runtime['native_go_notices']['sha256']
prepared = read(out / 'notices-preparation.json')
body = (out / prepared['prepared_notice']['file']).read_bytes()
assert hashlib.sha256(body).hexdigest() == prepared['prepared_notice']['sha256']
for row in prepared['verbatim_files']:
    assert hashlib.sha256(body[row['body_offset']:row['body_offset'] + row['bytes']]).hexdigest() == row['sha256']
rollback = download['rollback_root'].split(':', 1)[1]
old_rows = {row['path']: row for row in read(Path('C:/r12-c05-wintun-20260912/download.json'))['files']}
remote_check = subprocess.check_output(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'pokrov-de', 'sha256sum ' + ' '.join(rollback + '/' + name for name in sorted(old_rows))], text=True, timeout=60)
assert {line.split()[1].removeprefix(rollback + '/'): line.split()[0] for line in remote_check.splitlines()} == {name: row['sha256'] for name, row in old_rows.items()}
receipts = {lane: read(out / 'final-native' / (lane + '-evidence-corrected.json')) for lane in ['android', 'windows']}
checks = []
replace = {old: new}
provenance = runtime['artifact_provenance']
for lane, receipt in receipts.items():
    assert receipt['source'] == {'commit': new, 'clean': True}
    assert receipt['reproducibility']['result'] == 'PASS_BYTE_IDENTICAL_TWO_BUILDS'
    for row in receipt['reproducibility']['files']:
        p = core / 'dist' / lane / row['path']
        assert p.stat().st_size == row['size'] and sha(p) == row['sha256']
        checks.append({'lane': lane, **row})
    asset = runtime['assets'][lane]
    assert sha(client / asset['sync_destination'] / asset['entry']) == asset['sha256']
    assert old_rows[lane + '-a/' + asset['entry']]['sha256'] == asset['sha256']
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
    for receipt in receipts.values():
        assert any(x['name'] == row['name'] and x['sha256'] == digest for x in receipt['sbom'])
    replace[row['sha256']] = digest
    row['sha256'] = digest
validator = client / 'scripts/validate-seed.ps1'
validation = validator.read_text(encoding='utf8')
for a, b in replace.items():
    assert a in validation, a
    validation = validation.replace(a, b)
assert shutil.disk_usage('C:/').free > 40 * 2**30 + 180 * 2**20
assert shutil.disk_usage('E:/').free > 40 * 2**30 + 200 * 2**20
runtime['source_commit'] = new
runtime['native_go_notices'].update(source_commit=new, sha256=prepared['prepared_notice']['sha256'])
evidence.mkdir()
(evidence / 'previous-runtime-binding.json').write_bytes(previous)
for source, target in [('final-native', 'native'), ('binary-scans', 'binary-scans'), ('source-packet-evidence', 'source-packet')]:
    shutil.copytree(out / source, evidence / target)
names = ['native-test-result.json', 'final-source.json', 'overlay.json', 'notices-preparation.json', 'windows-abi-proxy.json', 'check-windows-descriptor.py', 'proxy-100-cycles.log', 'host-network-resumed-before.json', 'host-network-resumed-after.json', 'download.json', 'scan-collection.json', 'static-triage-binding.json', 'setup-source-delta.patch', 'native-test.py', 'native-final-build.py', 'native-audit.py', 'correct-local-sbom.py', 'prepare-binding-inputs.py', 'native-source-packet.py', 'prior-installer-retention.json', 'bind-client.py']
for name in names:
    shutil.copyfile(out / name, evidence / name)
ffi_dir = evidence / 'source-dll-privacy'
ffi_dir.mkdir()
for name in ['receipt.json', 'persisted-sinks.json', 'host-network-ffi-before.json', 'host-network-ffi-after.json', 'run.ps1', 'child.ps1', 'network.ps1', 'check-persisted-sinks.py']:
    shutil.copyfile(out / 'V01_CANARY_SETUP_PATH' / name, ffi_dir / name)
attributes = client / '.gitattributes'
write(attributes, attributes.read_text(encoding='utf8') + '\ndocs/operations/evidence/' + family + '/** -text\ndocs/operations/evidence/' + family + '/**/*.log -whitespace\n')
notice.write_bytes(body)
write(manifest, json.dumps(data, ensure_ascii=False, indent=2) + '\n')
write(validator, validation)
for relative in ['test/fixtures/release-handoff-v2/synthetic-candidate-input.json', 'docs/architecture/bootstrap-workflow.md']:
    p = client / relative
    content = p.read_text(encoding='utf8')
    assert old in content
    write(p, content.replace(old, new))
binding = {'status': 'PASS_LOCAL_REPRODUCIBLE_SETUP_PRIVACY_BINDING', 'previous_source': old, 'source': new, 'source_tree': git('rev-parse', 'HEAD^{tree}'), 'compared_files': checks, 'reproducibility_origin': 'Two native DE builds per platform using warmed caches; hashes verified locally', 'desktop_abi': 2, 'event_abi': 1, 'windows_exports': 15, 'windows_proxy_cycles': 100, 'host_routes_dns_unchanged': True, 'android_native_abis': 4, 'aar_java_manifest_entries_unchanged': True, 'notices_verbatim_blocks': len(prepared['verbatim_files']), 'source_dll_privacy': 'PASS_BOUNDED_SOURCE_DLL_FFI and PASS_BOUNDED_PERSISTED_SINKS', 'consumer_checks': 'PENDING', 'installed_tun_acceptance': 'PENDING for current bytes', 'license_compatibility_and_corresponding_source': 'UNRESOLVED_OWNER_DECISION', 'promotion': 'NOT_PERFORMED', 'rollback': download['rollback_root']}
write(evidence / 'binding.json', json.dumps(binding, indent=2) + '\n')
owner = client / 'docs/decisions/2026-08-23-pokrov-core-1.1.0-pre-candidate-binding.md'
content = owner.read_text(encoding='utf8').replace('## Current Windows adapter cleanup binding', '## Previous Windows adapter cleanup binding', 1)
heading, rest = content.split('\n', 1)
entry = '''## Current setup privacy binding — 2026-09-12

The development client binds Core `6b271decead88b708e2fc03984b703b0a4e63ebd`.
Setup writes fixed status messages and the selected mode; caller directories
and listen addresses are excluded from stderr and the legacy log observer.
The new regression test fails on Core880 and passes with this fix. The full
native Core test script passes. Dependencies, native ABI and Wintun are unchanged.

[Current binding evidence](../operations/evidence/2026-09-12-r12-setup-privacy-binding/README.md)
retains two byte-identical native DE builds per platform, five current binary
scans, corrected source SBOMs and 191 unchanged verbatim license blocks.
The exact source DLL passes 100 Dart proxy cycles and an isolated invalid-config
privacy check across FFI, stdout, stderr and five generated files, including
a canary in the setup directory. Host routes and DNS remain unchanged.
This is bounded source-DLL evidence; current consumer/package checks, installed
TUN acceptance and complete licensing/source obligations remain separate gates.

'''
write(owner, heading + '\n\n' + entry + rest.lstrip('\n'))
write(evidence / 'README.md', '''# Setup privacy binding — 2026-09-12

`binding.json` binds Core 6b271decead88b708e2fc03984b703b0a4e63ebd to the
development Android/Windows consumer. Earlier packages retain their own identities.

- `native/`: two byte-identical native DE builds per platform using warmed caches,
  original/corrected SBOMs, exact library receipts and binary composition.
- `native-test-result.json` and `setup-source-delta.patch`: the setup-path regression
  fails on the old source; both focused privacy tests and the full Core script pass.
  Full raw test output was not retained; the receipt records hashes and safe summaries.
- `source-dll-privacy/`: exact new DLL, six synthetic marker categories, debug disabled,
  invalid config before service startup, no live profile/TUN. FFI/stdout/stderr and
  five generated files contain no markers. Raw streams were hashed, not retained.
  The prior failure is retained in [Core880 follow-up](../2026-09-12-r12-wintun-followup/README.md).
- `windows-abi-proxy.json`: ABI2/event ABI1, 15 exports and 100 Dart proxy cycles.
- `binary-scans/` and `static-triage-binding.json`: five scans retain nine advisory
  IDs and their bounded prior dispositions; zero extracted symbols is not clearance.
- `source-packet/`: metadata for a private DE 3902-entry archive, all inputs hashed,
  and five offline module graphs. Prebuilt SDK/toolchain reconstruction and full
  corresponding-source/legal clearance are not established.
- `notices-preparation.json`: 191 verbatim license bodies unchanged; old inventory
  source_ref labels identify inputs, while the shipped notice names the current commit.

Consumer checks, source promotion and installed acceptance are pending at binding.
No public release or complete C05/V01 acceptance is established by this directory.
''')
print('PASS local source/artifact/SBOM/notice binding written; runtime sync and consumer checks pending')
