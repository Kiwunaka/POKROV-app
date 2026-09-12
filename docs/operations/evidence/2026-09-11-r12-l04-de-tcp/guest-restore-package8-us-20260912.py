from pathlib import Path
import hashlib,io,json,os,platform,stat,subprocess,tarfile,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-lifecycle-us-manual-restore-20260912.json';assert not out.exists()
deb=r/'pokrov_1.2.0~beta.30-8_amd64.deb';expected='b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933';assert hashlib.sha256(deb.read_bytes()).hexdigest()==expected
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
assert not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists()
profile=Path('/var/lib/pokrov/profiles/active-profile.json');original=hashlib.sha256(profile.read_bytes()).hexdigest();assert original=='9b6f73f24726f32a97ee646081879bc6dfd19f63376cb2c33f58c7766c80d257'
dependencies=['libc6','libstdc++6','libgtk-3-0t64','libsecret-1-0','systemd','systemd-resolved','network-manager','nftables','iproute2','polkitd','pkexec']
for name in dependencies:assert subprocess.check_output(['dpkg-query','-W','-f=${db:Status-Status}',name],text=True)=='installed'
assert not subprocess.check_output(['dpkg','--audit'],text=True).strip()
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']};network=lambda:{k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()};before=network()
result={'artifact_sha256':expected,'started_epoch':time.time(),'status':'RUNNING','operation':'restore exact already-local deb with dpkg after apt internal pathname error','dependencies_already_installed':len(dependencies),'signature_verified':True,'original_profile_sha256':original}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
save()
with (r/'candidate8-lifecycle-us-dpkg-restore-20260912.log').open('w') as log:p=subprocess.run(['dpkg','-i',str(deb)],stdout=log,stderr=subprocess.STDOUT)
result['dpkg_exit']=p.returncode;save();assert p.returncode==0
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-8'
count=0
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)]))) as tar:
 for entry in tar:
  if not entry.isfile() and not entry.issym():continue
  path=Path('/')/entry.name.removeprefix('./');st=path.lstat();assert st.st_uid==0 and st.st_gid==0
  if entry.issym():assert path.is_symlink() and os.readlink(path)==entry.linkname
  else:assert hashlib.sha256(path.read_bytes()).digest()==hashlib.sha256(tar.extractfile(entry).read()).digest() and stat.S_IMODE(st.st_mode)==entry.mode
  count+=1
result['payload_entries_verified']=count;assert count==302
pidlist=subprocess.check_output(['pgrep','-u','1000','-x','xfce4-session'],text=True).split();assert len(pidlist)==1
session=Path('/proc')/pidlist[0];assert session.stat().st_uid==1000
allowed={'DISPLAY','XAUTHORITY','DBUS_SESSION_BUS_ADDRESS','XDG_RUNTIME_DIR','HOME'};env={x.split('=',1)[0]:x.split('=',1)[1] for x in (session/'environ').read_text().split(chr(0)) if '=' in x and x.split('=',1)[0] in allowed};assert 'DISPLAY' in env
assert subprocess.run(['pgrep','-x','pokrov'],capture_output=True).returncode==1
unit='pokrov-l04-ui8-us-repaired-20260912';args=['systemd-run','--unit='+unit,'--uid=pokrovqa','--property=StandardOutput=null','--property=StandardError=null']+['--setenv='+k+'='+v for k,v in env.items()]+['/usr/bin/pokrov'];subprocess.run(args,capture_output=True,check=True)
time.sleep(4);pid=int(subprocess.check_output(['systemctl','show',unit,'-p','MainPID','--value'],text=True));assert pid>0;gui=Path('/proc')/str(pid);assert gui.stat().st_uid==1000 and (gui/'exe').resolve()==Path('/usr/lib/pokrov/ui/pokrov')
result['gui_pid']=pid;result['gui_uid']=1000;result['profile_unchanged']=hashlib.sha256(profile.read_bytes()).hexdigest()==original;after=network();result['network_restored']={k:v==after[k] for k,v in before.items()};result['runtime_absent']=not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists();result['finished_epoch']=time.time();result['status']='PASS_SAME_BYTE_PACKAGE_AND_GUI_RESTORED' if result['profile_unchanged'] and all(result['network_restored'].values()) and result['runtime_absent'] else 'FAIL';save();print(json.dumps(result));assert result['status'].startswith('PASS')
