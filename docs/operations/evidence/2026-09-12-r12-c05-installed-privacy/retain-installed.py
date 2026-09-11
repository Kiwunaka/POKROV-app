from pathlib import Path
import datetime, hashlib, json, re

client = Path('E:/r12client')
win = Path(__file__).parent
phone = Path('C:/r12-c05-android-installed-20260912')
emu = Path('C:/r12-c05-ldplayer-20260912')
family = client / 'docs/operations/evidence/2026-09-12-r12-c05-installed-privacy'
assert not family.exists()
read = lambda p: json.loads(p.read_bytes())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
before = read(win / 'baseline.json')
installed = read(win / 'installed-after-launch.json')
assert installed['matched_files'] == 304 and installed['ui_count'] == 1
assert installed['service_state'] == 'Running' and installed['service_account'] == 'LocalSystem'
assert all(before[x] == installed[x] for x in ('state_sha256', 'secure_store_sha256', 'outbox_count'))
assert read(win / 'installed-vm-restoration.json')['power_state'] == 'poweroff'
assert read(win / 'snapshot-lineage.json')['status'] == 'PASS'
assert read(phone / 'installed.json')['installed_apk_sha256'] == '45a943dca23587e7b710b33e29ac39b90bf0aaa614566c374f651bb4ceadc348'
assert read(emu / 'jni-privacy.json')['status'] == 'PASS_BOUNDED_ANDROID_JNI_LOG_PRIVACY'
assert read(emu / 'startup-privacy.json')['status'] == 'PASS_BOUNDED_STARTUP_LOG_SCAN'
assert read(emu / 'restoration.json')['stopped']
assert all(read(emu / 'host-network-after.json')[x] for x in ('routes_match_before', 'dns_match_before'))
family.mkdir()
sources = {}
for label, root, names in (
    ('windows', win, ['installed-before-launch.ps1', 'installed-before-launch.json', 'installed-after-launch.json', 'startup-timeline.json', 'installed-vm-restoration.json', 'snapshot-lineage.json', 'interactive-restart-budget.json', 'finish-ui-budget.json', 'host-network-installed.ps1', 'host-network-installed-after.json']),
    ('android-physical', phone, ['installed.json', 'install.log', 'previous-signature.log', 'current-signature.log']),
    ('android-emulator', emu, ['budget.json', 'baseline.py', 'baseline.json', 'install.log', 'previous-signature.log', 'current-signature.log', 'CorePrivacyProbe.java', 'jni-privacy.py', 'jni-privacy.json', 'startup-privacy.py', 'startup-privacy.json', 'restoration.json', 'host-network-after.json']),
):
    sources.update({label + '/' + name: root / name for name in names})
sources['android-emulator/classes.dex'] = emu / 'dex/classes.dex'
sources['retain-installed.py'] = Path(__file__)
captures = []
for name, path in sources.items():
    raw = path.read_bytes()
    assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', raw), name
    dest = family / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    captures.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
