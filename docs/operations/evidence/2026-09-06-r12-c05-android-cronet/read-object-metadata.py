from pathlib import Path
import struct,json,hashlib,collections
out=Path('E:/r12-c05-android-cronet');inputs=json.loads(Path('E:/r12-c05-source-packet/android-cronet-library-binding.json').read_text());result=[]
for x in inputs:
 data=Path(x['path']).read_bytes();assert hashlib.sha256(data).hexdigest()==x['sha256'];assert data[:8]==b'!<arch>\n';pos=8;longnames=b'';objects=[]
 while pos<len(data):
  h=data[pos:pos+60];assert h[-2:]==b'`\n';n=h[:16].decode().strip();size=int(h[48:58]);body=data[pos+60:pos+60+size];pos+=60+size+(size%2)
  if n=='//':longnames=body;continue
  if n=='/':continue
  if n.startswith('/') and n[1:].isdigit():n=longnames[int(n[1:]):].split(b'/\n',1)[0].decode()
  else:n=n.rstrip('/')
  assert body[:4]==b'\x7fELF',(n,body[:4]);bits=body[4];assert body[5]==1
  if bits==2:
   shoff=struct.unpack_from('<Q',body,40)[0];shentsize,shnum,shstrndx=struct.unpack_from('<HHH',body,58);fmt='<IIQQQQIIQQ'
  else:
   shoff=struct.unpack_from('<I',body,32)[0];shentsize,shnum,shstrndx=struct.unpack_from('<HHH',body,46);fmt='<IIIIIIIIII'
  sections=[struct.unpack_from(fmt,body,shoff+i*shentsize) for i in range(shnum)];source=[];comments=[]
  strsec=sections[shstrndx];strtab=body[strsec[4]:strsec[4]+strsec[5]]
  for sec in sections:
   secname=strtab[sec[0]:].split(b'\0',1)[0].decode()
   if secname=='.comment':comments=body[sec[4]:sec[4]+sec[5]].split(b'\0');comments=[b.decode(errors='replace') for b in comments if b]
   if sec[1]!=2:continue
   strings=sections[sec[6]];st=body[strings[4]:strings[4]+strings[5]]
   for at in range(sec[4],sec[4]+sec[5],sec[9]):
    name_index=struct.unpack_from('<I',body,at)[0];info=body[at+4] if bits==2 else body[at+12]
    if info&15==4:source.append(st[name_index:].split(b'\0',1)[0].decode(errors='replace'))
  objects.append({'member':n,'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest(),'source_file_symbols':source,'compiler_comments':comments})
 assert [o['member'] for o in objects]==(out/f"archive-members-{x['arch']}.txt").read_text().splitlines()
 r={'arch':x['arch'],'archive_sha256':x['sha256'],'members':objects};result.append(r);print(x['arch'],len(objects),'no_source',sum(not o['source_file_symbols'] for o in objects),'compiler_counts',collections.Counter(c for o in objects for c in o['compiler_comments']))
(out/'archive-object-metadata.json').write_text(json.dumps(result,indent=2)+'\n')
