import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-modes-20260913.json';assert not out.exists()
result={'candidate_sha256':'b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933','authorization':'root peer credential in isolated recovery harness; GUI polkit tested separately','profile_source':'existing profile; isolated runtime fixtures use its retained RU rule sets and restore original bytes; not a GUI mode-selection proof','started_epoch':time.time(),'steps':[]}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def call(action,payload=None):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-de-recheck8-sep13-'+action,'action':action,'payload':payload or {}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
 snap=v.get('snapshot',{});result['steps'].append({'action':action,'ok':v.get('ok'),'phase':snap.get('phase'),'last_stop_reason':snap.get('last_stop_reason'),'host_health':snap.get('host_health'),'dns_state':snap.get('dns_state'),'uplink_state':snap.get('uplink_state')});save();return v
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
def network():
 hashes={}
 for name,args in commands.items():
  p=subprocess.run(args,capture_output=True);assert p.returncode==0;hashes[name]=hashlib.sha256(p.stdout).hexdigest()
 return hashes
def absent():return not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
def wait_clean():
 for _ in range(120):
  if absent():return
  time.sleep(.25)
 raise AssertionError('recovery_incomplete')
def run(args):return subprocess.check_output(args,timeout=35)
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json');profile_before=hashlib.sha256(profile.read_bytes()).hexdigest()
for name,sha in {'pokrov-linuxd':'2236009c4815b632c176dfeafcc7bc7c8bc090a0a819ea9a58bcd7ad2688b983','pokrov-core':'979e8d77a8d41237a490ada5b129ff0b8f8a7a5cf4d754b1651196a5118aa8ce'}.items():assert hashlib.sha256((pathlib.Path('/usr/lib/pokrov')/name).read_bytes()).hexdigest()==sha
import io,tarfile,stat
pdeb=r/'pokrov_1.2.0~beta.30-8_amd64.deb'
assert hashlib.sha256(pdeb.read_bytes()).hexdigest()==result['candidate_sha256']
gpg=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(pdeb)+'.asc',str(pdeb)],capture_output=True,text=True)
assert gpg.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in gpg.stdout
count=0
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(pdeb)]))) as tar:
 for e in tar:
  if not e.isfile() and not e.issym():continue
  p=pathlib.Path('/')/e.name.removeprefix('./');st=p.lstat();assert st.st_uid==0 and st.st_gid==0
  if e.issym():assert p.is_symlink() and os.readlink(p)==e.linkname
  else:assert not p.is_symlink() and hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256(tar.extractfile(e).read()).digest() and stat.S_IMODE(st.st_mode)==e.mode
  count+=1
assert count==302
result.update(signature_verified=True,checked_payload_entries=count)

assert absent();before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before'];save();time.sleep(3)

import ast
original=profile.read_bytes();config=json.loads(original);by={x['tag']:i for i,x in enumerate(config['outbounds'])}
assert hashlib.sha256(config['outbounds'][0]['server'].encode()).hexdigest()=='3d297432f8ce6dbcac91f560a4a7de1deb28bfb64f691de605a645eb4bb8339e'
# The target was retained privately by the original owned-RU observer.
tree=ast.parse((r/'private-route7-443-sampled-ru.py').read_text());target=None
for n in tree.body:
 if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='target' for t in n.targets):target=ast.literal_eval(n.value)
assert isinstance(target,str)
direct=[x['tag'] for x in config['outbounds'] if x.get('type')=='direct'];assert len(direct)==1
sets=[x['tag'] for x in config['route']['rule_set'] if 'ru' in x['tag'].lower()];assert sets
result.update(ru_target_sha256=hashlib.sha256(target.encode()).hexdigest(),fixture_ru_rule_set_count=len(sets),modes=[])

def stage(raw,mode='fullTunnel'):
 return call('stage_profile',{'profile_name':'l04-modes-sep13','config_payload':raw.decode(),'route_mode':mode,'core_egress_probe_required':False})

