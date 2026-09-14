import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate7-tls-path-comparison.json';assert not out.exists()
result={'candidate_sha256':'5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d','authorization':'root peer credential in isolated recovery harness; GUI polkit tested separately','profile_source':'unchanged retained profile from successful package7b connected uninstall; no API refresh','started_epoch':time.time(),'steps':[]}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
def call(action,payload=None):
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l04-tls-path7-'+action,'action':action,'payload':payload or {}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
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
assert absent();before=network();assert before==json.loads((r/'clean-install.json').read_text())['network_before'];save();time.sleep(3)

original=profile.read_bytes();config=json.loads(original);outbounds=config['outbounds'];by={x['tag']:i for i,x in enumerate(outbounds)};final=config['route']['final'];choices=[]
def visit(tag,path):
 item=outbounds[by[tag]]
 if item.get('type')=='selector':
  for target in item['outbounds']:visit(target,path+[(tag,target)])
 elif item.get('type')=='vless' and not item.get('detour'):
  if not any(x['server']==item['server'] for x in choices):choices.append({'index':by[tag],'server':item['server'],'path':path})
visit(final,[]);assert len(choices)>=2;choices=choices[:2]+[choices[-1]] if len(choices)>2 else choices
result['network_before']=before;result['observations']=[];result['profile_source']='existing GUI profile; only existing selector defaults changed per isolated comparison; original bytes restored finally';save()
def probe(label,selected=None):
 observation={'label':label,'requests':[]}
 if selected:
  item=outbounds[selected['index']];observation.update({'outbound_index':selected['index'],'selector_path':[[by[a],by[b]] for a,b in selected['path']],'server_sha256':hashlib.sha256(item['server'].encode()).hexdigest(),'sni_sha256':hashlib.sha256(item.get('tls',{}).get('server_name','').encode()).hexdigest(),'server_port':item.get('server_port'),'utls_fingerprint':item.get('tls',{}).get('utls',{}).get('fingerprint')})
 for attempt in range(3):
  for target,url in [('app','https://app.pokrov.space/'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe')]:
   started=time.monotonic();p=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{json}',url],capture_output=True,text=True)
   try:v=json.loads(p.stdout)
   except ValueError:v={}
   observation['requests'].append({'attempt':attempt+1,'target':target,'curl_exit':p.returncode,'http_code':v.get('http_code'),'seconds':round(time.monotonic()-started,2),'peer_sha256':hashlib.sha256(v.get('remote_ip','').encode()).hexdigest(),'ssl_verify_result':v.get('ssl_verify_result'),'error_kinds':[k for k in ['SSL_ERROR_SYSCALL','Connection reset by peer','unexpected eof','wrong version number','certificate','timed out','Could not resolve host','Failed to connect'] if k.lower() in p.stderr.lower()]})
 result['observations'].append(observation);save()
def stage(raw):return call('stage_profile',{'profile_name':'l04-tls-path-comparison','config_payload':raw.decode(),'route_mode':'fullTunnel','core_egress_probe_required':False})
try:
 probe('no_vpn_control')
 for selected in choices:
  clone=json.loads(original)
  for group,target in selected['path']:clone['outbounds'][by[group]]['default']=target
  assert stage(json.dumps(clone).encode())['ok'];assert call('connect')['ok'];probe('selected_existing_path',selected);assert call('disconnect')['ok'];wait_clean();assert network()==before
 result['status']='COMPARISON_COMPLETE'
except Exception as e:result['status']='HARNESS_FAIL';result['failure_class']=type(e).__name__
finally:
 try:
  assert call('disconnect')['ok'];wait_clean();assert stage(original)['ok'];result['original_profile_restored']=profile.read_bytes()==original
 except Exception:result['restoration_failed']=True
 current=network();result['final_network_matches_baseline']={k:v==current[k] for k,v in before.items()};result['finished_epoch']=time.time();save()
print(json.dumps({'status':result['status'],'profiles_compared':len(choices),'original_profile_restored':result.get('original_profile_restored')}));assert result['status']=='COMPARISON_COMPLETE' and result['original_profile_restored']
