from pathlib import Path
import hashlib, json, re, zipfile

root = Path(__file__).parent
client = Path('E:/r12client')
platform = Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start')
package = platform / 'docs/developer/work-orders/2026-09-05--consolidated-release-and-post12'
family = client / 'docs/operations/evidence/2026-09-12-r12-c05-offline-build'
platform_family = package / 'evidence/c05-offline-build-20260912'
assert not family.exists() and not platform_family.exists()
family.mkdir()
platform_family.mkdir()
files = {p.relative_to(root).as_posix(): p for p in (root / 'native-evidence').rglob('*') if p.is_file()}
files.update({n: root / n for n in ['collection.json', 'workspace.json', 'collect-offline.py', 'retain.py']})
records = []
for name, source in files.items():
    raw = source.read_bytes()
    assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', raw)
    target = family / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(raw)
    records.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
receipt = {'status': 'PASS_BOUNDED_OFFLINE_CORE_BUILD', 'core_source': '2662f76a3303a0518bb07fbbdc449c066de2f95b', 'captures': records, 'supplement': json.loads((root / 'collection.json').read_text())['supplement'], 'boundary': 'Core and gomobile/gobind rebuilt without network; external prebuilt compilers/SDKs and libcronet reused. Not full corresponding-source or release acceptance.'}
(family / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
readme = '''# Core2662 offline build — 2026-09-12

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_OFFLINE_CORE_BUILD**.

From the retained Core2662 source archive, gomobile/gobind and Windows/Android
libraries rebuilt in isolated network namespaces as uid 65534. The compiled
Go cache was initially empty. Five output hashes match the current libraries:
DLL, header, AAR, source JAR, and supplied libcronet. All 3172 Core source
files remain unchanged. [Native receipt](native-evidence/resume-progress.json)
records exact commands, tool hashes, limits and output hashes; [capture index](receipt.json)
binds the retained logs and drivers.

The first tool build failed because version-qualified go install attempted a
module lookup with GOPROXY off. Its [failure receipt](native-evidence/build-progress.json)
and log remain. The successful retry compiled the pinned tool source directory.

Reproduction inputs: existing source archive
`E:/r12-2662-source-20260911/pokrov-core-2662f76-source-review.zip`
(SHA-256 `988573fde7433cc20c40f40a4696d0fa5b54aea1c936feec39cc7dab3715b25d`), plus
`C:/r12-c05-offline-source-20260912/gomobile-source-input-supplement.zip`
(SHA-256 `f04d3870a3db5ec6255a1477d861461528e738b2790df63a558af68bc0b58abd`).
The supplement contains 36 authenticated cache files for nine pinned tool modules
and their manifest. Overlay its go-module-cache directory onto the source packet;
verify each size/hash before use. Build gomobile/gobind from the extracted
v0.1.11 source with GOTOOLCHAIN=local and GOPROXY=off, then use the Core build
scripts and exact prerequisite versions recorded in the native receipt. The
retained drivers contain this run's concrete paths and need those paths adapted
for another machine; they are execution records, not a portable installer.

Go, PowerShell, MinGW, JDK, Android SDK/NDK and Windows libcronet were supplied
prebuilt. This does not establish compiler/Cronet/PGO reconstruction, complete
license compatibility, corresponding-source completeness or public delivery.
No app package, installation, release or production deploy was performed by
this build. Subsequent Wintun source corrections require separate artifacts.
'''
(family / 'README.md').write_text(readme)
with zipfile.ZipFile(platform_family / 'evidence.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for p in sorted(family.rglob('*')):
        if p.is_file():
            z.write(p, p.relative_to(family).as_posix())
for name in ['receipt.json']:
    (platform_family / name).write_bytes((family / name).read_bytes())
for repo, relative in [(client, family.relative_to(client).as_posix()), (platform, platform_family.relative_to(platform).as_posix())]:
    p = repo / '.gitattributes'
    with p.open('a', encoding='utf-8', newline='\n') as stream:
        stream.write(relative + '/** -text whitespace=-blank-at-eol,-blank-at-eof,cr-at-eol\n')
for name in ['windows-release-readiness.md', 'android-release-audit.md']:
    p = client / 'docs/operations' / name
    with p.open('a', encoding='utf-8', newline='\n') as stream:
        stream.write('\n## 2026-09-12 Core2662 offline library build\n\nThe [offline build evidence](evidence/2026-09-12-r12-c05-offline-build/README.md)\nreproduces the exact current Core2662 libraries and rebuilds pinned gomobile/gobind\nwithout network access. Five outputs match; 3172 source files are unchanged.\nPrebuilt toolchains, SDKs and libcronet remain external inputs. Full licensing,\ncorresponding-source delivery and release acceptance remain open. This proof\npredates the separate Windows adapter-cleanup source fix.\n')
print(json.dumps({'status': 'RETAINED', 'captures': len(records), 'platform_zip_bytes': (platform_family / 'evidence.zip').stat().st_size}))
