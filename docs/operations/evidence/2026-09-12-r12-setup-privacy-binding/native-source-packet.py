from pathlib import Path,PurePosixPath
import datetime,hashlib,json,os,shutil,subprocess,time,zipfile

base=Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work=base/'setup-privacy-final-6b271de-20260912';out=work/'source-packet'
assert Path(__file__).resolve().parent==work
out.mkdir(mode=0o755)
source=work/'source';revision='6b271decead88b708e2fc03984b703b0a4e63ebd'
sha=lambda p:hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
manifest=json.loads((work/'final-source.json').read_bytes())
assert manifest['source_commit']==revision and len(manifest['files'])==3339
assert subprocess.check_output(['git','-c','safe.directory='+str(source),'-C',str(source),'status','--porcelain'])==b''
checkout_line_endings={}
source_bytes={}
def core_bytes(row):
    raw=(source/row['path']).read_bytes()
    actual=hashlib.sha256(raw).hexdigest()
    if actual!=row['sha256']:
        assert row['path'].endswith('.ps1')
        raw=raw.replace(b'\r\n',b'\n')
        assert hashlib.sha256(raw).hexdigest()==row['sha256']
        checkout_line_endings[row['path']]={'git_blob_sha256':row['sha256'],'checkout_sha256':actual,'difference':'Declared PS1 CRLF checkout; exact Git LF bytes retained in source packet'}
    if row['path'] in source_bytes:assert source_bytes[row['path']]==actual
    source_bytes[row['path']]=actual
    return raw
for row in manifest['files']:core_bytes(row)

old=base/'offline-source-2662-20260912';archive=old/'source-review.zip'
assert sha(archive)=='988573fde7433cc20c40f40a4696d0fa5b54aea1c936feec39cc7dab3715b25d'
assert shutil.disk_usage(out).free>35*2**30
cache=out/'go-module-cache';cache.mkdir()
report={'checkout_line_endings':checkout_line_endings,'line_ending_handling':'Git LF bytes are retained for declared PS1 CRLF checkouts; handling is inherited from verified Core880 packet','status':'RUNNING','source':revision,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'steps':[]}
def save(): (out/'progress.json').write_text(json.dumps(report,indent=2)+'\n')
save()
cache_rows={};historical=[]
with zipfile.ZipFile(archive) as z:
    old_manifest=json.loads(z.read('SOURCE-MANIFEST.json'))
    assert len(z.namelist())==len(old_manifest['files'])+1==3693
    for row in old_manifest['files']:
        raw=z.read(row['path']);assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
        if row['path'].startswith('go-module-cache/'):
            relative=row['path'].removeprefix('go-module-cache/');target=cache/relative
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw);cache_rows[row['path']]=row
        elif row['path'].startswith(('historical/','native/','metadata/')):
            historical.append(row)
assert len(cache_rows)==492
tool=json.loads((old/'tool-inputs/receipt.json').read_bytes());assert tool['status']=='PASS_AUTHENTICATED_TOOL_BUILD_INPUTS'
new_tool_files=[]
for row in tool['files']:
    p=old/'tool-inputs/cache'/row['path'];assert sha(p)==row['sha256']
    name='go-module-cache/'+row['path'];target=cache/row['path']
    if name in cache_rows:assert cache_rows[name]['sha256']==row['sha256'];continue
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
    cache_rows[name]={**row,'path':name};new_tool_files.append(name)
report.update(previous_archive_entries_verified=3693,module_cache_inputs=len(cache_rows),new_tool_input_files=len(new_tool_files));save()
for name in ['home','tmp','go-cache']: (out/name).mkdir()
for current,dirs,files in os.walk(out):
    os.chown(current,65534,65534)
    for name in files:os.chown(Path(current)/name,65534,65534)
definitions=json.loads((work/'source-graph-definitions.json').read_bytes())
results=[]
for item in definitions:
    args=[str(base/'tools/go/bin/go'),*item['command'][1:]]
    env={'PATH':str(base/'tools/go/bin')+':/usr/bin:/bin','HOME':str(out/'home'),'GOMODCACHE':str(cache),'GOCACHE':str(out/'go-cache'),'GOPATH':str(out/'home/go'),'GOTMPDIR':str(out/'tmp'),'GOPROXY':'off','GOSUMDB':'off','GOENV':'off','GOWORK':'off','GOTELEMETRY':'off','GOMAXPROCS':'1','LANG':'C.UTF-8',**item['environment']}
    command=['unshare','--net','--','setpriv','--reuid=65534','--regid=65534','--clear-groups',*args]
    started=time.monotonic()
    p=subprocess.run(command,cwd=source,env=env,capture_output=True,timeout=300)
    log=out/(item['name']+'.offline.stdout.json');log.write_bytes(p.stdout)
    errors=out/(item['name']+'.offline.stderr.log');errors.write_bytes(p.stderr)
    results.append({'name':item['name'],'command':args,'environment':env,'network_isolated':True,'uid':65534,'exit_code':p.returncode,'elapsed_seconds':round(time.monotonic()-started,3),'stdout_sha256':sha(log),'stderr_sha256':sha(errors)})
    report['steps']=results;save();assert p.returncode==0,item['name']
