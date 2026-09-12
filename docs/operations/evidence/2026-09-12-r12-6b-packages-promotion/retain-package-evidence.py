from pathlib import Path
import datetime,hashlib,json,re,subprocess,zipfile
out=Path(__file__).parent;client=Path('E:/r12client')
source='2aa57015783ceb3415e3be62bbf0a698729011c4';core='6b271decead88b708e2fc03984b703b0a4e63ebd'
sha=lambda b:hashlib.sha256(b).hexdigest()
assert subprocess.check_output(['git','-C',str(client),'rev-parse','HEAD'],text=True).strip()==source
a=json.loads((out/'android-package-audit.json').read_bytes());w=json.loads((out/'windows-package-audit.json').read_bytes())
assert json.loads((out/'android-build-progress-store-only.json').read_bytes())['status']=='PASS'
assert json.loads((out/'comparison.json').read_bytes())['status']=='PASS_EXACT_PAYLOAD'
assert '100% tests passed, 0 tests failed out of 9' in (out/'windows-native-tests.log').read_text()
artifacts=[x['artifact'] for x in a['artifacts']]+[w['installer']]
for r in artifacts:
    p=Path(r['path']);assert p.stat().st_size==r['size'] and sha(p.read_bytes())==r['sha256']
scans={p.stem.removesuffix('.scan'):json.loads(p.read_bytes()) for p in (out/'binary-scans').glob('*.scan.json')}
bindings=[]
for r in a['artifacts']:
    for lib in r['libraries']:
        if lib['entry'].endswith('/libpokrov-core.so'):
            name='libpokrov-core-'+lib['entry'].split('/')[-2];assert scans[name]['binary']['sha256']==lib['sha256']
            bindings.append({'package':Path(r['artifact']['path']).name,'entry':lib['entry'],'sha256':lib['sha256'],'scan':name+'.scan.json','scan_sha256':sha((out/'binary-scans'/(name+'.scan.json')).read_bytes())})
native=next(x for x in w['bundle_inventory'] if x['relative_path']=='pokrov-core.dll')
assert scans['pokrov-core']['binary']['sha256']==native['sha256']
assert source.encode() in Path(next(x for x in w['bundle_inventory'] if x['relative_path']=='data/app.so')['path']).read_bytes()
bindings.append({'package':Path(w['installer']['path']).name,'entry':'pokrov-core.dll','sha256':native['sha256'],'scan':'pokrov-core.scan.json','scan_sha256':sha((out/'binary-scans/pokrov-core.scan.json').read_bytes())})
(out/'package-native-scan-binding.json').write_text(json.dumps({'status':'PASS_EXACT_PACKAGED_BYTES_MATCH_CURRENT_SCANS','core':core,'bindings':bindings,'advisories':scans['pokrov-core']['advisories'],'limit':'Module-level findings in stripped binaries do not prove function reachability; dispositions remain bounded in source binding family'},indent=2)+'\n')
family=client/'docs/operations/evidence/2026-09-12-r12-6b-packages-promotion';assert not family.exists();family.mkdir()
names='audit-android.py audit-windows.py prepare-android-audit.py android-package-audit.json windows-package-audit.json package-native-scan-binding.json verify-direct-apks.py direct-apks-verified.json direct-apk-duplicate-retention.json android-dex-current-binding.json build-windows.ps1 watch-windows-build.py windows-build-progress.json windows-build.log windows-driver.log windows-cache-retention.json native-tests.ps1 windows-native-tests.log build-android-resumed.ps1 watch-android-build-resumed.py android-build-progress-resumed.json android-build-resumed.log android-driver-resumed.log build-android-retained-cache-retry.ps1 watch-android-build-retained-cache.py android-build-progress-retained-cache-retry.json android-build-retained-cache-retry.log android-driver-retained-cache-retry.log android-detached-daemon-stop.json prepare-store-resume.py build-android-store-only.ps1 build-android-store-only-wrapper.ps1 watch-android-store-only.py store-only-resume.patch store-only-resume-preparation.json android-build-progress-store-only.json android-build-store-only.log android-driver-store-only.log start-extractor.ps1 extract-installer.py guest-extract.py compare-payload.py comparison.json extraction.json extract.log payload-inventory.json extractor-guest-before.json extractor-dispatch.json extractor-unit.log extractor-vm-budget.json extractor-vm-start.log extractor-vm-restoration.json prior-installer-retention.json android-storage-inventory.py android-storage-inventory.json android-storage-after-bundle-stop.py android-storage-after-bundle-stop.json core-cache-inventory.py core-cache-inventory.json compress-retired-core-cache.ps1 core-cache-compression.json compress-prior-artifacts.ps1 prior-artifact-compression-plan.json prior-artifact-compression.json compress-prior-failed-build.ps1 failed-build-compression-plan.json failed-build-compression.json retain-old-aar-cache.py verify-old-aar-cache.py relocate-old-aar-cache.ps1 retain-old-native-core-cache.py relocate-old-native-core-cache.ps1'.split()
names += [p.name for p in out.glob('old-*.json')]
names += [p.name for p in out.glob('compact-*.log')]
names += ['promotion/'+p.name for p in (out/'promotion').iterdir() if p.suffix in ['.json','.py','.md','.log'] and 'request' not in p.name]
names += ['packaged-ffi/V01_CANARY_SETUP_PATH/'+p.name for p in (out/'packaged-ffi/V01_CANARY_SETUP_PATH').iterdir() if p.is_file()]
captures=[]
def capture(name,raw):
    assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',raw),name
    p=family/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    captures.append({'path':name,'bytes':len(raw),'sha256':sha(raw)})
