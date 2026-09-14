import hashlib,json,os,pathlib,platform,socket,subprocess,sys,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
mode=sys.argv[1];assert mode in ('cancel','timeout','missing-agent')
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/('candidate8-auth-'+mode+'.json');assert not out.exists()
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-8'
assert hashlib.sha256(pathlib.Path('/usr/lib/pokrov/pokrov-linuxd').read_bytes()).hexdigest()=='2236009c4815b632c176dfeafcc7bc7c8bc090a0a819ea9a58bcd7ad2688b983'
gui=pathlib.Path('/proc/1648');assert gui.stat().st_uid==1000 and (gui/'exe').resolve()==pathlib.Path('/usr/lib/pokrov/ui/pokrov')
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
def network():return {k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()}
def absent():return not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
def status():
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(8);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'auth-negative8-status-'+mode,'action':'status','payload':{}})+'\n').encode());return json.loads(s.makefile('rb').readline(65537))
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json');before_profile=hashlib.sha256(profile.read_bytes()).hexdigest();before=network();assert absent()
result={'candidate_sha256':'b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933','mode':mode,'started_epoch':time.time(),'before_status':status(),'network_before':before,'gui_uid':1000,'gui_pid':1648,'status':'ARMED','runtime_mutation_seen':False,'authorization_action':'actual GUI action; root observer does not request a mutation'}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
save();fields=['POKROV_SCHEMA','POKROV_EVENT','POKROV_OUTCOME','POKROV_AUTHORIZATION_BACKEND','POKROV_ERROR_CODE'];events=[]
for _ in range(100):
 result['runtime_mutation_seen']|=not absent()
 p=subprocess.run(['journalctl','-u','pokrov-linuxd.service','--since','@'+str(result['started_epoch']),'--no-pager','-o','json'],capture_output=True,text=True,check=True)
 events=[]
 for line in p.stdout.splitlines():
  v=json.loads(line)
  if v.get('POKROV_SCHEMA')=='pokrov-linux-operational-v1' and v.get('POKROV_EVENT')=='authorization':events.append(dict({k:v[k] for k in fields if k in v},epoch=int(v['__REALTIME_TIMESTAMP'])/1000000))
 if events:break
 time.sleep(1)
result['events']=events;result['after_status']=status();after=network();result['network_unchanged']={k:after[k]==v for k,v in before.items()};result['profile_unchanged']=hashlib.sha256(profile.read_bytes()).hexdigest()==before_profile;result['runtime_absent']=absent();result['finished_epoch']=time.time();result['status']='OBSERVED' if events else 'NO_AUTH_EVENT';save()
assert events and not result['runtime_mutation_seen'] and result['runtime_absent'] and result['profile_unchanged'] and all(result['network_unchanged'].values())
assert all(x['POKROV_AUTHORIZATION_BACKEND']=='polkit_dbus' and x['POKROV_OUTCOME']!='pass' for x in events)
print(json.dumps({'status':result['status'],'mode':mode,'events':events,'runtime_absent':True,'profile_unchanged':True,'network_unchanged':True}))
