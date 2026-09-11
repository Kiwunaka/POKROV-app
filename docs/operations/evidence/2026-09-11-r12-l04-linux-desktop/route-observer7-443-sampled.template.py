import hashlib,json,os,pathlib,socket,subprocess,time
mode=MODE_LITERAL;target=TARGET_LITERAL
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/('candidate7-'+mode+'-443-sampled-route-proof.json');assert not out.exists()
result={'candidate_sha256':'5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d','selected_gui_mode':mode,'target_owner':'POKROV pokrov-ru TCP endpoint from current configured host; no authentication attempted','started_epoch':time.time(),'running_observed':False}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def state():
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(5);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall(b'{"protocol":"pokrov-linuxd-v1","request_id":"l04-route-proof","action":"status","payload":{}}\n');return json.loads(s.makefile('rb').readline(65537)).get('snapshot',{})
save()
for n in range(90):
 if state().get('phase')=='running':result['running_observed']=True;break
 time.sleep(2)
if not result['running_observed']:save();raise SystemExit(1)
result['state_root_mode']=oct(pathlib.Path('/var/lib/pokrov').stat().st_mode & 0o777)
result['profile_directory_mode']=oct(pathlib.Path('/var/lib/pokrov/profiles').stat().st_mode & 0o777)
result['ui_uid']=subprocess.check_output(['ps','-C','pokrov','-o','uid='],text=True).strip()
config=json.loads(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').read_text())
direct_tags={x.get('tag') for x in config.get('outbounds',[]) if x.get('type')=='direct'}
result['ru_direct_rules']=sum(x.get('outbound') in direct_tags and any('ru' in str(t).lower() for t in (x.get('rule_set',[]) if isinstance(x.get('rule_set',[]),list) else [x.get('rule_set')])) for x in config.get('route',{}).get('rules',[]))
result['api_metadata_absent']='_meta' not in config
result['ipv6_tun_address_present']=any(':' in a for x in config.get('inbounds',[]) if x.get('type')=='tun' for a in x.get('address',[]));config=None
save()
probes={}
for key,url in [('app','https://app.pokrov.space/'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe')]:
 p=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{http_code}',url],capture_output=True,text=True)
 probes[key]={'curl_exit':p.returncode,'http_code':p.stdout[-3:]}
try:
 with socket.create_connection((target,443),timeout=12) as c:
  probes['owned_ru_tcp']={'connected':True,'port':443,'sample_window_seconds':8,'samples':0,'core_direct_socket':False,'core_any_socket':False}
  deadline=time.monotonic()+8
  while time.monotonic()<deadline:
   p=subprocess.run(['ss','-H','-n','-t','-p','dst',target,'dport','=',':443'],capture_output=True,text=True)
   probes['owned_ru_tcp']['ss_exit_code']=p.returncode
   probes['owned_ru_tcp']['samples']+=1
   probes['owned_ru_tcp']['core_any_socket'] |= '"pokrov-core"' in p.stdout
   probes['owned_ru_tcp']['core_direct_socket'] |= any('"pokrov-core"' in line and line.startswith('ESTAB') for line in p.stdout.splitlines())
   time.sleep(.1)
except OSError as error:probes['owned_ru_tcp']={'connected':False,'error_class':type(error).__name__}
p=subprocess.run(['ip','-6','route','get','2001:db8::1'],capture_output=True);probes['ipv6_documentation_destination_route_rejected']=p.returncode!=0
rules=json.loads(subprocess.check_output(['ip','-N','-j','-6','route','show','table','all'],text=True));probes['ipv6_owned_reject_route']=any(str(x.get('table'))=='20555' and str(x.get('protocol'))=='243' and str(x.get('type'))=='7' and x.get('dev')=='lo' and x.get('metric')==42700 for x in rules)
p=subprocess.run(['getent','ahostsv4','app.pokrov.space'],capture_output=True)
probes['system_dns']={'exit_code':p.returncode,'answer_present':bool(p.stdout.strip())}
result['probes']=probes;result['finished_epoch']=time.time();save()
