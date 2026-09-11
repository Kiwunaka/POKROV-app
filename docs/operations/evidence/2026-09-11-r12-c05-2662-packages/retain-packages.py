from pathlib import Path
import datetime,hashlib,json,re,subprocess,zipfile
out=Path('C:/r12-c05-packages-20260911');client=Path('E:/r12client');native=Path('C:/r12-c05-utls-update-20260911');source='212bd2f30c9f91d80fd3a6c08fb5557be8457f1c';core='2662f76a3303a0518bb07fbbdc449c066de2f95b'
sha=lambda b:hashlib.sha256(b).hexdigest()
a=json.loads((out/'android-package-audit.json').read_bytes());w=json.loads((out/'windows-package-audit.json').read_bytes());progress=json.loads((out/'build-progress-retry.json').read_bytes())
assert progress['status']=='PASS' and progress['source_commit']==source
artifacts=[x['artifact'] for x in a['artifacts']]+[w['installer']]
for row in artifacts:
 f=Path(row['path']);assert f.stat().st_size==row['size'] and sha(f.read_bytes())==row['sha256']
assert json.loads((out/'comparison.json').read_bytes())['status']=='PASS_EXACT_PAYLOAD'
assert json.loads((out/'osv-runtime-graph-summary.json').read_bytes())['advisory_package_count']==0
assert '100% tests passed, 0 tests failed out of 9' in (out/'windows-native-tests.log').read_text(encoding='utf8')
scans={f.stem.removesuffix('.scan'):json.loads(f.read_bytes()) for f in (native/'binary-scans').glob('*.scan.json')};assert len(scans)==5
bindings=[];aot=[]
for package in a['artifacts']:
 with zipfile.ZipFile(package['artifact']['path']) as z:
  for lib in package['libraries']:
   if lib['entry'].endswith('/libpokrov-core.so'):
    abi=lib['entry'].split('/')[-2];scan=scans['libpokrov-core-'+abi];assert scan['binary']['sha256']==lib['sha256'];bindings.append({'package':Path(package['artifact']['path']).name,'entry':lib['entry'],'binary_sha256':lib['sha256'],'fresh_scan':f'libpokrov-core-{abi}.scan.json','scan_sha256':sha((native/'binary-scans'/f'libpokrov-core-{abi}.scan.json').read_bytes())})
   if lib['entry'].endswith('/libapp.so'):
    raw=z.read(lib['entry']);assert source.encode() in raw;aot.append({'package':Path(package['artifact']['path']).name,'entry':lib['entry'],'sha256':lib['sha256'],'exact_source_revision_string_present':True})
core_file=next(x for x in w['bundle_inventory'] if x['relative_path']=='pokrov-core.dll');assert core_file['sha256']==scans['pokrov-core']['binary']['sha256'];bindings.append({'package':Path(w['installer']['path']).name,'entry':'pokrov-core.dll','binary_sha256':core_file['sha256'],'fresh_scan':'pokrov-core.scan.json','scan_sha256':sha((native/'binary-scans/pokrov-core.scan.json').read_bytes())})
app=next(x for x in w['bundle_inventory'] if x['relative_path']=='data/app.so');assert source.encode() in Path(app['path']).read_bytes();aot.append({'package':Path(w['installer']['path']).name,'entry':'data/app.so','sha256':app['sha256'],'exact_source_revision_string_present':True})
(out/'package-native-scan-binding.json').write_text(json.dumps({'status':'PASS_EXACT_BYTES_REUSE_FRESH_SAME_DAY_SCANS','core_revision':core,'bindings':bindings,'advisories':scans['pokrov-core']['advisories'],'precision':'Module-level fallback: extracted symbol count zero; 21 trace records are not function reachability proof','x86':'Scanned AAR ABI, not one of the three distributed Android ABIs'},indent=2)+'\n')
(out/'package-build-identity.json').write_text(json.dumps({'status':'PASS_BUILD_COMMANDS_AND_AOT_REVISION_BINDING','source_revision':source,'build_progress':progress,'aot_artifacts':aot,'limit':'Static revision string presence plus retained build commands; installed runtime identity is a separate check'},indent=2)+'\n')
names=['build.ps1','build-retry.ps1','build-progress.json','build-progress-retry.json','windows-build.log','windows-build-retry.log','android-build-retry.log','audit-windows.py','audit-android.py','windows-package-audit.json','android-package-audit.json','parse-dex.py','android-dex-identity.json','android-dex-parsing.json','android-dex-packages-direct.log','android-dex-packages-store.log','android-dex-packages-direct.stderr.log','android-dex-packages-store.stderr.log','query-advisories.py','osv-query-public-packages.json','osv-response-public-packages.json','osv-runtime-graph-summary.json','dependency-advisories.log','android-pub-deps.json','windows-pub-deps.json','gradle-modules.init.gradle','gradle-modules.log','android-gradle-modules-direct.json','android-gradle-modules-store.json','native-tests.ps1','windows-native-tests.log','package-native-scan-binding.json','package-build-identity.json','start-extractor.ps1','extract-installer.py','guest-extract.py','compare-payload.py','comparison.json','extraction.json','extract.log','payload-inventory.json','extractor-guest-before.json','extractor-dispatch.json','extractor-unit.log','extractor-vm-budget.json','extractor-vm-start.log','extractor-vm-restoration.json','prepare-retry.ps1','retry-retention.json','output-retention.json','compress-completed-intermediates.py','completed-intermediates-compression.json']
family=client/'docs/operations/evidence/2026-09-11-r12-c05-2662-packages';assert not family.exists();family.mkdir()
(family/'.gitattributes').write_text('* -text whitespace=cr-at-eol\n*.log whitespace=-blank-at-eol,-blank-at-eof,-space-before-tab,cr-at-eol\n')
captures=[]
for name in names:
 raw=(out/name).read_bytes();assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',raw),name
 (family/name).write_bytes(raw);captures.append({'name':name,'bytes':len(raw),'sha256':sha(raw)})
