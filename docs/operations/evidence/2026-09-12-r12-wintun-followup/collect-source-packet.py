from pathlib import Path
import base64,hashlib,json,subprocess
out=Path(__file__).parent/'source-packet-evidence';out.mkdir()
remote='/tmp/pokrov-r12-core-validation-1c8b33f6a771409a/wintun-final-880b-20260912/source-packet-v2'
code="""from pathlib import Path
import base64,hashlib,json
p=Path(REMOTE)
report=json.loads((p/'progress.json').read_bytes())
assert report['status']=='PASS_SOURCE_PREPARATION_ONLY' and report['core_files']==3339 and report['packet_entries']==3902
files=[p/'progress.json',p/'offline-graph-checks.json',p/'source-manifest.json',*sorted(p.glob('*.offline.stdout.json')),*sorted(p.glob('*.offline.stderr.log'))]
rows=[]
for f in files:
 raw=f.read_bytes();rows.append({'name':f.name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'base64':base64.b64encode(raw).decode()})
print(json.dumps(rows))
""".replace('REMOTE',repr(remote))
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de','python3 -'],input=code,text=True,capture_output=True,timeout=120,check=True)
rows=json.loads(p.stdout)
for row in rows:
 assert Path(row['name']).name==row['name']
 raw=base64.b64decode(row.pop('base64'));assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
 (out/row['name']).write_bytes(raw)
(out/'collection.json').write_text(json.dumps({'status':'PASS_METADATA_BYTES_RETAINED','remote_host':'pokrov-de','remote_path':remote,'files':rows},indent=2)+'\n')
report=json.loads((out/'progress.json').read_bytes())
print(json.dumps({'status':report['status'],'metadata_files':len(rows),'archive':report['archive'],'steps':[{k:s[k] for k in ['name','exit_code','network_isolated']} for s in report['steps']]}))
