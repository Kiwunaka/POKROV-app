from pathlib import Path
import json,socket,subprocess,time,hashlib,os
r=Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate10-route-packets-all.json';assert not out.exists()
profile=Path('/var/lib/pokrov/profiles/active-profile.json');original=profile.read_bytes()
assert not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists()
backup=r/'private-route-packets-all-original.json';assert not backup.exists();backup.write_bytes(original);backup.chmod(0o600)
result={'scope':'isolated root IPC diagnostic, not GUI acceptance','started_epoch':time.time(),'original_sha256':hashlib.sha256(original).hexdigest(),'steps':[]}
def save():out.write_text(json.dumps(result));out.chmod(0o644)
def call(action,payload=None):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(60);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-bootstrap-fixture-'+action,'action':action,'payload':payload or {}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
 result['steps'].append({'action':action,'ok':v.get('ok'),'snapshot':v.get('snapshot')});save();assert v.get('ok');return v
def stage(raw,mode='allExceptRu'):return call('stage_profile',{'profile_name':'l04-route-diagnostic','config_payload':raw.decode(),'route_mode':mode,'core_egress_probe_required':True})
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
def network():return {k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()}
before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before']

import ast
nodes=ast.parse((r/'private-route7-443-sampled-ru.py').read_text()).body
target=next(ast.literal_eval(n.value) for n in nodes if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='target' for t in n.targets))
interface=json.loads(subprocess.check_output(['ip','-j','-4','route','show','default'],text=True))[0]['dev']
result['target_sha256']=hashlib.sha256(target.encode()).hexdigest();result['target_port']=80;result['modes']=[]
try:
 for mode in ['fullTunnel','allExceptRu']:
  raw=(r/('private-gui-route10b-'+mode+'-20260914.json')).read_bytes();stage(raw,mode)
  row={'mode':mode,'exact_gui_profile_sha256':hashlib.sha256(raw).hexdigest()};result['modes'].append(row)
  started=time.time();row['connect']=call('connect').get('snapshot');row['connect_seconds']=time.time()-started
  p=subprocess.run([str(r/'dns-diagnostic')],capture_output=True,text=True,timeout=25);row['dns']=json.loads(p.stdout)
  def sockets():
   p=subprocess.run(['ss','-H','-n','-t','-p','dst',target,'dport','=',':80'],capture_output=True,text=True,check=True)
   return {line for line in p.stdout.splitlines() if '"pokrov-core"' in line and line.startswith('ESTAB')}
  row['ru_tcp']={'connected':False,'physical_direct_syn_packets':0,'port_excludes_all_profile_proxy_endpoints':all(o.get('server_port')!=80 for o in json.loads(raw)['outbounds'])}
  with socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(0x0003)) as capture:
   capture.bind((interface,0));capture.settimeout(.1)
   try:
    with socket.create_connection((target,80),timeout=12):
     row['ru_tcp']['connected']=True;end=time.monotonic()+3
     while time.monotonic()<end:
      try:packet=capture.recv(2048)
      except socket.timeout:continue
      if len(packet)<54 or packet[12:14]!=b'\x08\x00' or packet[23]!=6 or packet[30:34]!=socket.inet_aton(target):continue
      tcp=14+(packet[14]&15)*4
      if int.from_bytes(packet[tcp+2:tcp+4],'big')==80 and packet[tcp+13]&2:row['ru_tcp']['physical_direct_syn_packets']+=1
   except OSError as e:row['ru_tcp']['failure_class']=type(e).__name__
  row['route_pass']=row['ru_tcp']['connected'] and (row['ru_tcp']['physical_direct_syn_packets']>0)==(mode=='allExceptRu')
  call('disconnect');row['network_restored']=network()==before;save()
 result['status']='COMPLETE'
except Exception as e:result['status']='FAIL';result['failure_class']=type(e).__name__
finally:
 try:call('disconnect');stage(original);result['original_restored']=profile.read_bytes()==original
 except Exception as e:result['restoration_failure']=type(e).__name__
 result['network_restored']=network()==before;result['finished_epoch']=time.time();save()
