import hashlib,json,os,pathlib,platform,socket,subprocess,time,ast
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate10-gui-route-20260914.json';assert not out.exists()
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json')
result={'status':'WAITING_FOR_GUI','started_epoch':time.time(),'candidate_sha256':'d4c3ead8786cfdd91ff7851e3634d7025e899323db13636803f3064551628f17','control':'unmodified installed GUI and production polkit; observer uses read-only status only','modes':[]}
def save():out.write_text(json.dumps(result,indent=2)+chr(10));out.chmod(0o644)
def snapshot():
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(35);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-gui-route-differential','action':'status','payload':{}})+chr(10)).encode());v=json.loads(s.makefile('rb').readline(65537));assert v['ok'];return v['snapshot']
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
def network():
 hashes={}
 for name,args in commands.items():
  p=subprocess.run(args,capture_output=True);assert p.returncode==0;hashes[name]=hashlib.sha256(p.stdout).hexdigest()
 return hashes
before=network();assert before==json.loads((r/'candidate8-gui-modes-baseline-20260913.json').read_text())['network_before'];assert not pathlib.Path('/sys/class/net/pokrov0').exists()
result['network_before']=before
backup=r/'private-gui-route10-original-20260914.json';assert not backup.exists();backup.write_bytes(profile.read_bytes());backup.chmod(0o600)
result['profile_before_sha256']=hashlib.sha256(profile.read_bytes()).hexdigest()
pid=int(subprocess.check_output(['pgrep','-x','pokrov'],text=True).strip());p=pathlib.Path('/proc',str(pid));assert p.stat().st_uid==1000
result['gui']={'pid':pid,'uid':1000,'cgroup':(p/'cgroup').read_text().strip()}
assert hashlib.sha256((p/'exe').read_bytes()).hexdigest()=='af46523ff098a7177046a9097b7c2db9c2473a8a17612f2e64ba920e255da8a0'
tree=ast.parse((r/'private-route7-443-sampled-ru.py').read_text());target=None
for n in tree.body:
 if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='target' for t in n.targets):target=ast.literal_eval(n.value)
assert isinstance(target,str);result['ru_target_sha256']=hashlib.sha256(target.encode()).hexdigest();save()
seen=set();last_row=None
try:
 while time.time()-result['started_epoch']<900:
  snap=snapshot();mode=json.loads(pathlib.Path('/home/pokrovqa/.local/share/space.pokrov.linux/pokrov-client-experience-v1.json').read_text()).get('firstRouteScopeMode')
  if snap['phase']=='running' and mode in ['fullTunnel','allExceptRu'] and mode not in seen:
   seen.add(mode);raw=profile.read_bytes();config=json.loads(raw)
   assert config['route']['default_domain_resolver']=={'server':'dns-direct','strategy':'ipv4_only'}
   direct={x['tag'] for x in config.get('outbounds',[]) if x.get('type')=='direct'}
   rule_sets={x['tag'] for x in config.get('route',{}).get('rule_set',[]) if 'ru' in x.get('tag','').lower()}
   row={'mode':mode,'started_epoch':time.time(),'authorization':'GUI/polkit','initial_health':snap,'profile_sha256':hashlib.sha256(raw).hexdigest(),'ru_rule_set_count':len(rule_sets),'direct_ru_rule_count':sum(x.get('outbound') in direct and any(t in rule_sets for t in x.get('rule_set',[])) for x in config.get('route',{}).get('rules',[])),'http':[]};result['modes'].append(row);result['status']='MEASURING';save()
   for label,url,expected in [('app','https://app.pokrov.space/','200'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe','204')]:
    p=subprocess.run(['curl','-4','--silent','--show-error','--max-time','15','--output','/dev/null','--write-out','%{http_code}',url],capture_output=True,text=True)
    row['http'].append({'target':label,'exit':p.returncode,'code':p.stdout[-3:],'pass':p.returncode==0 and p.stdout[-3:]==expected})
   private=r/('private-gui-route10-'+mode+'-20260914.json');assert not private.exists();private.write_bytes(raw);private.chmod(0o600)
   def core_sockets():
    p=subprocess.run(['ss','-H','-n','-t','-p','dst',target,'dport','=',':443'],capture_output=True,text=True,check=True)
    return {line for line in p.stdout.splitlines() if '"pokrov-core"' in line and line.startswith('ESTAB')}
   existing=core_sockets();row['ru_tcp']={'connected':False,'core_direct_socket':False,'new_core_direct_socket':False,'core_sockets_before':len(existing),'samples':0}

   try:
    with socket.create_connection((target,443),timeout=12):
     row['ru_tcp']['connected']=True;end=time.monotonic()+4
     while time.monotonic()<end:
      p=subprocess.run(['ss','-H','-n','-t','-p','dst',target,'dport','=',':443'],capture_output=True,text=True);assert p.returncode==0
      row['ru_tcp']['new_core_direct_socket']|=bool(core_sockets()-existing);row['ru_tcp']['core_direct_socket']|=any('"pokrov-core"' in line and line.startswith('ESTAB') for line in p.stdout.splitlines());row['ru_tcp']['samples']+=1;time.sleep(.1)
   except OSError as e:row['ru_tcp']['failure_class']=type(e).__name__
   row['ipv6_documentation_route_rejected']=subprocess.run(['ip','-6','route','get','2001:db8::1'],capture_output=True).returncode!=0
   routes=json.loads(subprocess.check_output(['ip','-N','-j','-6','route','show','table','all'],text=True))
   row['ipv6_owned_reject_route']=any(str(x.get('table'))=='20555' and str(x.get('protocol'))=='243' and str(x.get('type'))=='7' and x.get('dev')=='lo' and x.get('metric')==42700 for x in routes)
   p=subprocess.run(['getent','ahostsv4','app.pokrov.space'],capture_output=True);row['system_dns']=p.returncode==0 and bool(p.stdout.strip())
   row['ru_tcp']['core_sockets_after']=len(core_sockets());row['finished_epoch']=time.time();row['phase_after']=snapshot()['phase'];row['pass']=snap['dns_ready'] is True and snap['core_egress_validated'] is True and snap['message_code']=='connected' and all(x['pass'] for x in row['http']) and row['system_dns'] and row['ipv6_documentation_route_rejected'] and row['ipv6_owned_reject_route'] and row['ru_tcp']['connected'] and row['ru_tcp']['new_core_direct_socket']==(mode=='allExceptRu');last_row=row;result['status']='WAITING_FOR_GUI_DISCONNECT';save()
  if last_row is not None and snap['phase']!='running' and not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists():
   last_row['network_restored']=network()==before;save();last_row=None
   if len(seen)==2:result['status']='COMPLETE';break
  time.sleep(1)
 else:result['status']='OBSERVER_DEADLINE'
except Exception as e:result['status']='OBSERVER_ERROR';result['failure_class']=type(e).__name__
finally:result['finished_epoch']=time.time();save()
