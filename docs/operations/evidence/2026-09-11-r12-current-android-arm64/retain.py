from pathlib import Path
import datetime,hashlib,json,re,subprocess
out=Path(__file__).parent
client=Path('E:/r12client');platform=Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start')
work=platform/'docs/developer/work-orders/2026-09-05--consolidated-release-and-post12'
ce=client/'docs/operations/evidence/2026-09-11-r12-current-android-arm64';pe=work/'evidence/current-android-arm64-20260911'
assert not ce.exists() and not pe.exists()
audit=json.loads((out/'android-package-audit.json').read_bytes());assert audit['status']=='PASS_LOCAL_PACKAGE'
files={n:out/n for n in ['abi-probe.gradle','abi-injected-v2.log','abi-fixed-arm64.log','abi-fixed-production.log','release-handoff-v2-v2.log','seed-before-build.log','build-arm64.ps1','build-arm64-v1.ps1','build-arm64-v2.ps1','run-build.py','build-v1-missing-harness-root.log','build-v1-disk-and-exit.json','build-v2-exitcode-context.log','build-v2-disk-and-exit.json','build.log','build-disk-and-exit.json','audit-android.py','android-package-audit.json']}
files['apk.signing.json']=Path(audit['signing_receipt']['path']);files['retain.py']=Path(__file__)
for d in (ce,pe):d.mkdir(parents=True)
rows=[]
for name,path in files.items():
 raw=path.read_bytes();assert not re.search(rb'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{32,}',raw)
 (ce/name).write_bytes(raw);rows.append({'name':name,'source_path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
receipt={'schema':'pokrov.r12.current-android-arm64-retained/v1','status':'PASS_LOCAL_PACKAGE','observed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client_sha':audit['source_client_sha'],'source_main_base':audit['source_main_base'],'feature_fix_sha':audit['feature_fix_sha'],'source_core_sha':audit['source_core_sha'],'artifact':audit['artifact'],'abi':'arm64-v8a','signing':'PRODUCTION_SELF_MANAGED_CERTIFICATE_MATCH','native_libraries_verified':3,'notice_sources_verified':4,'embedded_exact_revision':True,'abi_regression':'PASS_ARM64_ONLY_AND_EXISTING_FOUR_APK_PRODUCTION_CONFIGURATION','release_handoff_contract':'16_PASS','seed_before_build':'PASS','minimum_observed_free_gib':{k:round(v/1024**3,3) for k,v in audit['disk_budget']['minimum_observed_free_bytes'].items()},'retained_files':rows,'client_evidence_path':str(ce),'source_product_equals_feature':True,'source_product_delta_from_main':['apps/android_shell/android/app/build.gradle'],'source_working_logical_diff_empty':True,'source_status_caveat':'Six existing LFS/CRLF stat entries remain; logical git diff HEAD is empty.','build_warning':'Kotlin incremental caches reported different C/E roots; compiler fallback completed and package build/signature checks exited 0. No cache was deleted.','harness_initial_failures_retained':['Wrong external harness support seed root before signing/build','Unset LASTEXITCODE in isolated PowerShell context before build; initialized in external harness'],'phone_used':False,'vm_started':False,'installed':False,'public_candidate_changed':False,'push_merge_deploy_publication':False,'other_current_android_artifacts':'NOT_BUILT_CAPACITY_FLOOR','full_goal':'OPEN'}
raw=(json.dumps(receipt,indent=2)+'\n').encode();(ce/'receipt.json').write_bytes(raw);(pe/'receipt.json').write_bytes(raw)
p=client/'.gitattributes';s=p.read_text(encoding='utf-8');line='/docs/operations/evidence/2026-09-11-r12-current-android-arm64/** -text';assert line not in s;p.write_text(s.rstrip()+'\n'+line+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'retained_files':len(rows),'apk_sha256':audit['artifact']['sha256']}))
