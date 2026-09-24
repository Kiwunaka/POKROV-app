import hashlib,json,os,pathlib,platform,socket,subprocess,time,ast
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate10-gui-core-recovery.json';assert not out.exists()
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json')
result={'status':'WAITING_FOR_GUI','started_epoch':time.time(),'candidate_sha256':'d4c3ead8786cfdd91ff7851e3634d7025e899323db13636803f3064551628f17','control':'unmodified installed GUI and production polkit; observer uses read-only status only','steps':[]}
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

import signal
pid=int(subprocess.check_output(['pgrep','-x','pokrov'],text=True));gui=pathlib.Path('/proc',str(pid));assert gui.stat().st_uid==1000
result['gui']={'pid':pid,'uid':1000,'cgroup':(gui/'cgroup').read_text().strip()};save()
def wait_running():
 for _ in range(300):
  snap=snapshot()
  if snap['phase']=='running':return snap
  time.sleep(1)
 raise TimeoutError('GUI reconnect deadline')
try:
 first=wait_running();result['first_connected']=first;result['status']='WAITING_BEFORE_CORE_FAULT';save()
 p=subprocess.run(['curl','-4','-sS','--max-time','15','-o','/dev/null','-w','%{http_code}','https://api.pokrov.space/api/public/authenticated-egress-probe'],capture_output=True,text=True)
 result['reinstalled_https']={'exit':p.returncode,'code':p.stdout[-3:]};assert p.returncode==0 and p.stdout[-3:]=='204';assert first['dns_ready'] and first['core_egress_validated'];save()
 time.sleep(20)
 core=int(subprocess.check_output(['pgrep','-x','pokrov-core'],text=True));assert pathlib.Path('/proc',str(core),'exe').resolve()==pathlib.Path('/usr/lib/pokrov/pokrov-core');os.kill(core,signal.SIGKILL)
 for _ in range(120):
  if not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists():break
  time.sleep(.25)
 snap=snapshot();result['after_core_sigkill']=snap;result['network_restored_after_fault']=network()==before;result['gui_survived']=gui.exists()
 assert snap['phase']!='running' and snap['last_stop_reason']=='runtime_error' and snap['dns_ready'] is None and snap['core_egress_validated'] is None and result['network_restored_after_fault'] and result['gui_survived']
 result['status']='WAITING_FOR_GUI_RECONNECT';save()
 second=wait_running();result['second_connected']=second;assert second['dns_ready'] and second['core_egress_validated'];result['status']='WAITING_FOR_GUI_DISCONNECT';save()
 for _ in range(300):
  snap=snapshot()
  if snap['phase']!='running' and not pathlib.Path('/sys/class/net/pokrov0').exists():break
  time.sleep(1)
 result['final_network_restored']=network()==before;result['final_snapshot']=snapshot();assert result['final_network_restored'] and result['final_snapshot']['dns_ready'] is None and result['final_snapshot']['core_egress_validated'] is None
 result['status']='PASS_GUI_REINSTALLED_CORE_RECOVERY'
except Exception as e:result['status']='FAIL';result['failure_class']=type(e).__name__
finally:result['finished_epoch']=time.time();save()
