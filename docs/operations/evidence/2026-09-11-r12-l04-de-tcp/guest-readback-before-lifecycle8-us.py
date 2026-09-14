import pathlib,json,hashlib,subprocess,io,tarfile,os,platform,stat
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');deb=r/'pokrov_1.2.0~beta.30-8_amd64.deb'
assert hashlib.sha256(deb.read_bytes()).hexdigest()=='b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933'
rows=[]
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)]))) as tar:
 for entry in tar:
  if not entry.isfile() and not entry.issym():continue
  name=entry.name.removeprefix('./');assert name.startswith('usr/');path=pathlib.Path('/')/name;st=path.lstat();assert st.st_uid==0 and st.st_gid==0,name
  if entry.issym():assert path.is_symlink() and os.readlink(path)==entry.linkname;sha=None
  else:
   assert path.is_file() and not path.is_symlink();sha=hashlib.sha256(path.read_bytes()).hexdigest();assert sha==hashlib.sha256(tar.extractfile(entry).read()).hexdigest(),name
   assert stat.S_IMODE(st.st_mode)==entry.mode,name
  rows.append({'path':name,'sha256':sha,'mode':oct(stat.S_IMODE(st.st_mode))})
assert not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
assert stat.S_IMODE(pathlib.Path('/var/lib/pokrov').stat().st_mode)==0o700
assert stat.S_IMODE(pathlib.Path('/var/lib/pokrov/profiles').stat().st_mode)==0o700
assert stat.S_IMODE(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').stat().st_mode)==0o600
v=json.loads((r/'candidate8-gui-core-loss.json').read_bytes());events=[]
p=subprocess.run(['journalctl','-u','pokrov-linuxd.service','--since','@'+str(int(v['started_epoch'])),'-o','json','--no-pager'],capture_output=True,text=True,check=True)
for line in p.stdout.splitlines():
 item=json.loads(line)
 try:event=json.loads(item.get('MESSAGE',''))
 except (ValueError,TypeError):continue
 if event.get('event') in ('authorization_decision','linux_authorization_decision'):
  events.append({k:event[k] for k in ('event','action','outcome','backend','result') if k in event})
result={'status':'PASS_INSTALLED_PAYLOAD_READBACK','artifact_sha256':hashlib.sha256(deb.read_bytes()).hexdigest(),'version':subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True),'checked_payload_entries':len(rows),'entries':rows,'all_bytes_modes_ownership_match_deb':True,'private_directory_modes':'0700/0700; active profile 0600','no_tun':True,'no_recovery':True,'authorization_events':events,'gui_pid_unchanged':pathlib.Path('/proc/1648').exists() and (pathlib.Path('/proc/1648/exe').resolve()==pathlib.Path('/usr/lib/pokrov/ui/pokrov'))}
out=r/'candidate8-installed-before-lifecycle-us-20260912.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='entries'}))
