import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate7-live-recovery.json';assert not out.exists()
result={'candidate_sha256':'5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d','authorization':'root peer credential in isolated recovery harness; GUI polkit tested separately','profile_source':'unchanged retained profile from successful package7b connected uninstall; no API refresh','started_epoch':time.time(),'steps':[]}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def call(action):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-recovery7-'+action,'action':action,'payload':{}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
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
def traffic(label):
 attempts=[]
 for _ in range(3):
  p=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{http_code}','https://app.pokrov.space/api/public/authenticated-egress-probe'],capture_output=True,text=True);attempts.append({'curl_exit':p.returncode,'http_code':p.stdout[-3:]})
 result[label]=attempts;save()
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json');profile_before=hashlib.sha256(profile.read_bytes()).hexdigest()
for name,sha in {'pokrov-linuxd':'2236009c4815b632c176dfeafcc7bc7c8bc090a0a819ea9a58bcd7ad2688b983','pokrov-core':'979e8d77a8d41237a490ada5b129ff0b8f8a7a5cf4d754b1651196a5118aa8ce'}.items():assert hashlib.sha256((pathlib.Path('/usr/lib/pokrov')/name).read_bytes()).hexdigest()==sha
assert absent();before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before'];save();time.sleep(3)
foreign=['ip','-4','rule','add','priority','20555','to','198.18.99.0/24','table','main','protocol','99'];fault=['ip','-4','rule','add','priority','20555','to','198.18.98.0/24','table','20555','protocol','243'];foreign_added=fault_added=False
try:
 assert call('connect')['ok'];assert pathlib.Path('/sys/class/net/pokrov0').exists();traffic('fixed_profile_initial_http')
 assert call('disconnect')['ok'];wait_clean();assert network()==before;result['normal_restore']='PASS';save()
 assert call('connect')['ok'];run(foreign);foreign_added=True;assert call('disconnect')['ok'];wait_clean()
 rules=json.loads(run(['ip','-N','-j','-4','rule']));assert any(x.get('dst')=='198.18.99.0' and str(x.get('protocol'))=='99' for x in rules)
 delete=foreign.copy();delete[3]='del';run(delete);foreign_added=False;assert network()==before;result['foreign_rule_preserved']='PASS';save()
 assert call('connect')['ok'];run(fault);fault_added=True;assert not call('disconnect')['ok'];assert not absent();assert pathlib.Path('/var/lib/pokrov/network-recovery.json').exists();assert not call('invalidate_profile')['ok']
 tables=json.loads(run(['nft','-j','list','tables']));assert any(x.get('table',{}).get('name')=='pokrov' for x in tables['nftables']);result['partial_rollback_retains_journal_filter_and_profile']='PASS';save()
 delete=fault.copy();delete[3]='del';run(delete);fault_added=False;assert call('disconnect')['ok'];wait_clean();assert network()==before;result['partial_rollback_retry']='PASS';save()
 assert call('connect')['ok'];pid=int(run(['pgrep','-x','pokrov-core']).strip());assert pathlib.Path('/proc',str(pid),'exe').resolve()==pathlib.Path('/usr/lib/pokrov/pokrov-core');os.kill(pid,signal.SIGKILL);wait_clean();assert network()==before
 snap=call('status')['snapshot'];assert snap['phase']!='running' and snap['last_stop_reason']=='runtime_error';result['core_sigkill_restore']='PASS';save()
 assert call('connect')['ok'];run(['systemctl','kill','--kill-whom=main','--signal=SIGKILL','pokrov-linuxd.service']);wait_clean()
 for _ in range(40):
  if subprocess.run(['systemctl','is-active','--quiet','pokrov-linuxd.service'],capture_output=True).returncode==0:break
  time.sleep(.25)
 assert call('initialize')['ok'];assert network()==before;assert call('connect')['ok'];traffic('fixed_profile_after_daemon_restart_http');assert call('disconnect')['ok'];wait_clean();assert network()==before;result['daemon_sigkill_restart_restore']='PASS'
 result['profile_bytes_unchanged']=hashlib.sha256(profile.read_bytes()).hexdigest()==profile_before;assert result['profile_bytes_unchanged'];result['status']='PASS_CURRENT_PACKAGE_RECOVERY'
except Exception as e:result['status']='FAIL';result['failure_class']=type(e).__name__
finally:
 for added,rule in [(fault_added,fault),(foreign_added,foreign)]:
  if added:
   delete=rule.copy();delete[3]='del';subprocess.run(delete,capture_output=True)
 try:call('disconnect')
 except Exception:result['final_disconnect_failed']=True
 result['final_network_matches_baseline']={k:v==network()[k] for k,v in before.items()};result['finished_epoch']=time.time();save()
print(json.dumps({k:v for k,v in result.items() if k!='steps'},indent=2));assert result['status'].startswith('PASS')
