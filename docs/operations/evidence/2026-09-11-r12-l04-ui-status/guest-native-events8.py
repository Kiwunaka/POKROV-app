import pathlib,subprocess,json
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');start=json.loads((r/'candidate8-gui-core-loss.json').read_bytes())['started_epoch']
fields=['POKROV_SCHEMA','POKROV_EVENT','POKROV_OUTCOME','POKROV_AUTHORIZATION_BACKEND','POKROV_ERROR_CODE','POKROV_NETWORK_STAGE','POKROV_NETWORK_SUBSYSTEM','POKROV_GENERATION']
p=subprocess.run(['journalctl','-u','pokrov-linuxd.service','--since','@'+str(int(start)),'--no-pager','-o','json'],capture_output=True,text=True,check=True)
events=[]
for line in p.stdout.splitlines():
 v=json.loads(line)
 if v.get('POKROV_SCHEMA')=='pokrov-linux-operational-v1':events.append({k:v[k] for k in fields if k in v})
count=sum(e.get('POKROV_EVENT')=='authorization' and e.get('POKROV_AUTHORIZATION_BACKEND')=='polkit_dbus' and e.get('POKROV_OUTCOME')=='pass' for e in events);assert count>=2
result={'status':'PASS_CURRENT_GUI_POLKIT_EVENTS','started_epoch':start,'polkit_dbus_pass_count':count,'events':events,'projection':'native structured journald fields only; initial MESSAGE-based readback projection was empty and is not authorization proof'}
out=r/'candidate8-daemon-events.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='events'}))
