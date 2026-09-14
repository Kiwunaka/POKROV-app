from pathlib import Path
import json,csv,collections,subprocess,hashlib,zipfile,ast,re
p=Path('C:/r12-l04-recheck-20260913');c=Path('E:/r12client');r=Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start');w=r/'docs/developer/work-orders/2026-09-05--consolidated-release-and-post12';d=c/'docs/operations/evidence/2026-09-13-r12-l04-recheck'
receipt=json.loads((d/'receipt.json').read_text());n=0
for x in receipt['files']:
 assert hashlib.file_digest((d/x['path']).open('rb'),'sha256').hexdigest()==x['sha256'];n+=1
v=json.loads((d/'de-comparison.json').read_text());assert v['unit']['MainPID']=='0' and v['unit']['ExecMainStatus']=='0'
obs=v['result']['observations'];assert len(obs)==3
assert all(x['curl_exit']==0 and x['http_code'] in [200,204] for row in obs[:2] for x in row['requests'])
assert collections.Counter(x['curl_exit'] for x in obs[2]['requests'])=={28:1,35:5}
assert v['result']['original_profile_restored'] and all(v['result']['final_network_matches_baseline'].values())
m=json.loads((d/'runtime-modes.json').read_text())['result'];assert m['status']=='PASS_RUNTIME_FIXTURES' and len(m['modes'])==2
assert all(row['pass'] and row['network_restored'] for row in m['modes']) and m['original_profile_restored'] and all(m['final_network_matches_baseline'].values())
f=json.loads((d/'final-readback.json').read_text());assert f['checked_payload_entries']==302 and f['no_tun'] and f['no_recovery'] and f['gui']==[{'pid':136118,'uid':1000}] and f['modes_unit_deactivated_successfully'] and not f['modes_unit_failure_message_present']
script_count=0
with zipfile.ZipFile(d/'scripts.zip') as z:
 for name in z.namelist():
  raw=z.read(name);ast.parse(raw.decode());assert not re.search(rb'(?i)(vless://|hysteria2://|BEGIN (?:OPENSSH|RSA|EC|PRIVATE) PRIVATE KEY|Bearer [A-Za-z0-9._-]{15,})',raw);script_count+=1
 for native,stored in [('guest-de-recheck-20260913.py','guest-recheck.py'),('guest-modes-20260913.py','guest-modes.py')]:assert f['native_scripts'][native]==hashlib.sha256(z.read(stored)).hexdigest()
reg='docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/R12-REGISTER.csv'
before=list(csv.DictReader(subprocess.check_output(['git','show','HEAD:'+reg],cwd=r).decode('utf-8').splitlines()));after=list(csv.DictReader((r/reg).open(encoding='utf-8')));assert len(before)==len(after)==83
assert [b['id'] for a,b in zip(before,after) if a!=b]==['R12-L04']
for a,b in zip(before,after):assert all(a[k]==b[k] for k in a if k!='reconciliation')
counts=dict(collections.Counter(x['status'] for x in after));assert counts=={'verified':48,'active':28,'queued':6,'blocked':1}
for repo in [c,r]:subprocess.run(['git','diff','--check'],cwd=repo,capture_output=True,check=True)
assert not subprocess.check_output(['git','diff','--name-only','--','artifacts/releases'],cwd=c).strip()
links=0
for doc in [d/'README.md',c/'apps/linux_shell/README.md',w/'EXECUTION-L04-RECHECK-2026-09-13.md']:
 for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
  if '://' in target:continue
  file=target.split('#')[0];dest=Path(file) if re.match(r'^[A-Z]:/',file) else doc.parent/file
  assert dest.exists(),str(dest);links+=1
v={'status':'PASS','retained_payload_hashes':n,'syntax_checked_scripts':script_count,'native_script_byte_matches':2,'focused_local_links':links,'preserved_status_counts':counts,'only_reconciliation_changed':'R12-L04','client_release_artifacts_unchanged':True,'diff_checks':'PASS'}
(p/'validation.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v))
