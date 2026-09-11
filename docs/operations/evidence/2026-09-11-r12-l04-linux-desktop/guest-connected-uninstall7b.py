import hashlib,json,os,pathlib,platform,signal,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate7b-connected-uninstall.json';assert not out.exists()
def state():
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(5);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall(b'{"protocol":"pokrov-linuxd-v1","request_id":"l04-uninstall7","action":"status","payload":{}}\n');return json.loads(s.makefile('rb').readline(65537)).get('snapshot',{})
result={'operation':'connected_uninstall_and_purge','source_version':'1.2.0~beta.30-7','started_epoch':time.time(),'running_observed':False}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
save()
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)==result['source_version']
for _ in range(90):
 if state().get('phase')=='running':result['running_observed']=True;break
 time.sleep(2)
save();assert result['running_observed']
time.sleep(5)
result['post_upgrade_full_mode_http_probes']=[]
config=json.loads(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').read_text())
result['selected_transport_server_sha256']=hashlib.sha256(config['outbounds'][0].get('server','').encode()).hexdigest()
result['selected_tls_sni_sha256']=hashlib.sha256(config['outbounds'][0].get('tls',{}).get('server_name','').encode()).hexdigest()
result['selected_utls_fingerprint']=config['outbounds'][0].get('tls',{}).get('utls',{}).get('fingerprint')
direct={x.get('tag') for x in config.get('outbounds',[]) if x.get('type')=='direct'}
result['post_upgrade_ru_direct_rules']=sum(x.get('outbound') in direct and any('ru' in str(t).lower() for t in (x.get('rule_set',[]) if isinstance(x.get('rule_set',[]),list) else [x.get('rule_set')])) for x in config.get('route',{}).get('rules',[]));config=None
for attempt in range(3):
 for label,url,expected in [('app','https://app.pokrov.space/','200'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe','204')]:
  probe=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{http_code}',url],capture_output=True,text=True)
  result['post_upgrade_full_mode_http_probes'].append({'attempt':attempt+1,'target':label,'curl_exit':probe.returncode,'http_code':probe.stdout[-3:],'expected':expected,'pass':probe.returncode==0 and probe.stdout[-3:]==expected})
 time.sleep(1)
q=subprocess.run(['getent','ahostsv4','app.pokrov.space'],capture_output=True);result['post_upgrade_system_dns']=q.returncode==0 and bool(q.stdout.strip())
save();assert result['post_upgrade_ru_direct_rules']==0 and all(x['pass'] for x in result['post_upgrade_full_mode_http_probes']) and result['post_upgrade_system_dns']
pids=subprocess.check_output(['pgrep','-x','pokrov'],text=True).split();assert len(pids)==1
pid=int(pids[0]);proc=pathlib.Path('/proc')/str(pid);assert (proc/'exe').resolve()==pathlib.Path('/usr/lib/pokrov/ui/pokrov');assert (proc/'status').read_text().split('Uid:\t',1)[1].splitlines()[0].split()[0]=='1000'
os.kill(pid,signal.SIGTERM)
for _ in range(30):
 if not proc.exists():break
 time.sleep(.1)
assert not proc.exists();result['nonroot_ui_exited_for_uninstall']=True
assert state().get('phase')=='running';result['runtime_running_with_ui_closed']=True
roots={'profile':pathlib.Path('/var/lib/pokrov/profiles'),'settings':pathlib.Path('/home/pokrovqa/.local/share/space.pokrov.linux'),'keyring':pathlib.Path('/home/pokrovqa/.local/share/keyrings')}
def snapshot():return {name:{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()} for name,root in roots.items()}
before=snapshot();assert all(before.values());result['state_file_counts_before']={k:len(v) for k,v in before.items()}
deb=r/'pokrov_1.2.0~beta.30-7_amd64.deb';sha=hashlib.sha256(deb.read_bytes()).hexdigest();assert sha=='5fadf99660301b7456e8e0b133b90921b807b992fc58fb27af92183ebc81154d'
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
result['candidate_sha256']=sha;result['signature_verified']=True;save()
with (r/'candidate7b-connected-uninstall.log').open('w') as log:
 p=subprocess.run(['apt-get','-y','purge','pokrov'],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive','NEEDRESTART_MODE':'l'},stdout=log,stderr=subprocess.STDOUT)
after=snapshot();result.update({'apt_exit_code':p.returncode,'package_installed':subprocess.run(['dpkg-query','-W','-f=${db:Status-Status}','pokrov'],capture_output=True,text=True).stdout.strip()=='installed','state_unchanged':{k:v==after[k] for k,v in before.items()},'socket_enabled':subprocess.run(['systemctl','is-enabled','--quiet','pokrov-linuxd.socket']).returncode==0,'state_root_mode':oct(pathlib.Path('/var/lib/pokrov').stat().st_mode&0o777),'tun_absent':not pathlib.Path('/sys/class/net/pokrov0').exists(),'recovery_absent':not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()})
result['binaries_absent']=all(not pathlib.Path(x).exists() for x in ['/usr/bin/pokrov','/usr/lib/pokrov/ui/pokrov','/usr/lib/pokrov/pokrov-linuxd','/usr/lib/pokrov/pokrov-core'])
result['socket_absent']=not pathlib.Path('/run/pokrov/pokrov-linuxd.sock').exists()
result['units_not_active']={name:subprocess.run(['systemctl','is-active','--quiet',name],capture_output=True).returncode!=0 for name in ['pokrov-linuxd.service','pokrov-linuxd.socket','pokrov-linux-sleep.service']}
result['units_not_enabled']={name:subprocess.run(['systemctl','is-enabled','--quiet',name],capture_output=True).returncode!=0 for name in ['pokrov-linuxd.service','pokrov-linuxd.socket','pokrov-linux-sleep.service']}
result['core_process_absent']=subprocess.run(['pgrep','-x','pokrov-core'],capture_output=True).returncode==1
result['daemon_process_absent']=subprocess.run(['pgrep','-x','pokrov-linuxd'],capture_output=True).returncode==1
network={}
for name,args in {'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}.items():
 q=subprocess.run(args,capture_output=True);assert q.returncode==0;network[name]=hashlib.sha256(q.stdout).hexdigest()
original=json.loads((r/'clean-install.json').read_text())['network_before'];result['network_matches_clean_preinstall']={k:v==network[k] for k,v in original.items()};result['finished_epoch']=time.time()
result['status']='PASS_CONNECTED_UNINSTALL_AND_PURGE' if p.returncode==0 and all(result['state_unchanged'].values()) and not result['package_installed'] and result['binaries_absent'] and result['socket_absent'] and all(result['units_not_active'].values()) and all(result['units_not_enabled'].values()) and result['core_process_absent'] and result['daemon_process_absent'] and result['tun_absent'] and result['recovery_absent'] and result['state_root_mode']=='0o700' and all(result['network_matches_clean_preinstall'].values()) else 'FAIL'
save();print(json.dumps(result,indent=2));assert result['status'].startswith('PASS')
