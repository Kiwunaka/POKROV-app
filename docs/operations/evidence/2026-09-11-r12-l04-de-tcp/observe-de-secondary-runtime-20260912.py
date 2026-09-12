from pathlib import Path
import json,subprocess
r=Path(__file__).parent
remote='''import hashlib,json,subprocess,time
def read(args):
 p=subprocess.run(args,capture_output=True,text=True,timeout=10);assert p.returncode==0;return json.loads(p.stdout)
rules=read(['ip','-j','-4','rule','show']);routes=read(['ip','-j','-4','route','show','table','all']);addr=read(['ip','-j','-4','addr','show','dev','eth0'])
def red(v):
 if isinstance(v,dict):return {k:red(x) for k,x in v.items()}
 if isinstance(v,list):return [red(x) for x in v]
 if isinstance(v,str) and any(c.isdigit() for c in v) and '.' in v:return 'sha256:'+hashlib.sha256(v.encode()).hexdigest()
 return v
p=subprocess.run(['ss','-H','-lntp','sport = :443'],capture_output=True,text=True,timeout=10);assert p.returncode==0
import re
owners=re.findall(r'\\("([A-Za-z0-9_.-]+)"',p.stdout)
print(json.dumps({'captured_epoch':time.time(),'origin':'DE current secondary-address route state','owned_priority_rules':red([x for x in rules if x.get('priority')==12070]),'owned_table_routes':red([x for x in routes if str(x.get('table'))=='33770']),'eth0_flags':addr[0]['flags'],'eth0_operstate':addr[0]['operstate'],'eth0_addresses':red(addr[0]['addr_info']),'listener_process_names':owners,'all_rules_sha256':hashlib.sha256(json.dumps(rules,sort_keys=True).encode()).hexdigest(),'all_routes_sha256':hashlib.sha256(json.dumps(routes,sort_keys=True).encode()).hexdigest(),'production_mutation':False}))
'''
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-de','sudo -n python3 -'],input=remote,capture_output=True,text=True,timeout=30);assert p.returncode==0,'runtime inspection failed'
v=json.loads(p.stdout);out=r/'candidate8-de-secondary-runtime-20260912.json';assert not out.exists();out.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8');print(json.dumps(v))
