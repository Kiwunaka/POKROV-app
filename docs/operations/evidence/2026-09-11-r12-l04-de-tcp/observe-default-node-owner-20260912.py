from pathlib import Path
import hashlib,json,subprocess,time

r=Path(__file__).parent
remote='''import hashlib,json,subprocess,time
targets={'profile_server':'3d297432f8ce6dbcac91f560a4a7de1deb28bfb64f691de605a645eb4bb8339e','resolved_address':'5a8735db03a9b7134a66eca92a6d2e56f20b0eac54acbb9230024804539500fc'}
query="SELECT json_build_object('code',code,'host',host,'enabled',enabled,'port',vless_port,'profiles',transport_profiles_json) FROM nodes ORDER BY code;"
p=subprocess.run(['runuser','-u','postgres','--','psql','-X','-d','portal','-At','-c',query],capture_output=True,text=True,timeout=20)
assert p.returncode==0,'read-only node projection failed'
rows=[json.loads(x) for x in p.stdout.splitlines() if x.strip()];matches=[]
def walk(value,path):
 if isinstance(value,dict):
  for k,v in value.items():yield from walk(v,path+[k])
 elif isinstance(value,list):
  for i,v in enumerate(value):yield from walk(v,path+[str(i)])
 elif isinstance(value,str):
  for label,digest in targets.items():
   if hashlib.sha256(value.encode()).hexdigest()==digest:yield {'target':label,'field_path':'.'.join(path)}
for row in rows:
 profiles=json.loads(row['profiles']) if row['profiles'] else []
 found=list(walk({'host':row['host'],'profiles':profiles},[]))
 if found:matches.append({'node_code':row['code'],'enabled':row['enabled'],'port':row['port'],'matches':found})
print(json.dumps({'captured_epoch':time.time(),'origin':'brain read-only current nodes','rows_checked':len(rows),'matches':matches,'raw_endpoint_material_retained':False}))
'''
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','sudo -n python3 -'],input=remote,capture_output=True,text=True,timeout=35)
assert p.returncode==0,'remote projection failed'
result=json.loads(p.stdout);out=r/'candidate8-default-node-owner-20260912.json';assert not out.exists()
out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
