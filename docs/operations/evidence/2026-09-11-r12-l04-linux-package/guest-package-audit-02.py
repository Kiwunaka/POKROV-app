import hashlib,json,pathlib,subprocess,tarfile,io,os,stat
r=pathlib.Path('/home/pokrovtest/r12-l02');root=r/'l04-packages';deb=root/'pokrov_1.2.0~beta.30-2_amd64.deb'
raw=deb.read_bytes();metadata=json.loads(deb.with_suffix('.json').read_bytes());assert metadata['sha256']==hashlib.sha256(raw).hexdigest()
control=subprocess.check_output(['dpkg-deb','--field',str(deb)],text=True)
assert 'Architecture: amd64' in control and 'Version: 1.2.0~beta.30-2' in control
archive=subprocess.check_output(['dpkg-deb','--fsys-tarfile',str(deb)])
entries=[];executables=[]
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
 for item in tar.getmembers():
  assert item.uid==0 and item.gid==0,item.name
  if not item.issym():
   assert not item.mode&0o022,(item.name,oct(item.mode))
   assert not item.mode&0o6000,item.name
  name=item.name.removeprefix('./')
  entries.append({'path':name,'mode':oct(item.mode),'size':item.size,'type':item.type.decode(),'link':item.linkname})
  if name in ('usr/lib/pokrov/pokrov-core','usr/lib/pokrov/pokrov-linuxd','usr/lib/pokrov/ui/pokrov'):
   assert item.isfile() and item.mode==0o755;executables.append(name)
  if name=='usr/bin/pokrov':assert item.issym() and item.linkname=='../lib/pokrov/ui/pokrov'
assert len(executables)==3
controltar=subprocess.check_output(['dpkg-deb','--ctrl-tarfile',str(deb)])
with tarfile.open(fileobj=io.BytesIO(controltar)) as tar:
 for hook in ('postinst','prerm','postrm'):
  item=tar.getmember('./'+hook);content=tar.extractfile(item).read()
  assert item.mode==0o755 and b'\r' not in content
  subprocess.run(['/bin/sh','-n'],input=content,check=True)
stage=root/'pokrov_1.2.0~beta.30-2_amd64'
elfs=[]
for path in sorted((stage/'usr/lib/pokrov').rglob('*')):
 if path.is_file() and not path.is_symlink():
  with path.open('rb') as f:header=f.read(4)
  if header==b'\x7fELF':
   p=subprocess.run(['ldd',str(path)],text=True,capture_output=True)
   assert 'not found' not in p.stdout,(str(path),p.stdout)
   assert p.returncode==0 or 'not a dynamic executable' in p.stdout+p.stderr
   elfs.append({'path':str(path.relative_to(stage)),'ldd':p.stdout.strip(),'exit_code':p.returncode})
receipt={'status':'PASS_PACKAGE_CONTENTS','artifact':deb.name,'sha256':metadata['sha256'],'bytes':len(raw),'client_revision':metadata['client_revision'],'core_revision':metadata['core_revision'],'entries':entries,'elfs':elfs,'control':control,'hooks_shell_syntax':'PASS','signature':'UNSIGNED','install_runtime':'NOT_RUN'}
(r/'l04-deb-audit-02.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k not in ('entries','elfs','control')}))
