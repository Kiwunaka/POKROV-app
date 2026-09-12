from pathlib import Path
import datetime,hashlib,json,subprocess
out=Path(__file__).parent
source='8067520c7b9230ab0c66823fae9ae78791f1a838'
assert subprocess.check_output(['git','-C','E:/r12client','rev-parse','HEAD'],text=True).strip()==source
reports={name:json.loads((out/name).read_bytes()) for name in ['android-package-audit.json','windows-package-audit.json','direct-apks-verified.json','android-direct-progress.json','android-build-progress-store-only.json','windows-build-progress.json','comparison.json','windows-native-ctest.json']}
for n in ['android-direct-progress.json','android-build-progress-store-only.json']:
 r=reports[n];assert r['status']=='PASS' and r['min_free_c']>40*2**30 and r['min_free_e']>40*2**30
w=reports['windows-build-progress.json'];assert w['status']=='PASS' and w['samples']
assert all(row['free_c']>40*2**30 and row['free_e']>40*2**30 for row in w['samples'])
assert reports['comparison.json']['status']=='PASS_EXACT_PAYLOAD' and reports['comparison.json']['extracted_files']==304
assert reports['windows-native-ctest.json']['status']=='PASS_NINE_NATIVE_TESTS'
for n in ['android-package-audit.json','windows-package-audit.json','direct-apks-verified.json']:assert reports[n]['source_client']==source
artifacts=[r['artifact'] for r in reports['android-package-audit.json']['artifacts']]+[reports['windows-package-audit.json']['installer']]
assert len(artifacts)==6
for a in artifacts:
 p=Path(a['path']);assert p.stat().st_size==a['size']
 with p.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==a['sha256']
main=json.loads(Path('C:/r12-marker-atomicity-promotion-20260912/client-ci-main.json').read_bytes());assert main['status']=='PASS' and main['source']=='d6c7c3deaed34afde5283ada585ee2860c9e1490'
r={'status':'PASS_SIX_CURRENT_LOCAL_PACKAGES','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':source,'source_core':'6b271decead88b708e2fc03984b703b0a4e63ebd','artifacts':artifacts,'source_pr':125,'merge':main['source'],'main_ci':'PASS','windows_installer_payload_files':304,'windows_native_ctest':9,'current_package_installation':'NOT_PERFORMED','authenticode':'SKIPPED_BY_OWNER','store_submission':'NOT_REQUESTED','public_distribution':'NOT_PERFORMED','full_release_gates':'OPEN','prior_physical_huawei_proof':'F711_PACKAGE_ONLY_NOT_TRANSFERRED','stopped_build_evidence':'stopped-android-direct-progress.json','storage_retention':'storage-retention.json','storage_removal':'storage-removal.json'}
(out/'packages-result.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({'status':r['status'],'packages':len(artifacts),'bytes':sum(a['size'] for a in artifacts)}))
