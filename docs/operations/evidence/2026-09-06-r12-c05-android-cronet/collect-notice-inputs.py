from pathlib import Path
import json,zipfile,hashlib,re,collections
out=Path('E:/r12-c05-android-cronet');z=zipfile.ZipFile('E:/r12-c05-source-packet/naive-source-30f3a568.zip');pre=z.namelist()[0].split('/')[0]+'/';prior=json.loads(Path('E:/r12-c05-cronet-graph/notice-assembly.json').read_text());scope=json.loads((out/'source-object-mapping.json').read_text());files=sorted(set(s[2:] for r in scope for t in r['targets'] for s in t.get('sources',[]) if s.startswith('//') and not s.startswith('//out/')));names=set(z.namelist());source_checks=[]
for n in files:
 key=pre+'src/'+n
 if key in names:source_checks.append({'file':n,'sha256':hashlib.sha256(z.read(key)).hexdigest()})
sections=[];dest=out/'notices';dest.mkdir(exist_ok=True);source_root=Path('E:/r12-c05-cronet-provenance/naive-source')
for i,s in enumerate(prior['sections']):
 if s['name']=='Mozilla Windows Cert code':continue
 p=Path(s['source_file']);b=p.read_bytes()[:s['size']];assert hashlib.sha256(b).hexdigest()==s['sha256']
 if p.is_relative_to(source_root):
  rel=p.relative_to(source_root).as_posix();fresh=z.read(pre+rel)[:s['size']];assert fresh==b,(s['name'],rel);b=fresh;origin='https://github.com/SagerNet/naiveproxy/blob/30f3a5689ac20ba1b87c1ce58f66d3aaa8b2cfe5/'+rel
 else:origin=s['origin']
 item={'name':s['name'],'origin':origin,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'scope':'Android GN native dependency or supporting source header; prior upstream authentication reused only after exact package source equality.'};p=dest/(str(len(sections)+1).zfill(2)+'.txt');p.write_bytes(b);item['body_file']=str(p);sections.append(item)
for label,n in [('LLVM libunwind','src/third_party/libunwind/src/LICENSE.TXT'),('CPU Features','src/third_party/cpu_features/src/LICENSE'),('JNI Zero','src/third_party/jni_zero/LICENSE')]:
 b=z.read(pre+n);p=dest/(str(len(sections)+1).zfill(2)+'.txt');p.write_bytes(b);sections.append({'name':label,'origin':'https://github.com/SagerNet/naiveproxy/blob/30f3a5689ac20ba1b87c1ce58f66d3aaa8b2cfe5/'+n,'sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'body_file':str(p)})
p=out/'cpu-features-bsd-header.txt';b=p.read_bytes();sections.append({'name':'CPU Features Android NDK compatibility header','origin':'https://github.com/SagerNet/naiveproxy/blob/30f3a5689ac20ba1b87c1ce58f66d3aaa8b2cfe5/src/third_party/cpu_features/src/ndk_compat/cpu-features.h','sha256':hashlib.sha256(b).hexdigest(),'bytes':len(b),'body_file':str(p)})
# Source projects that appear in the Android target get their own README metadata.
roots=sorted(set((n.split('third_party/',1)[0]+'third_party/'+n.split('third_party/',1)[1].split('/')[0]) for n in files if 'third_party/' in n));metadata=[]
for folder in roots:
 p=pre+'src/'+folder+'/README.chromium'
 if p in names:metadata.append({'source_directory':folder,'readme':z.read(p).decode(),'readme_sha256':hashlib.sha256(z.read(p)).hexdigest()})
report={'native_commit':'30f3a5689ac20ba1b87c1ce58f66d3aaa8b2cfe5','source_archive_sha256':hashlib.sha256(Path('E:/r12-c05-source-packet/naive-source-30f3a568.zip').read_bytes()).hexdigest(),'sections':sections,'source_file_hashes':source_checks,'declared_original_files':len(files),'source_readmes':metadata,'graph_summary':json.loads((out/'source-object-summary.json').read_text()),'scope':'Android GN-declared native source and supporting headers. Archive member and STT_FILE multiset congruence; no source-to-binary reproduction or complete transitive header/license clearance.'}
(out/'notice-inputs.json').write_text(json.dumps(report,indent=2)+'\n');print('sections',len(sections),'original_sources',len(source_checks),'declared_original_files',len(files),'README',len(metadata));print([s['name'] for s in sections])
