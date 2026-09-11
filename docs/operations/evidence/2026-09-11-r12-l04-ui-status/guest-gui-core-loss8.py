import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-gui-core-loss.json';assert not out.exists()
result={'candidate_sha256':'b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933','authorization':'actual non-root GUI connect and production polkit; root observer injects exact Core SIGKILL only','profile_source':'unchanged retained profile from successful package7b connected uninstall; no API refresh','started_epoch':time.time(),'steps':[]}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def call(action):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-gui-tls01-'+action,'action':action,'payload':{}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
 if action=='status':return v
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
assert absent();before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before'];assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-8';save();time.sleep(3)

result['profile_source']='new profile supplied by actual GUI connect; observer does not stage or edit it';save()
try:
 for _ in range(180):
  snap=call('status').get('snapshot',{})
  if snap.get('phase')=='running':break
  time.sleep(1)
 assert snap.get('phase')=='running';config=json.loads(profile.read_bytes());outbounds=config['outbounds'];by={x['tag']:i for i,x in enumerate(outbounds)}
 path=[];tag=config['route']['final']
 while outbounds[by[tag]].get('type')=='selector':
  item=outbounds[by[tag]];target=item.get('default') or item['outbounds'][0];path.append([by[tag],by[target]]);tag=target
 selected=outbounds[by[tag]];result['selected_path']={'leaf_index':by[tag],'selector_path':path,'type':selected.get('type'),'server_sha256':hashlib.sha256(selected.get('server','').encode()).hexdigest(),'sni_sha256':hashlib.sha256(selected.get('tls',{}).get('server_name','').encode()).hexdigest(),'utls_fingerprint':selected.get('tls',{}).get('utls',{}).get('fingerprint'),'detour_index':by.get(selected.get('detour'))};result['requests']=[];save()
 for attempt in range(3):
  for target,url in [('app','https://app.pokrov.space/'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe')]:
   started=time.monotonic();q=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{json}',url],capture_output=True,text=True)
   try:v=json.loads(q.stdout)
   except ValueError:v={}
   result['requests'].append({'attempt':attempt+1,'target':target,'curl_exit':q.returncode,'http_code':v.get('http_code'),'seconds':round(time.monotonic()-started,2),'peer_sha256':hashlib.sha256(v.get('remote_ip','').encode()).hexdigest(),'ssl_verify_result':v.get('ssl_verify_result'),'error_kinds':[k for k in ['SSL_ERROR_SYSCALL','Connection reset by peer','unexpected eof','wrong version number','certificate','timed out','Could not resolve host','Failed to connect'] if k.lower() in q.stderr.lower()]});save()
 result['phase']='AWAITING_OBSERVED_CONNECTED_SCREENSHOT';save()
 trigger=r/'candidate8-core-kill.trigger'
 for _ in range(180):
  if trigger.exists():break
  time.sleep(1)
 assert trigger.exists()
 pids=subprocess.check_output(['pgrep','-x','pokrov-core'],text=True).split();assert len(pids)==1
 pid=int(pids[0]);exe=pathlib.Path('/proc')/str(pid)/'exe';assert exe.resolve()==pathlib.Path('/usr/lib/pokrov/pokrov-core')
 assert hashlib.sha256(exe.read_bytes()).hexdigest()=='979e8d77a8d41237a490ada5b129ff0b8f8a7a5cf4d754b1651196a5118aa8ce'
 result['injection']={'signal':'SIGKILL','target':'exact installed Core process','pid':pid,'epoch':time.time()};save();os.kill(pid,signal.SIGKILL);wait_clean()
 snap=call('status').get('snapshot',{});result['after_core_loss']={k:snap.get(k) for k in ('phase','last_stop_reason','host_health','dns_state','uplink_state')}
 assert snap.get('phase')!='running' and snap.get('last_stop_reason')=='runtime_error'
 result['gui_processes']=[{'pid':int(x),'uid':(pathlib.Path('/proc')/x).stat().st_uid} for x in subprocess.check_output(['pgrep','-x','pokrov'],text=True).split()]
 result['status']='PASS_NATIVE_CORE_LOSS_RESTORE_GUI_VISUAL_PENDING'
except Exception as e:result['status']='HARNESS_FAIL';result['failure_class']=type(e).__name__
finally:
 try:assert call('disconnect')['ok'];wait_clean()
 except Exception:result['disconnect_failed']=True
 current=network();result['final_network_matches_baseline']={k:v==current[k] for k,v in before.items()};result['finished_epoch']=time.time();save()
print(json.dumps({'status':result['status'],'requests':len(result.get('requests',[]))}));assert result['status']=='PASS_NATIVE_CORE_LOSS_RESTORE_GUI_VISUAL_PENDING'
