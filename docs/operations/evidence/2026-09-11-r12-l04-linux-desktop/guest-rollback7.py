import hashlib,json,os,pathlib,platform,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate7-rollback-to-baseline.json';assert not out.exists()
assert subprocess.run(['pgrep','-x','pokrov'],capture_output=True).returncode==1
assert not pathlib.Path('/sys/class/net/pokrov0').exists()
assert not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-7'
roots={'profile':pathlib.Path('/var/lib/pokrov/profiles'),'settings':pathlib.Path('/home/pokrovqa/.local/share/space.pokrov.linux'),'keyring':pathlib.Path('/home/pokrovqa/.local/share/keyrings')}
def snapshot():return {name:{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()} for name,root in roots.items()}
before=snapshot();assert all(before.values())
versions={}
for label,name,key in [('session','app-first-session-linux.json','schema_version'),('experience','pokrov-client-experience-v1.json','version')]:
 p=roots['settings']/name;v=json.loads(p.read_text());versions[label]=v.get(key)
deb=r/'upgrade-baseline/pokrov_1.2.0~beta.30-1_amd64.deb';sha=hashlib.sha256(deb.read_bytes()).hexdigest();assert sha=='f600ae9bdfe37275da311a85d5e774165733953faf4ab98db1902fb069b66ee4'
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
result={'operation':'rollback_to_explicit_same_payload_version_fixture','baseline_is_prior_public_release':False,'source_version':'1.2.0~beta.30-7','target_version':'1.2.0~beta.30-1','baseline_sha256':sha,'signature_verified':True,'state_schema_versions_before':versions,'state_file_counts_before':{k:len(v) for k,v in before.items()},'started_epoch':time.time()}
out.write_text(json.dumps(result,indent=2)+'\n')
with (r/'candidate7-rollback-to-baseline.log').open('w') as log:
 p=subprocess.run(['apt-get','-y','--allow-downgrades','install',str(deb)],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive','NEEDRESTART_MODE':'l'},stdout=log,stderr=subprocess.STDOUT)
after=snapshot();result.update({'apt_exit_code':p.returncode,'installed_version':subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True),'state_unchanged':{k:v==after[k] for k,v in before.items()},'socket_enabled':subprocess.run(['systemctl','is-enabled','--quiet','pokrov-linuxd.socket']).returncode==0,'state_root_mode':oct(pathlib.Path('/var/lib/pokrov').stat().st_mode&0o777),'finished_epoch':time.time()})
result['status']='PASS_ROLLBACK_STATE_PRESERVATION' if p.returncode==0 and all(result['state_unchanged'].values()) and result['installed_version']=='1.2.0~beta.30-1' else 'FAIL'
out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));assert result['status'].startswith('PASS')
