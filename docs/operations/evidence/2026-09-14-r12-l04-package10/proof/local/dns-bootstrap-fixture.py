from pathlib import Path
import json,socket,subprocess,time,hashlib,os
r=Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate9-bootstrap-fixture.json';assert not out.exists()
profile=Path('/var/lib/pokrov/profiles/active-profile.json');original=profile.read_bytes()
assert not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists()
backup=r/'private-bootstrap-fixture-original.json';assert not backup.exists();backup.write_bytes(original);backup.chmod(0o600)
result={'scope':'isolated root IPC diagnostic, not GUI acceptance','started_epoch':time.time(),'original_sha256':hashlib.sha256(original).hexdigest(),'steps':[]}
def save():out.write_text(json.dumps(result));out.chmod(0o644)
def call(action,payload=None):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(60);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-bootstrap-fixture-'+action,'action':action,'payload':payload or {}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
 result['steps'].append({'action':action,'ok':v.get('ok'),'snapshot':v.get('snapshot')});save();assert v.get('ok');return v
def stage(raw):return call('stage_profile',{'profile_name':'l04-bootstrap-fixture','config_payload':raw.decode(),'route_mode':'allExceptRu','core_egress_probe_required':True})
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
def network():return {k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()}
before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before']
clone=json.loads(original);servers=clone['dns']['servers'];direct=servers[3];assert direct['tag']=='dns-direct' and direct['detour']==next(x['tag'] for x in clone['outbounds'] if x['type']=='direct')
clone['route']['default_domain_resolver']={'server':direct['tag'],'strategy':'ipv4_only'}
fixture=json.dumps(clone).encode();result['fixture_sha256']=hashlib.sha256(fixture).hexdigest();save()
try:
 stage(fixture);started=time.time();result['connect']=call('connect').get('snapshot');result['connect_seconds']=time.time()-started
 p=subprocess.run([str(r/'dns-diagnostic')],capture_output=True,text=True,timeout=20);result['dns']=json.loads(p.stdout);save()
 result['https']=[]
 for target,url,code in [('app','https://app.pokrov.space/','200'),('api-marker','https://api.pokrov.space/api/public/authenticated-egress-probe','204')]:
  p=subprocess.run(['curl','-4','-sS','--max-time','15','-o','/dev/null','-w','%{http_code}',url],capture_output=True,text=True);result['https'].append({'target':target,'exit':p.returncode,'code':p.stdout[-3:],'pass':p.returncode==0 and p.stdout[-3:]==code})
 result['status']='COMPLETE'
except Exception as e:result['status']='FAIL';result['failure_class']=type(e).__name__
finally:
 try:call('disconnect');stage(original);result['original_restored']=profile.read_bytes()==original
 except Exception as e:result['restoration_failure']=type(e).__name__
 result['network_restored']=network()==before;result['finished_epoch']=time.time();save()
