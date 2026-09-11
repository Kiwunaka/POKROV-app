import pathlib,json,hashlib,tarfile,io,zstandard
r=pathlib.Path(__file__).parent
old=pathlib.Path('C:/r12-l04-fix07-20260911/candidate7-public-evidence/pokrov_1.2.0~beta.30-7_amd64.deb');new=r/'candidate8-public-evidence/pokrov_1.2.0~beta.30-8_amd64.deb'
def unpack(path):
 raw=path.read_bytes();assert raw[:8]==b'!<arch>\n';pos=8;result={}
 while pos<len(raw):
  head=raw[pos:pos+60];size=int(head[48:58]);name=head[:16].decode().strip().rstrip('/');data=raw[pos+60:pos+60+size];pos+=60+size+size%2
  if name.startswith(('data.tar','control.tar')):
   if name.endswith('.zst'):data=zstandard.ZstdDecompressor().stream_reader(io.BytesIO(data)).read()
   with tarfile.open(fileobj=io.BytesIO(data)) as tar:
    for t in tar:
     if t.isdir():continue
     result[name.split('.')[0]+'/'+t.name.removeprefix('./')]={'sha256':hashlib.sha256(tar.extractfile(t).read()).hexdigest() if t.isfile() else None,'mode':t.mode,'uid':t.uid,'gid':t.gid,'type':t.type.decode(),'linkname':t.linkname}
 return result
a,b=unpack(old),unpack(new);assert a.keys()==b.keys()
changed=[k for k in a if a[k]!=b[k]]
assert set(changed)=={'control/control','data/usr/share/doc/pokrov/build.json','data/usr/lib/pokrov/ui/lib/libapp.so','data/usr/lib/pokrov/ui/lib/libfile_selector_linux_plugin.so','data/usr/lib/pokrov/ui/lib/libflutter_secure_storage_linux_plugin.so','data/usr/lib/pokrov/ui/lib/liburl_launcher_linux_plugin.so','data/usr/lib/pokrov/ui/pokrov'},changed
result={'status':'PASS_EXACT_PAYLOAD_COMPARISON','old_sha256':hashlib.sha256(old.read_bytes()).hexdigest(),'new_sha256':hashlib.sha256(new.read_bytes()).hexdigest(),'changed_paths':changed,'identical_paths':len(a)-len(changed),'daemon_core_unit_hooks_byte_identical':True}
(r/'candidate8-public-evidence/package8-vs7.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