for name in sorted(set(names)):capture(name,(out/name).read_bytes())
for r in a['artifacts']:
    p=Path(r['signing_receipt']['path']);capture(p.name,p.read_bytes())
capture('windows-package.manifest.json',Path(w['manifest']['path']).read_bytes())
prior=Path('C:/r12-c05-packages-20260911')
for name in ['android-dex-identity.json','android-dex-parsing.json','android-dex-packages-direct.log','android-dex-packages-store.log']:
    capture('prior-parsed-dex/'+name,(prior/name).read_bytes())
for name in ['client','core']:
    for stage in ['pr','main']:
        ci=json.loads((out/'promotion'/f'{name}-ci-{stage}.json').read_bytes())
        assert ci, 'Missing retained CI'
receipt={'status':'PASS_BOUNDED_CURRENT_PACKAGES_AND_SOURCE_PROMOTION','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':source,'source_core':core,'artifacts':artifacts,'package_line':'1.2.0+4053 development','client_pr':120,'client_merge':'36357cb4383fbea25b146876ca3191cba383b49b','core_pr':15,'core_merge':'fc301b94aeafc4589cca7b6f8718129187ca3747','ci':'Both PR and main workflows PASS; client dispatch-only skips retained; initial coordination failures retained','windows_payload_exact_files':304,'windows_ctest_pass':9,'android_signature':'Production self-managed certificate; upload-key AAB signature verified','windows_authenticode':'SKIPPED_BY_OWNER','installed_acceptance':'PENDING_CURRENT_PACKAGES','full_source_license_gate':'OPEN','public_release':False,'store_submission':'NOT_REQUESTED','production_deploy':False,'captures':captures}
(family/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
(out/'package-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
(family/'.gitattributes').write_text('* -text whitespace=cr-at-eol\n*.log -whitespace\n*.patch -whitespace\n')
(family/'README.md').write_text('''# Core6b packages and source promotion — 2026-09-12

Document class: EVIDENCE. [Receipt and capture hashes](receipt.json).
Client `2aa57015783ceb3415e3be62bbf0a698729011c4`; Core
`6b271decead88b708e2fc03984b703b0a4e63ebd`; development `1.2.0+4053`.

- Four APKs and the store AAB pass canonical signing verification. All packaged
  Core and Flutter libraries, four notice sources and compiled client revision
  match. Current DEX bytes exactly match the independently parsed prior inputs;
  those seven namespace checks are reused by byte identity, not repeated.
- Windows installer extraction matches all 304 staged files. All nine CTest
  cases pass. Packaged-DLL synthetic privacy canaries pass in FFI/stdout/stderr
  and five persisted sinks, including setup-path markers; host routes/DNS match.
- Signed client PR120 and Core PR15 merged through ordinary protected flows.
  Both PR/main workflows pass and protections are unchanged. Initial client CI
  failures before coordinated Core promotion remain recorded; dispatch skips
  are not passes. Source promotion is not a binary release.
- Android needed a store-only continuation after two storage stops. The second
  stop crossed the 40 GiB floor by 23,691,264 bytes; that failed receipt remains.
  Old Core caches were hash-verified, archived on owned DE, then relocated;
  retained artifact compression preserved all bytes. Four redundant APK copies
  were removed only after verifying their retained counterparts. No VM or
  evidence history was deleted. The successful store-only run used a 1 GiB E
  abort margin and stayed above the floor (minimum 44,868,575,232 bytes on E).

The canonical builder's APK invocation alone was replaced with four retained
APK hash checks in a local resumer; store build, signing checks and environment
restoration remained intact. Its exact delta is retained. The repository build
script is unchanged. APK sidecars were regenerated by the canonical final checks.

[Current native scan binding](package-native-scan-binding.json) reuses exact
Core6b scan bytes from the [source binding](../2026-09-12-r12-setup-privacy-binding/README.md).
Nine advisory IDs retain bounded module-level dispositions. Full licensing and
corresponding-source obligations, installed TUN/recovery/privacy acceptance and
the complete release gate remain open. Windows Authenticode is
`SKIPPED_BY_OWNER`; no public binary, tag, production deploy or store submission
was made. Phone and host Hiddify were untouched.
''',encoding='utf-8')
for name in ['android-release-audit.md','windows-release-readiness.md']:
    p=client/'docs/operations'/name
    with p.open('a',encoding='utf-8') as f:f.write('''
## 2026-09-12 Core6b current package audit and source promotion

[Exact six development artifacts and protected source merges](evidence/2026-09-12-r12-6b-packages-promotion/README.md)
pass bounded package checks: Android self-managed signatures, exact native
libraries/notices/revision, Windows 304-file extraction and nine CTest cases,
packaged-DLL canaries and five persisted sinks. Client PR120 and Core PR15 plus
both main CI workflows pass; branch protections are unchanged. Failed storage
attempts and byte-preserving retention are recorded. Installed acceptance for
these exact packages, full source/license and release gates remain open.
''')
print(json.dumps({'status':receipt['status'],'captures':len(captures),'bytes':sum(r['bytes'] for r in captures)}))
