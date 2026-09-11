from pathlib import Path
import hashlib, json, datetime

root = Path('E:/r12client')
out = Path(__file__).parent
family = root / 'docs/operations/evidence/2026-09-12-r12-c05-package-ffi'
assert not family.exists()
family.mkdir()
proof = json.loads((out / 'packaged-ffi.json').read_bytes())
restored = json.loads((out / 'vm-restoration.json').read_bytes())
assert proof['status'] == 'PASS_BOUNDED_PACKAGE_FFI'
assert restored['status'] == 'PASS_VM_RESTORED_OFFLINE'
assert not restored['installed_package_changed']
names = ['packaged-ffi.json', 'ffi-child.ps1', 'ffi-run.ps1', 'baseline.ps1', 'baseline.json', 'baseline-after-ffi.json', 'vm-before.json', 'new-leaf-move.json', 'vm-restoration.json', 'host-network.ps1', 'host-network-resumed-before.json', 'host-network-resumed-after.json', 'retain-ffi.py']
captures = []
for name in names:
    raw = (out / name).read_bytes()
    (family / name).write_bytes(raw)
    captures.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
receipt = {'status': 'PASS_BOUNDED_PACKAGE_FFI', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'client_source': proof['client_source'], 'core_source': proof['core_source'], 'dll_sha256': proof['child']['dll_sha256'], 'captures': captures, 'scope': 'Unprivileged exact packaged DLL in an isolated fixture on the owned Windows VM. Existing installed package was not updated. UI and installed acceptance remain deferred.', 'host_network_preserved': True, 'vm_powered_off': True, 'snapshots_retained': 13}
(family / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
(family / 'README.md').write_text('''# Core2662 package FFI privacy — 2026-09-12

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_PACKAGE_FFI**.
Client build source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`, Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`, exact packaged DLL
SHA-256 `e77cc0ab979becc635ec578b8b44248b1146dd96ba34cd4de72e62130089ce2c`.
[Receipt and capture hashes](receipt.json), [FFI result](packaged-ffi.json).

The DLL was copied from the versioned development release bundle into an
isolated user fixture on the existing Windows 11 VM. The 45-second bounded
PowerShell/C# child calls the actual exported setup/start/freeString functions
with debug disabled and a deliberately invalid synthetic configuration.
It returns `CORE-005`; credential, config, URL, IP, path and PII markers are
absent from the FFI return, stdout and stderr. Stdout is empty; stderr contains
398 bytes. Raw streams were scanned in memory and were not exported.

This checks the previous direct-FFI leak regression for the exact new package.
It does not cover every runtime logging path or installed service/TUN behavior.
The current guest API token is not elevated. Installation and ordinary UI
acceptance were deferred while the owner was occupied; no elevation was attempted.
All 304 files of the existing client7ed/Core904 installation still match before
and after the fixture. Session and secure-storage hashes, empty outbox and
idle UI are unchanged. No live profile was used by the FFI subprocess.

The guest was shut down normally. [Restoration](vm-restoration.json) proves
poweroff, NIC none, all 13 retained snapshots, unchanged old rollback-leaf hash,
and 3,355,443,200 bytes growth within the 4 GiB budget. Host route/DNS digests
match their baseline. A window capture returned the occluding game instead of
the VM; direct VirtualBox capture returned E_FAIL. No host input or focus change
was sent, and no VM screenshot is claimed.

Commands: the retained `baseline.ps1`, `ffi-run.ps1`/`ffi-child.ps1` and final
baseline projection ran through the existing bounded guest-control wrapper.
`shutdown.exe /s /t 0 /d p:0:0` shut down the guest; native VBox readback and
SHA-256 checks produced the restoration receipt. The first DLL copy used the
wrong unversioned host directory and stopped before copying it; the corrected
versioned bundle path supplied the verified bytes. Public release, production
deploy and installed-candidate acceptance were not performed.
''', encoding='utf8')
owner = root / 'docs/operations/windows-release-readiness.md'
text = owner.read_text(encoding='utf8')
heading = '## 2026-09-12 Core2662 package FFI privacy'
assert heading not in text
owner.write_text(text.rstrip() + '\n\n' + heading + '''

The current client212/Core2662 DLL from the exact development package passes
the previous direct-FFI privacy regression in an isolated user fixture on the
owned Windows 11 VM: all six synthetic markers are absent from FFI return,
stdout and stderr, with `CORE-005` preserved and debug disabled. The
[bounded receipt](evidence/2026-09-12-r12-c05-package-ffi/README.md) records the
exact DLL hash, unchanged existing installation/session storage, normal VM
shutdown, 13 retained snapshots and unchanged host network digests.
Installation and ordinary UI acceptance remain deferred by the owner; this
fixture does not establish current installed service, TUN or full runtime-log
coverage. Source publication, complete licensing and public release remain open.
''', encoding='utf8')
previous = root / 'docs/operations/evidence/2026-09-11-r12-c05-2662-packages/README.md'
text = previous.read_text(encoding='utf8')
previous.write_text(text.rstrip() + '\n\nThe subsequent [package FFI check](../2026-09-12-r12-c05-package-ffi/README.md)\npasses the six-marker direct-FFI regression for this exact DLL in an isolated\nWindows VM fixture. It does not change the uninstalled scope above.\n', encoding='utf8')
attributes = root / '.gitattributes'
text = attributes.read_text(encoding='utf8')
line = 'docs/operations/evidence/2026-09-12-r12-c05-package-ffi/** -text whitespace=cr-at-eol'
assert line not in text
attributes.write_text(text.rstrip() + '\n' + line + '\n', encoding='utf8')
print(json.dumps({'status': receipt['status'], 'captures': len(captures)}))
