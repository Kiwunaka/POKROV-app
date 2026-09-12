from pathlib import Path
import subprocess,json,hashlib,os,platform,time,socket,stat,io,tarfile
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-lifecycle-us-recovery-20260912.json';assert not out.exists()
deb=r/'pokrov_1.2.0~beta.30-8_amd64.deb';expected='b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933';assert hashlib.sha256(deb.read_bytes()).hexdigest()==expected
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
ui=Path('/proc/1648');assert ui.stat().st_uid==1000 and (ui/'exe').resolve()==Path('/usr/lib/pokrov/ui/pokrov')
env={x.split('=',1)[0]:x.split('=',1)[1] for x in (ui/'environ').read_text().split(chr(0)) if '=' in x and x.split('=',1)[0] in {'DISPLAY','XAUTHORITY','DBUS_SESSION_BUS_ADDRESS','XDG_RUNTIME_DIR','HOME'}};assert 'DISPLAY' in env
profile=Path('/var/lib/pokrov/profiles/active-profile.json');original_profile=hashlib.sha256(profile.read_bytes()).hexdigest()
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
network=lambda:{k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()};before=network()
result={'status':'RUNNING','artifact_sha256':expected,'started_epoch':time.time(),'profile_before_sha256':original_profile,'network_before':before,'signature_verified':True,'initial_gui_uid':1000,'initial_gui_pid':1648,'operation':'exact package8 connected purge and same-byte reinstall'}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
save()
try:
 with (r/'candidate8-lifecycle-us-driver-20260912.log').open('w') as log:
  p=subprocess.run(['python3',str(r/'guest-readback-before-lifecycle8-us.py')],stdout=log,stderr=subprocess.STDOUT);result['payload_preflight_exit']=p.returncode;save();assert p.returncode==0
  p=subprocess.run(['python3',str(r/'guest-connected-uninstall8-us-20260912.py')],stdout=log,stderr=subprocess.STDOUT);result['uninstall_test_exit']=p.returncode;save()
finally:
 status=subprocess.run(['dpkg-query','-W','-f=${db:Status-Status}','pokrov'],capture_output=True,text=True).stdout.strip()
 if status!='installed':
  with (r/'candidate8-reinstall-us-20260912.log').open('w') as log:p=subprocess.run(['apt-get','-y','--no-download','install',str(deb)],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive','NEEDRESTART_MODE':'l'},stdout=log,stderr=subprocess.STDOUT)
  result['reinstall_exit']=p.returncode;save()
 assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-8'
 with socket.socket(socket.AF_UNIX) as s:
  s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall(b'{"protocol":"pokrov-linuxd-v1","request_id":"l04-lifecycle8-restore","action":"disconnect","payload":{}}\n');response=json.loads(s.makefile('rb').readline(65537));result['disconnect_ok']=response.get('ok')
 for _ in range(120):
  if not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists():break
  time.sleep(.25)
 result['network_after']=network();result['network_restored']={k:v==result['network_after'][k] for k,v in before.items()};result['profile_unchanged']=hashlib.sha256(profile.read_bytes()).hexdigest()==original_profile
 count=0
 with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)]))) as tar:
  for entry in tar:
   if not entry.isfile() and not entry.issym():continue
   path=Path('/')/entry.name.removeprefix('./');st=path.lstat();assert st.st_uid==0 and st.st_gid==0
   if entry.issym():assert path.is_symlink() and os.readlink(path)==entry.linkname
   else:assert hashlib.sha256(path.read_bytes()).digest()==hashlib.sha256(tar.extractfile(entry).read()).digest() and stat.S_IMODE(st.st_mode)==entry.mode
   count+=1
 result['restored_payload_entries']=count
 if not ui.exists():
  args=['systemd-run','--unit=pokrov-l04-ui8-us-restored-20260912','--uid=pokrovqa','--property=StandardOutput=null','--property=StandardError=null']+['--setenv='+k+'='+v for k,v in env.items()]+['/usr/bin/pokrov'];subprocess.run(args,capture_output=True,check=True)
  time.sleep(4)
  pid=int(subprocess.check_output(['systemctl','show','pokrov-l04-ui8-us-restored-20260912','-p','MainPID','--value'],text=True));assert pid>0;ui=Path('/proc')/str(pid)
 result['restored_gui_pid']=int(ui.name);result['restored_gui_uid']=ui.stat().st_uid;assert ui.stat().st_uid==1000 and (ui/'exe').resolve()==Path('/usr/lib/pokrov/ui/pokrov')
 result['runtime_absent']=not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists();result['finished_epoch']=time.time();result['status']='PASS' if result.get('uninstall_test_exit')==0 and result.get('reinstall_exit')==0 and result['disconnect_ok'] and all(result['network_restored'].values()) and result['profile_unchanged'] and count==302 and result['runtime_absent'] else 'FAIL_WITH_RESTORATION';save()
print(json.dumps({k:v for k,v in result.items() if k not in ['network_before','network_after']}));assert result['status']=='PASS'
