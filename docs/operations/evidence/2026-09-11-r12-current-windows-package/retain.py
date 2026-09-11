import datetime,hashlib,json,re,subprocess
from pathlib import Path
out=Path(__file__).parent
client=Path('E:/r12client')
platform=Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start')
work=platform/'docs/developer/work-orders/2026-09-05--consolidated-release-and-post12'
ce=client/'docs/operations/evidence/2026-09-11-r12-current-windows-package'
pe=work/'evidence/current-windows-package-20260911'
assert not ce.exists() and not pe.exists()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
audit=read(out/'windows-package-audit.json');comparison=read(out/'source-and-package-comparison.json')
assert audit['client_revision']=='d9763e8cd7aba9b215015e07c0576f667c1dec09' and audit['bundle_file_count']==304
assert comparison['unchanged_bundle_hashes']==303 and [r['path'] for r in comparison['changed_bundle_files']]==['data/app.so']
assert 'All tests passed!' in (out/'current-navigation-tests.log').read_text(encoding='utf8')
assert 'No issues found!' in (out/'current-app-shell-analyze.log').read_text(encoding='utf8')
assert 'Seed scaffold OK:' in (out/'validate-seed.log').read_text(encoding='utf8')
assert 'Windows bundle ready.' in (out/'build.log').read_text(encoding='utf8')
files={n:out/n for n in ['build.ps1','build-v1.ps1','audit-windows.py','compare.py','sync-runtime.log','sync-runtime-v1.log','validate-seed.log','validate-seed-v1.log','validate-seed-v2.log','build.log','disk-budget-before.json','disk-budget-after-build.json','windows-package-audit.json','source-and-package-comparison.json','client-ci-main.json','app-shell-pub-get.log','current-navigation-tests.log','current-app-shell-analyze.log']}
files['package.manifest.json']=Path(audit['manifest']['path'])
files['package.iss']=Path(audit['packager_script']['path'])
files['retain.py']=Path(__file__)
for d in (ce,pe):d.mkdir(parents=True)
rows=[]
for name,path in files.items():
 raw=path.read_bytes()
 assert re.search(rb'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----\r?\n[A-Za-z0-9+/=\r\n]{32,}',raw) is None
 (ce/name).write_bytes(raw)
 rows.append({'name':name,'source_path':str(path),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
receipt={'schema':'pokrov.r12.current-windows-package/v1','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'result':'PASS_LOCAL_PACKAGE','client_parent':subprocess.check_output(['git','-C',str(client),'rev-parse','HEAD'],text=True).strip(),'platform_parent':subprocess.check_output(['git','-C',str(platform),'rev-parse','HEAD'],text=True).strip(),'client_revision':audit['client_revision'],'core_revision':audit['core_revision'],'installer':audit['installer'],'aot_revision_binding':audit['aot_revision_binding'],'bundle_files':304,'required_hashes':11,'pe_inventories':15,'unchanged_from_previous_bundle':303,'changed_bundle_files':['data/app.so'],'current_navigation_tests':'3_PASS','current_app_shell_analyze':'PASS','seed_gate':'PASS','main_ci':comparison['main_ci'],'retained_metadata_files':2,'retained_metadata_bytes':16920,'release_archive_binary_copies_created':False,'retained_files':rows,'client_evidence_path':str(ce),'source_logical_git_diff_empty_after_build':True,'working_status_caveat':'Six LFS/CRLF paths are reported modified by stat status; git diff HEAD returns no logical content delta. Raw compiled component hashes are verified.','signing_status':'SKIPPED_BY_OWNER','installer_payload_extraction':'NOT_RUN_KNOWN_TOOL_LIMIT','installed_current_package':False,'vm_started':False,'phone_used':False,'release_candidate_or_public_pointer_changed':False,'push_merge_deploy_publication_performed':False,'preparation_failures_retained':['seed v1 rejected unhydrated Android AAR pointer; exact local Core artifact synchronized','seed v2 rejected omitted rollback metadata; only two exact Git JSON files materialized'],'remaining':['current installer internal payload/device proof','installed current client network and N05 fault matrix','current Android package and device gates','full original R12 and supplementary release scope']}
raw=(json.dumps(receipt,indent=2)+'\n').encode()
(ce/'receipt.json').write_bytes(raw);(pe/'receipt.json').write_bytes(raw)
print(json.dumps({'result':receipt['result'],'retained_files':len(rows),'installer_sha256':audit['installer']['sha256'],'unchanged_bundle_files':303}))