def selected_default(clone):
 # Keep selector-chain shape; choose the already-tested default DE transport.
 out=clone['outbounds'];final=clone['route']['final']
 def visit(tag):
  x=out[by[tag]]
  if x.get('type')!='selector':return tag==out[0]['tag']
  for t in x['outbounds']:
   if visit(t):x['default']=t;return True
  return False
 assert visit(final)

try:
 for mode in ['fullTunnel','allExceptRu']:
  clone=json.loads(original);selected_default(clone)
  if mode=='allExceptRu':
   assert not any(x.get('outbound')==direct[0] and any(t in sets for t in x.get('rule_set',[])) for x in clone['route']['rules'])
   clone['route']['rules'].insert(2,{'rule_set':sets,'outbound':direct[0]})
  assert stage(json.dumps(clone).encode(),mode)['ok'];assert call('connect')['ok']
  row={'mode':mode,'authorization':'root fixture IPC','http':[]};result['modes'].append(row);save()
  for label,url,expected in [('app','https://app.pokrov.space/','200'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe','204')]:
   p=subprocess.run(['curl','-4','--silent','--show-error','--max-time','15','--output','/dev/null','--write-out','%{http_code}',url],capture_output=True,text=True)
   row['http'].append({'target':label,'exit':p.returncode,'code':p.stdout[-3:],'pass':p.returncode==0 and p.stdout[-3:]==expected})
  row['ru_tcp']={'connected':False,'core_direct_socket':False,'samples':0}
  try:
   with socket.create_connection((target,443),timeout=12):
    row['ru_tcp']['connected']=True;end=time.monotonic()+4
    while time.monotonic()<end:
     p=subprocess.run(['ss','-H','-n','-t','-p','dst',target,'dport','=',':443'],capture_output=True,text=True);assert p.returncode==0
     row['ru_tcp']['core_direct_socket']|=any('"pokrov-core"' in line and line.startswith('ESTAB') for line in p.stdout.splitlines());row['ru_tcp']['samples']+=1;time.sleep(.1)
  except OSError as e:row['ru_tcp']['failure_class']=type(e).__name__
  row['ipv6_documentation_route_rejected']=subprocess.run(['ip','-6','route','get','2001:db8::1'],capture_output=True).returncode!=0
  routes=json.loads(subprocess.check_output(['ip','-N','-j','-6','route','show','table','all'],text=True))
  row['ipv6_owned_reject_route']=any(str(x.get('table'))=='20555' and str(x.get('protocol'))=='243' and str(x.get('type'))=='7' and x.get('dev')=='lo' and x.get('metric')==42700 for x in routes)
  p=subprocess.run(['getent','ahostsv4','app.pokrov.space'],capture_output=True);row['system_dns']=p.returncode==0 and bool(p.stdout.strip())
  row['pass']=all(x['pass'] for x in row['http']) and row['system_dns'] and row['ipv6_documentation_route_rejected'] and row['ipv6_owned_reject_route'] and row['ru_tcp']['connected'] and row['ru_tcp']['core_direct_socket']==(mode=='allExceptRu');save()
  assert call('disconnect')['ok'];wait_clean();row['network_restored']=network()==before;save();assert row['network_restored']
 result['status']='PASS_RUNTIME_FIXTURES' if all(x['pass'] for x in result['modes']) else 'FAIL_RUNTIME_FIXTURES'
except Exception as e:result['status']='HARNESS_FAIL';result['failure_class']=type(e).__name__
finally:
 try:
  assert call('disconnect')['ok'];wait_clean();assert stage(original)['ok'];result['original_profile_restored']=profile.read_bytes()==original
 except Exception:result['restoration_failed']=True
 current=network();result['final_network_matches_baseline']={k:v==current[k] for k,v in before.items()};result['finished_epoch']=time.time();save()
assert result['original_profile_restored'] and all(result['final_network_matches_baseline'].values())
