import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate7-sleep.json';assert not out.exists()
result={'candidate_sha256':'5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d','authorization':'root peer credential in isolated recovery harness; GUI polkit tested separately','profile_source':'unchanged retained profile from successful package7b connected uninstall; no API refresh','started_epoch':time.time(),'steps':[]}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def call(action):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-sleep7-'+action,'action':action,'payload':{}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
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

result['network_before']=before
result['boot_id_before']=pathlib.Path('/proc/sys/kernel/random/boot_id').read_text().strip();save()
try:
 assert call('connect')['ok'];traffic('before_sleep_http')
 result['connected_before_sleep']=pathlib.Path('/sys/class/net/pokrov0').exists();assert result['connected_before_sleep'];save()
 subprocess.run(['systemctl','suspend'],check=True,capture_output=True,timeout=75)
 wait_clean()
 started=time.monotonic()
 for _ in range(60):
  current=network()
  if current==before:break
  time.sleep(.5)
 result['resume_settle_seconds']=round(time.monotonic()-started,2)
 result['after_resume_matches']={k:current[k]==v for k,v in before.items()};save();assert current==before
 result['same_boot']=pathlib.Path('/proc/sys/kernel/random/boot_id').read_text().strip()==result['boot_id_before'];assert result['same_boot']
 assert call('initialize')['ok'];assert call('connect')['ok'];traffic('after_resume_http');assert call('disconnect')['ok'];wait_clean();assert network()==before
 result['profile_bytes_unchanged']=hashlib.sha256(profile.read_bytes()).hexdigest()==profile_before;assert result['profile_bytes_unchanged']
 result['status']='PASS_CURRENT_PACKAGE_SUSPEND_RESUME'
except Exception as e:result['status']='FAIL';result['failure_class']=type(e).__name__
finally:
 try:call('disconnect')
 except Exception:result['final_disconnect_failed']=True
 current=network();result['final_network_matches_baseline']={k:v==current[k] for k,v in before.items()};result['finished_epoch']=time.time();save()
print(json.dumps({k:v for k,v in result.items() if k!='steps'},indent=2));assert result['status'].startswith('PASS')