for row in manifest['files']:core_bytes(row)
(out/'offline-graph-checks.json').write_text(json.dumps(results,indent=2)+'\n')
packet=out/'pokrov-core-6b271de-source-review.zip';entries=[]
with zipfile.ZipFile(packet,'x',allowZip64=True) as z:
    def add(name,raw,mode='100644'):
        assert not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts
        info=zipfile.ZipInfo(name,(2026,9,12,0,0,0));info.create_system=3;info.external_attr=int(mode,8)<<16
        info.compress_type=zipfile.ZIP_STORED if name.endswith('.zip') else zipfile.ZIP_DEFLATED
        z.writestr(info,raw);entries.append({'path':name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
    for row in manifest['files']:add('core/'+row['path'],core_bytes(row),row['mode'])
    for name,row in sorted(cache_rows.items()):
        p=cache/name.removeprefix('go-module-cache/');assert sha(p)==row['sha256'];add(name,p.read_bytes())
    with zipfile.ZipFile(archive) as oldzip:
        for row in historical:
            name=row['path'];raw=oldzip.read(name)
            if name.startswith('metadata/'):name='historical/core-2662/'+name
            add(name,raw)
    add('metadata/source-inventory.json',(work/'final-source.json').read_bytes())
    add('metadata/offline-graph-checks.json',(out/'offline-graph-checks.json').read_bytes())
    add('metadata/gomobile-source-inputs.json',(old/'tool-inputs/receipt.json').read_bytes())
    add('metadata/native-builds.json',(work/'progress.json').read_bytes())
    for name in ['android-evidence-corrected.json','windows-evidence-corrected.json','sbom-local-source-correction.json','audit/artifact-composition.json','sbom/corrected/core-source.cdx.json','sbom/corrected/engine-source.cdx.json']:
        add('metadata/'+name,(work/name).read_bytes())
    readme='''# POKROV Core6b271de source review packet

Internal source preparation for Core 6b271decead88b708e2fc03984b703b0a4e63ebd.
This is not a public release or complete corresponding-source verdict.

core/ contains 3339 exact Git blobs, with modes, build scripts and licenses.
Declared PS1 CRLF checkout endings are normalized to exact Git LF blob bytes;
the native build scripts already validate that declared equivalence.
The local sing-tun copy retains its upstream base and two Windows cleanup
fixes. Setup diagnostics additionally omit caller filesystem paths and listen
address; the source regression test covers stderr and legacy observer.
Official Wintun binaries and their separate terms are retained unchanged.
go-module-cache/ preserves the authenticated runtime download inputs and the
pinned gomobile/gobind source supplement; no client keys or profiles are included.
native/ preserves the same three native-source archives. Previous metadata is
explicitly historical. SOURCE-MANIFEST.json lists every entry's size and SHA-256.

Five target dependency graphs resolve in empty network namespaces, uid65534,
with GOPROXY=off and readonly manifests using this packet's module-cache inputs.
Four exact library builds also ran network-isolated using prepared compiler and
module caches; their receipts are retained. The earlier fresh-tool/cold-cache
reconstruction belongs to Core2662 and is not relabeled as current evidence.

Source SBOM corrections identify local replacements by Core commit/source path
and keep declared require versions separate. Full native SDK/compiler/Cronet
reconstruction, combined license compatibility, client licensing, corresponding
source delivery and publication are not established. Existing licenses apply.
'''
    add('README.md',readme.encode())
    document={'schema_version':'pokrov.core-source-review-packet/v1','core_commit':revision,'status':'SOURCE_PREPARATION_ONLY','files':entries.copy()}
    raw=(json.dumps(document,indent=2)+'\n').encode();(out/'source-manifest.json').write_bytes(raw);add('SOURCE-MANIFEST.json',raw)
with zipfile.ZipFile(packet) as z:
    assert len(z.namelist())==len(set(z.namelist()))==len(entries)
    for row in entries:
        raw=z.read(row['path']);assert len(raw)==row['bytes'] and hashlib.sha256(raw).hexdigest()==row['sha256']
report.update(status='PASS_SOURCE_PREPARATION_ONLY',core_files=3339,packet_entries=len(entries),archive={'path':str(packet),'bytes':packet.stat().st_size,'sha256':sha(packet)},native_source_archives=3,publication='NOT_PERFORMED',complete_license_compatibility=False,free_bytes_after=shutil.disk_usage(out).free)
save();print(json.dumps({k:v for k,v in report.items() if k!='steps'}))
