from pathlib import Path
import ctypes,datetime,hashlib,io,json,os,shutil,subprocess,tarfile,time

out=Path(__file__).parent;root=Path('E:/r12client').resolve()
destination='/tmp/pokrov-r12-core-validation-1c8b33f6a771409a/retained-client-2662-before-wintun-20260912'
roots=['apps/windows_shell/build/windows','apps/windows_shell/build/native_assets/windows','apps/windows_shell/build/release_bundle','apps/windows_shell/.dart_tool/flutter_build','apps/android_shell/build/app/outputs/flutter-apk','apps/android_shell/build/app/outputs/bundle/storeRelease']
sha=lambda p:hashlib.file_digest(p.open('rb'),'sha256').hexdigest()
assert shutil.disk_usage('C:/').free>40*2**30 and shutil.disk_usage('E:/').free>40*2**30
assert subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de','test ! -e '+destination]).returncode==0
files=[];directories=[]
for relative in roots:
    p=root/relative
    assert p.resolve().is_relative_to(root) and not p.is_symlink() and not p.is_junction()
    if not p.exists():continue
    directories.append(relative)
    for child in sorted(p.rglob('*')):
        assert not child.is_symlink() and not child.is_junction()
        if child.is_dir():directories.append(child.relative_to(root).as_posix())
        else:
            assert child.is_file()
            files.append({'path':child.relative_to(root).as_posix(),'bytes':child.stat().st_size,'sha256':sha(child)})
package_receipt=json.loads(Path('C:/r12-c05-packages-20260911/package-receipt.json').read_bytes())
inventory={r['path']:r for r in files}
for item in package_receipt['artifacts']:
    row=inventory[Path(item['path']).relative_to(root).as_posix()]
    assert row['bytes']==item['size'] and row['sha256']==item['sha256']
manifest={'status':'PREPARED','source_root':str(root),'source_commit':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),'previous_packages_core':'2662f76a3303a0518bb07fbbdc449c066de2f95b','destination_host':'pokrov-de','destination':destination,'directories':directories,'files':files,'total_file_bytes':sum(r['bytes'] for r in files),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(out/'package-retention-plan.json').write_text(json.dumps(manifest,indent=2)+'\n')
kernel=ctypes.WinDLL('kernel32');kernel.SetPriorityClass(kernel.GetCurrentProcess(),0x40)
remote_script="import os,pathlib,shutil,sys; p=pathlib.Path('"+destination+"'); assert shutil.disk_usage('/tmp').free>32*2**30; p.mkdir(mode=0o700); f=(p/'outputs.tar.gz').open('xb'); shutil.copyfileobj(sys.stdin.buffer,f); f.close()"
command="python3 -c '"+remote_script.replace("'","'\"'\"'")+"'"
with (out/'package-retention-upload.log').open('wb') as error:
    proc=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de',command],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=error)
    started=time.monotonic()
    class Writer:
        def __init__(self):self.bytes=0;self.digest=hashlib.sha256();self.last=0
        def write(self,b):
            proc.stdin.write(b);self.digest.update(b);self.bytes+=len(b)
            delay=self.bytes/(1024**2)-(time.monotonic()-started)
            if delay>0:time.sleep(min(delay,1))
            if time.monotonic()-self.last>10:
                self.last=time.monotonic();(out/'package-retention-progress.json').write_text(json.dumps({'status':'UPLOADING','bytes_sent':self.bytes,'elapsed_seconds':round(time.monotonic()-started,1),'total_uncompressed_bytes':manifest['total_file_bytes']})+'\n')
            return len(b)
        def flush(self):proc.stdin.flush()
    writer=Writer()
    with tarfile.open(fileobj=writer,mode='w|gz',compresslevel=1) as archive:
        raw=json.dumps(manifest,indent=2).encode();member=tarfile.TarInfo('retention-manifest.json');member.size=len(raw);member.mode=0o600;archive.addfile(member,io.BytesIO(raw))
        for relative in directories:archive.add(root/relative,arcname=relative,recursive=False)
        for row in files:
            path=root/row['path'];archive.add(path,arcname=row['path'],recursive=False)
            assert path.stat().st_size==row['bytes'] and sha(path)==row['sha256']
    writer.flush();proc.stdin.close();assert proc.wait(timeout=60)==0
manifest.update(status='UPLOADED_AWAITING_REMOTE_VERIFICATION',archive_bytes=writer.bytes,archive_sha256=writer.digest.hexdigest())
(out/'package-retention-upload.json').write_text(json.dumps(manifest,indent=2)+'\n')
verify="""from pathlib import Path
import hashlib,json,tarfile
p=Path('DESTINATION')
a=p/'outputs.tar.gz'
with a.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
assert digest=='DIGEST'
with tarfile.open(a,'r:gz') as archive:
    manifest=json.load(archive.extractfile('retention-manifest.json'))
    rows={r['path']:r for r in manifest['files']};seen=set()
    for member in archive:
        if member.name=='retention-manifest.json' or member.isdir():continue
        assert member.isfile() and member.name in rows
        with archive.extractfile(member) as f:actual=hashlib.file_digest(f,'sha256').hexdigest()
        assert actual==rows[member.name]['sha256'] and member.size==rows[member.name]['bytes']
        seen.add(member.name)
    assert seen==set(rows)
result={'status':'PASS_ALL_PREVIOUS_OUTPUT_BYTES_RETAINED','archive_sha256':digest,'archive_bytes':a.stat().st_size,'files':len(seen),'total_file_bytes':sum(x['bytes'] for x in rows.values()),'destination':str(a),'original_local_outputs_deleted':False}
(p/'verification.json').write_text(json.dumps(result,indent=2)+'\\n')
print(json.dumps(result))
""".replace('DESTINATION',destination).replace('DIGEST',writer.digest.hexdigest())
result=subprocess.run(['ssh','-o','BatchMode=yes','-o','ConnectTimeout=8','pokrov-de','python3 -'],input=verify,text=True,capture_output=True,check=True,timeout=180)
verified=json.loads(result.stdout);assert verified['status']=='PASS_ALL_PREVIOUS_OUTPUT_BYTES_RETAINED'
(out/'output-retention.json').write_text(json.dumps(verified,indent=2)+'\n')
print(json.dumps(verified))
