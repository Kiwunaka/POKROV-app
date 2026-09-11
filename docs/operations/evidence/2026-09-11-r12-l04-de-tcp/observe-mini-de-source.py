import subprocess,json,hashlib,pathlib
hosts={}
for alias in ['pokrov-de','pokrov-mini']:
 p=subprocess.run(['ssh','-G',alias],capture_output=True,text=True,check=True);hosts[alias]=next(x.split(' ',1)[1] for x in p.stdout.splitlines() if x.startswith('hostname '))
s='''import subprocess,json,hashlib,socket
hosts=HOSTS
routes=json.loads(subprocess.check_output(['ip','-j','-4','route','get',hosts['pokrov-de']],text=True));r=routes[0]
v={'route_device':r.get('dev'),'preferred_source_matches_ssh_alias':r.get('prefsrc')==hosts['pokrov-mini'],'source_sha256':hashlib.sha256(r.get('prefsrc','').encode()).hexdigest(),'target_alias':'pokrov-de','tcp_probe_has_no_http_or_tls_payload':True}
print(json.dumps(v))
'''.replace('HOSTS',repr(hosts))
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','pokrov-mini','python3 -'],input=s,capture_output=True,text=True,check=True)
v=json.loads(p.stdout);r=pathlib.Path('C:/r12-l04-ui-poll-20260911');out=r/'mini-de-route-source.json';assert not out.exists();out.write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v))
