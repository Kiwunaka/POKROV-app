import pathlib,json,subprocess,hashlib,os,platform,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate10-reinstall-for-recovery.json';assert not out.exists()
assert subprocess.run(['dpkg-query','-W','-f=${db:Status-Status}','pokrov'],capture_output=True).returncode!=0
state_paths={'settings':pathlib.Path('/home/pokrovqa/.local/share/space.pokrov.linux'),'keyring':pathlib.Path('/home/pokrovqa/.local/share/keyrings')}
def states():return {k:{str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()} for k,root in state_paths.items()}
private_before=states()
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json');before=hashlib.sha256(profile.read_bytes()).hexdigest()
deb=r/'pokrov_1.2.0~beta.30-10_amd64.deb';sha=hashlib.sha256(deb.read_bytes()).hexdigest();assert sha=='d4c3ead8786cfdd91ff7851e3634d7025e899323db13636803f3064551628f17'
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
with (r/'candidate10-reinstall-for-recovery.log').open('w') as log:
 p=subprocess.run(['apt-get','-y','install',str(deb)],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive','NEEDRESTART_MODE':'l'},stdout=log,stderr=subprocess.STDOUT)
result={'operation':'reinstall_for_current_package_recovery_proof','clean_install_claim':False,'sha256':sha,'signature_verified':True,'apt_exit_code':p.returncode,'retained_profile_unchanged':hashlib.sha256(profile.read_bytes()).hexdigest()==before,'installed_version':subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True),'finished_epoch':time.time()};out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));assert p.returncode==0 and result['retained_profile_unchanged']

import tarfile,io,stat
count=0
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)]))) as tar:
 for entry in tar:
  if not entry.isfile() and not entry.issym():continue
  path=pathlib.Path('/')/entry.name.removeprefix('./');st=path.lstat();assert st.st_uid==0 and st.st_gid==0
  if entry.issym():assert path.is_symlink() and os.readlink(path)==entry.linkname
  else:assert hashlib.sha256(path.read_bytes()).digest()==hashlib.sha256(tar.extractfile(entry).read()).digest() and stat.S_IMODE(st.st_mode)==entry.mode
  count+=1
result['verified_installed_entries']=count;result['private_state_preserved']=states()==private_before
result['socket_enabled']=subprocess.run(['systemctl','is-enabled','--quiet','pokrov-linuxd.socket'],capture_output=True).returncode==0
sock=pathlib.Path('/run/pokrov/pokrov-linuxd.sock');result['socket_mode']=oct(stat.S_IMODE(sock.stat().st_mode));result['socket_uid']=sock.stat().st_uid
result['state_mode']=oct(stat.S_IMODE(pathlib.Path('/var/lib/pokrov').stat().st_mode))
result['status']='PASS' if count==302 and result['private_state_preserved'] and result['socket_enabled'] and result['socket_mode']=='0o666' and result['socket_uid']==0 and result['state_mode']=='0o700' else 'FAIL'
out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));assert result['status']=='PASS'