for item in a['artifacts']:
 p=Path(item['signing_receipt']['path']);raw=p.read_bytes();(family/p.name).write_bytes(raw);captures.append({'name':p.name,'bytes':len(raw),'sha256':sha(raw)})
manifest=Path(w['manifest']['path']);raw=manifest.read_bytes();(family/'windows-package.manifest.json').write_bytes(raw);captures.append({'name':'windows-package.manifest.json','bytes':len(raw),'sha256':sha(raw)})
receipt={'status':'PASS_BOUNDED_EXACT_PACKAGES','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'client_source':source,'core_source':core,'package_line':'1.2.0+4053 development, not successor release identity','artifacts':artifacts,'android_signer_sha256':'0a0602a7df5d96a0b427909d004f3ddf26def86587634bf16694da8d654b2500','windows_signing':'SKIPPED_BY_OWNER','staged_and_extracted_windows_files':304,'windows_native_ctest':{'passed':9,'failed':0},'public_package_queries':{'Pub':75,'Maven':63,'returned_advisory_ids':0,'direct_store_maven_graph_equal':True},'native_scan':'Exact packaged bytes match same-day Core scans; nine IDs at module precision; no whole-program vulnerability clearance','source_archive':'E:/r12-2662-source-20260911/pokrov-core-2662f76-source-review.zip','source_archive_sha256':'988573fde7433cc20c40f40a4696d0fa5b54aea1c936feec39cc7dab3715b25d','captures':captures,'installed_acceptance':'NOT_PERFORMED_FOR_THESE_PACKAGES','full_licensing_corresponding_source':'OPEN_BEYOND_EXACT_NEW_UTLS_ROOT_LICENSE','public_release':False,'production_deploy':False,'store_submission':'NOT_REQUESTED'}
(family/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');(out/'package-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
for x in captures:assert sha((family/x['name']).read_bytes())==x['sha256']
(family/'README.md').write_text('''# Core2662 exact development packages — 2026-09-11

Document class: EXECUTION_EVIDENCE. **PASS_BOUNDED_EXACT_PACKAGES**.
Client source `212bd2f30c9f91d80fd3a6c08fb5557be8457f1c`; Core
`2662f76a3303a0518bb07fbbdc449c066de2f95b`; development line `1.2.0+4053`.
[Receipt](receipt.json) lists six artifacts, signing scope and every retained file hash.

- Four direct APKs and store AAB pass the production signing helper. Core and
  Flutter bytes and four notice sources match in every package. Direct/store
  DEX were parsed independently; four direct APKs share exact DEX bytes.
- Windows installer and its staged payload pass 304-file comparison after
  unprivileged, network-isolated extraction in the existing Ubuntu lab VM.
  The extractor still emits 304 multipart-checksum warnings; independent
  SHA-256 readback of every file is the identity oracle. The VM is powered off.
- All nine Windows native CTest cases pass. 75 Pub and 63 Maven public coordinates
  return zero OSV IDs. Both Android flavor graphs are exactly equal.
- [Native scan binding](package-native-scan-binding.json) ties packaged libraries
  to the [fresh Core scans](../2026-09-11-r12-c05-utls-binding/README.md).
  Nine advisory IDs remain at module precision; no reachable-vulnerability
  clearance is inferred from stripped binaries.
- The first Windows attempt failed with missing generated C++ wrapper files.
  Preserving and invalidating old Flutter output cache allowed the unchanged
  source to build. Failed logs and all previous output hashes remain available.
  Completed Android intermediates were compressed with exact before/after
  SHA-256 checks to restore the 40 GiB disk floor.

The source review archive contains 3693 verified entries. Its own root uTLS
license is authenticated; full license compatibility, corresponding-source
assessment and native reconstruction remain open. These packages have not
been installed, publicly released or submitted to a store. Older installed
receipts retain their exact earlier bytes. Windows Authenticode remains
`SKIPPED_BY_OWNER` for the existing direct-beta exception.
''',encoding='utf8')
owner=client/'docs/architecture/bootstrap-workflow.md';text=owner.read_text(encoding='utf8');old='The pinned Psiphon fork still lacks a root LICENSE; this file attribution\ndoes not establish clearance for the whole fork.';assert old in text
text=text.replace(old,'The previous Core904 Psiphon fork lacked a root LICENSE; that file attribution\ndid not establish clearance for the whole fork. The current Core2662 binding\nuses authenticated uTLS7a1fc with its own root LICENSE.\n[Exact development packages](../operations/evidence/2026-09-11-r12-c05-2662-packages/README.md)\nretain that notice, fresh package audits and the remaining source/license limits.',1)
owner.write_text(text,encoding='utf8')
print(json.dumps({'status':receipt['status'],'captured_files':len(captures),'bytes':sum(x['bytes'] for x in captures),'artifacts':len(artifacts)}))
