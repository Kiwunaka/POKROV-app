from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

CLIENT=Path('E:/r12client')
CORE=Path('E:/r12core-implementation')
OUT=Path('E:/r12-c05-go-notices')
PRIOR=Path('E:/r12-c05-package-artifacts')
TOOLCHAIN=Path('C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64')
MODCACHE=Path('C:/Users/kiwun/go/pkg/mod')
manifest=json.loads((CLIENT/'config/runtime-artifacts.seed.json').read_text())['core']
source=manifest['source_commit']
assert source=='8dc57a830bd1487389dd1b7c9190f094c31e13bc'
assert subprocess.check_output([str(TOOLCHAIN/'bin/go.exe'),'version'],text=True).strip()=='go version go1.26.8 windows/amd64'
inventory=json.loads((PRIOR/'linked-module-notices.json').read_text())
binding={}
for target in ['android','windows']:
    asset=manifest['assets'][target]
    path=CLIENT/asset['sync_destination']/asset['entry']
    assert path.stat().st_size==asset['size']
    assert hashlib.sha256(path.read_bytes()).hexdigest()==asset['sha256']
    binding[target]={'file':path.relative_to(CLIENT).as_posix(),'bytes':asset['size'],'sha256':asset['sha256']}

data=bytearray(('POKROV Core native Go notices\n\n'
    f'Core source snapshot: {source}\n'
    'Go toolchain: go1.26.8\n'
    'This file preserves root copyright, license and patent notices from the\n'
    'recorded Android AAR and Windows DLL Go module inputs. Not every component\n'
    'is present on each platform. Effective replacement sources are identified\n'
    'below. This file does not replace other native, nested-package or source\n'
    'distributions. License texts are reproduced without modification.\n\n').encode())
sections=[]
files=[]

def heading(title, info):
    data.extend(('\n'+'='*78+'\n'+title+'\n'+info+'\n'+'='*78+'\n').encode('utf8'))

def append_file(label, source_ref, raw):
    raw.decode('utf8')
    data.extend(('\nRoot file: '+label+'\nSource: '+source_ref+'\n\n').encode('utf8'))
    offset=len(data)
    data.extend(raw)
    data.extend(b'\n')
    files.append({'source_ref':source_ref,'body_offset':offset,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})

for label,path in [('POKROV Core','LICENSE'),('ray2sing converter','ray2sing/LICENSE')]:
    heading(label,'Source snapshot: '+source)
    raw=subprocess.check_output(['git','-C',str(CORE),'show',source+':'+path])
    append_file(path,'core@'+source+'/'+path,raw)
    sections.append({'component':label,'source':source})
heading('Go runtime and standard library','Toolchain version: go1.26.8')
for name in ['LICENSE','PATENTS']:
    append_file(name,'go1.26.8/'+name,(TOOLCHAIN/name).read_bytes())
sections.append({'component':'Go runtime and standard library','version':'go1.26.8'})

missing=[]
patents=0
with zipfile.ZipFile(PRIOR/'linked-root-notices.zip') as archive:
    for module in inventory['modules']:
        identity=module['identity']
        replacement=identity.get('replacement')
        label=identity['module']+' '+identity['version']
        info='Recorded binary inputs: '+', '.join(module['binaries'])
        if replacement:
            info+='\nEffective replacement: '+replacement['module']+' '+replacement['version']
            if replacement['module'].startswith('./'):
                info+='\nReplacement source snapshot: '+source
        heading(label,info)
        notices=module['retained_root_notices']
        if not notices:
            missing.append(identity)
            data.extend(b'No root license text was found in this recorded source snapshot.\nNo replacement license has been inferred or supplied here.\n')
        for notice in notices:
            raw=archive.read(notice['artifact'])
            assert len(raw)==notice['bytes'] and hashlib.sha256(raw).hexdigest()==notice['sha256']
            append_file(notice['source_ref'].rsplit('/',1)[-1],notice['source_ref'],raw)
        directory=Path(module['source_dir']).resolve()
        assert directory.is_relative_to(CORE.resolve()) or directory.is_relative_to(MODCACHE.resolve())
        patent=directory/'PATENTS'
        if patent.is_file():
            if directory.is_relative_to(CORE.resolve()):
                relative=patent.relative_to(CORE).as_posix()
                raw=subprocess.check_output(['git','-C',str(CORE),'show',source+':'+relative])
                ref='core@'+source+'/'+relative
            else:
                raw=patent.read_bytes()
                effective=replacement or identity
                ref=effective['module']+'@'+effective['version']+'/PATENTS'
            append_file('PATENTS',ref,raw)
            patents+=1
        sections.append({'component':label,'identity':identity,'root_notice_count':len(notices),'recorded_binaries':module['binaries']})

assert len(inventory['modules'])==128 and len(missing)==1
path=CLIENT/'packages/app_shell/assets/licenses/native-go-NOTICES.txt'
path.parent.mkdir(parents=True,exist_ok=True)
assert not path.exists()
path.write_bytes(data)
for item in files:
    body=data[item['body_offset']:item['body_offset']+item['bytes']]
    assert hashlib.sha256(body).hexdigest()==item['sha256']
receipt={'schema':'pokrov.native-go-root-notices/v1','source_commit':source,'go_toolchain':'go1.26.8',
    'artifact_binding':binding,'notice_asset':{'file':path.relative_to(CLIENT).as_posix(),'bytes':len(data),
        'sha256':hashlib.sha256(data).hexdigest()},'sections':sections,'verbatim_files':files,
    'module_entries':128,'modules_with_root_license_notices':127,'additional_module_patent_files':patents,
    'missing_root_license':missing,'complete_license_clearance':False,
    'input_inventory_sha256':hashlib.sha256((PRIOR/'linked-module-notices.json').read_bytes()).hexdigest(),
    'input_archive_sha256':hashlib.sha256((PRIOR/'linked-root-notices.zip').read_bytes()).hexdigest()}
(OUT/'assembly.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8')
print(json.dumps({'notice_asset':receipt['notice_asset'],'sections':len(sections),'verbatim_files':len(files),'patent_files':patents}))