phone_observation = {
    'status': 'PASS_OBSERVED_INSTALLED_STARTUP',
    'device_class': 'Huawei ADA-AL00U API31 physical ARM64',
    'main_screen_visible': True,
    'visible_location_routing_warp_and_entitlement_unchanged': True,
    'method': 'Before/after screenshots inspected during authorized device availability; account-bearing images retained locally only.',
    'before_image_sha256': sha(phone / 'before-ui.png'),
    'after_image_sha256': sha(phone / 'after-ui.png'),
    'tunnel_test': 'NOT_RUN',
    'owner_withdrew_device_until_morning': True,
    'no_device_actions_after_withdrawal': True,
}
(family / 'android-physical/ui-observation.json').write_text(json.dumps(phone_observation, indent=2) + '\n')
ui_path = family / 'android-physical/ui-observation.json'
captures.append({'path': 'android-physical/ui-observation.json', 'bytes': ui_path.stat().st_size, 'sha256': sha(ui_path)})
receipt = {
    'status': 'PASS_BOUNDED_INSTALLED_STARTUP_AND_JNI_LOG_PRIVACY',
    'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'client_source': installed['client_source'],
    'core_source': installed['core_source'],
    'captures': captures,
    'windows_files_matched': 304,
    'windows_state_and_secure_store_preserved': True,
    'physical_android_upgrade': True,
    'android_emulator_api': 34,
    'android_emulator_abi': 'x86_64',
    'jni_error_return_contains_all_synthetic_markers': True,
    'jni_stdout_stderr_logcat_markers_absent': True,
    'host_routes_and_dns_preserved': True,
    'host_hiddify_changed': False,
    'public_release': False,
    'production_deploy': False,
    'full_c05_accepted': False,
    'open': ['Current-package installed tunnel/recovery matrix', 'Physical Android runtime logging and ARM native execution', 'Extended/crash and other logging sinks', 'Complete license/corresponding-source assessment and publication'],
}
(family / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
(family / 'README.md').write_text('''# Core2662 installed startup and JNI log privacy — 2026-09-12

Document class: EXECUTION_EVIDENCE.
**PASS_BOUNDED_INSTALLED_STARTUP_AND_JNI_LOG_PRIVACY**.
Client source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`, Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`, development `1.2.0+4053`.
[Receipt](receipt.json) records exact capture hashes and scope.

## Windows

The owner made the PC available and authorized control of the existing guest.
The ordinary setup wizard updated the existing installation. Before launch
and after the main screen appeared, [all 304 installed files](windows/installed-after-launch.json)
matched the current package; LocalSystem service was running, outbox empty,
and session/secure-storage hashes were unchanged from the
[prior baseline](../2026-09-12-r12-c05-package-ffi/baseline.json).
The [startup journal projection](windows/startup-timeline.json) identifies
client212 and successful initialization/UI readiness. It also retains the
previous-exit detection and failed API/update refreshes with the guest NIC off.

The exact current DLL already passes the separate
[six-marker FFI regression](../2026-09-12-r12-c05-package-ffi/README.md).
This installed slice proves startup and preservation, not a current TUN test.
Changing the disabled NIC attachment while running failed without changing it.
The shutdown wrapper returned exit 1 as the guest stopped; independent
[native readback](windows/installed-vm-restoration.json) proves poweroff/NIC none.
All [13 snapshots](windows/snapshot-lineage.json) and the old rollback-leaf
hash remain intact. Restart growth was 580911104 bytes within 805306368.

## Physical Android

`adb -d install -r` installed the current ARM64 direct APK, SHA-256
`45a943dca23587e7b710b33e29ac39b90bf0aaa614566c374f651bb4ceadc348`.
Both old and current APKs pass apksigner verification with the same certificate.
The previous APK remains in the local rollback directory. No app data was cleared.
[Installed readback](android-physical/installed.json) and
[UI observation](android-physical/ui-observation.json) show successful startup
with the same visible settings. Account-bearing screenshots remain local.
The owner took the phone until morning before tunnel/logging acceptance;
there were no further phone actions. Existing third-party VPN state was untouched.

## Android emulator

Only the existing `pokrov-qa-120` instance was started. SDK ADB and the indexed
LDPlayer console were bound by matching boot identities; physical-looking
LDPlayer properties were not treated as proof of a physical device.
The current x86_64 APK, SHA-256
`9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee`,
was installed with the same signing certificate and no app-data clear.
The main screen and stored location/routing survived. The test entitlement
requires renewal; no paid action or entitlement bypass was performed.

The [startup log scan](android-emulator/startup-privacy.json) inspected 13433
bytes from the current main process in memory. Six defined secret-pattern
classes returned zero matches; no fatal exception or ANR was observed.
This is a bounded regex scan, not exhaustive confidentiality proof.

[CorePrivacyProbe.java](android-emulator/CorePrivacyProbe.java) was compiled
with JDK17 `javac --release 8`, then SDK36.1 D8 `--min-api 26`.
A separate shell `app_process` loads the exact installed APK through
`PathClassLoader`, calls native `Libbox.setup(debug=false)` with an isolated
temporary directory, then `checkConfig` with six synthetic markers in an
invalid outbound type. No VPN service or live profile is started.
[JNI result](android-emulator/jni-privacy.json): the config was rejected;
stdout, stderr and the child's 5449-byte logcat contain none of the markers.
The JNI exception returned to the caller **does contain all six markers**.
The harness catches it and exports booleans only. This does not claim that
raw JNI errors are safe to display/log, or prove every consumer error path.
The retained [driver](android-emulator/jni-privacy.py) keeps raw streams in memory.

The emulator was shut down; disk growth was 295698432 bytes within 402653184.
[Host route/DNS hashes](android-emulator/host-network-after.json) are unchanged.
Root settings, host Hiddify and other emulator instances were not changed.
LDPlayer was not installed inside Windows VM: available headroom above the
40 GiB disk floor is insufficient for its published 36 GB free-space minimum.

Current installed tunnel/recovery, physical ARM runtime/privacy, extended/crash
sinks, full license/source assessment and source publication remain open.
No new public release, store submission or production deploy occurred.
''', encoding='utf8')
for owner, text in (
    ('windows-release-readiness.md', '''The exact client212/Core2662 package is now installed in the owned Windows11
VM. All 304 files match before/after ordinary UI startup; LocalSystem service,
session/secure-store preservation and empty outbox pass. The
[installed follow-up](evidence/2026-09-12-r12-c05-installed-privacy/README.md)
records the disabled-NIC scope, startup journal, normal guest poweroff,
13 preserved snapshots and unchanged host network. This supersedes the earlier
installation deferral for startup only; current TUN/recovery and full privacy,
license/source and release acceptance remain open.'''),
    ('android-release-audit.md', '''The exact client212/Core2662 ARM64 APK is installed on the owner's Huawei
API31 phone; the x86_64 APK is installed in the existing API34 LDPlayer QA
instance. Same-signer updates and installed SHA-256 readback pass; observed
settings and UI startup are preserved. The phone was withdrawn before runtime
acceptance. The [installed/JNI evidence](evidence/2026-09-12-r12-c05-installed-privacy/README.md)
adds a current-process startup log scan and a separate six-marker native
`Libbox.checkConfig` probe loaded from the exact installed x86_64 APK.
Native stdout/stderr/logcat have no markers; the caught JNI exception does
contain them and is not declared safe for display/logging. No tunnel or
subscription bypass was used. Physical ARM logging, current TUN/recovery,
extended/crash sinks and full C05/source/release gates remain open.'''),
):
    path = client / 'docs/operations' / owner
    content = path.read_text(encoding='utf8')
    heading = '## 2026-09-12 Core2662 installed startup and privacy'
    assert heading not in content
    path.write_text(content.rstrip() + '\n\n' + heading + '\n\n' + text + '\n', encoding='utf8')
path = client / 'docs/operations/evidence/2026-09-11-r12-c05-2662-packages/README.md'
path.write_text(path.read_text(encoding='utf8').rstrip() + '\n\nThe later [installed startup and JNI privacy slice](../2026-09-12-r12-c05-installed-privacy/README.md)\nupdates Windows, physical ARM64 and emulator x86_64 installation evidence.\nIts bounded results and remaining runtime/source gates are recorded separately.\n', encoding='utf8')
path = client / '.gitattributes'
path.write_text(path.read_text(encoding='utf8').rstrip() + '\ndocs/operations/evidence/2026-09-12-r12-c05-installed-privacy/** -text whitespace=cr-at-eol\n', encoding='utf8')
print(json.dumps({'status': receipt['status'], 'captures': len(captures), 'family': str(family)}))
