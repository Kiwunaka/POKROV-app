from pathlib import Path
import datetime,hashlib,io,json,os,re,shutil,subprocess,tarfile,time
base=Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work=base/'setup-privacy-20260912';source=work/'source'
assert Path(__file__).resolve().parent==work and shutil.disk_usage(work).free>30*2**30
original=base/'wintun-final-880b-20260912/source'
revision='880bff65ad665844828fe50fc395e9cfc1cd81b4'
archive=subprocess.check_output(['git','-c','safe.directory='+str(original),'-C',str(original),'archive','--format=tar',revision])
source.mkdir()
with tarfile.open(fileobj=io.BytesIO(archive)) as t:
 for member in t.getmembers():
  assert not Path(member.name).is_absolute() and '..' not in Path(member.name).parts and (member.isdir() or member.isfile())
 t.extractall(source,filter='data')
manifest=json.loads((work/'overlay.json').read_bytes());assert manifest['base_source']==revision
with tarfile.open(work/'overlay.tar.gz') as t:
 for row in manifest['files']:
  raw=t.extractfile(row['path']).read();assert hashlib.sha256(raw).hexdigest()==row['sha256']
  target=work/'overlay'/row['path'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
shutil.copyfile(work/'overlay/v2/hcore/privacy_test.go',source/'v2/hcore/privacy_test.go')
for name in ['home','tmp']:(work/name).mkdir()
for current,dirs,files in os.walk(work):
 os.chown(current,65534,65534)
 for name in files:os.chown(Path(current)/name,65534,65534,follow_symlinks=False)
env={'PATH':str(base/'tools/go/bin')+':'+str(base/'tools/ripgrep-14.1.1-x86_64-unknown-linux-musl')+':/usr/bin:/bin','HOME':str(work/'home'),'GOROOT':str(base/'tools/go'),'GOPATH':str(base/'gopath'),'GOMODCACHE':str(base/'cache/mod'),'GOCACHE':str(base/'cache/build'),'GOTMPDIR':str(work/'tmp'),'TMPDIR':str(work/'tmp'),'XDG_CACHE_HOME':str(base/'xdg'),'DOTNET_CLI_HOME':str(base/'dotnet'),'DOTNET_CLI_TELEMETRY_OPTOUT':'1','GOTELEMETRY':'off','GOENV':'off','GOTOOLCHAIN':'local','GOWORK':'off','GOFLAGS':'-buildvcs=false -mod=readonly -p=1','GOMAXPROCS':'1','CGO_ENABLED':'1','GOPROXY':'off','GOSUMDB':'off','LANG':'C.UTF-8'}
report={'status':'RUNNING','base_source':revision,'overlay':manifest,'network_isolated':True,'uid':65534,'steps':[]}
def save():(work/'progress.json').write_text(json.dumps(report,indent=2)+'\n')
def run(label,args,expected=0):
 report['stage']=label;save();started=time.monotonic()
 command=['unshare','--net','--','sh','-c','ip link set lo up; exec "$@"','fixture','setpriv','--reuid=65534','--regid=65534','--clear-groups',*args]
 p=subprocess.run(command,cwd=source,env=env,capture_output=True,timeout=1800)
 text=(p.stdout+b'\n'+p.stderr).decode(errors='replace')
 lines=[line[:300] for line in re.sub(r'\x1b\[[0-9;]*m','',text).splitlines() if line.startswith(('ok ','? ','PASS','FAIL','--- FAIL','POKROV Core tests OK.')) or 'setup stderr is absent' in line or re.search(r'\.go:\d+:\d+:',line)]
 row={'label':label,'command':args,'expected_exit':expected,'exit_code':p.returncode,'elapsed_seconds':round(time.monotonic()-started,3),'stdout_sha256':hashlib.sha256(p.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(p.stderr).hexdigest(),'safe_summary':lines,'raw_output_saved':False}
 report['steps'].append(row);save()
 assert p.returncode==expected,(label,lines)
 return text
go=str(base/'tools/go/bin/go')
before=run('old_setup_expected_privacy_failure',[go,'test','-count=1','-run','^TestSetupDoesNotLogCallerPathsOrListenAddress$','./v2/hcore'],1)
assert 'setup stderr is absent or contains caller paths/listen address' in before
for row in manifest['files']:
 target=source/row['path'];shutil.copyfile(work/'overlay'/row['path'],target);os.chown(target,65534,65534)
formatted=subprocess.check_output([str(base/'tools/go/bin/gofmt'),'-l','v2/hcore/grpc_server.go','v2/hcore/privacy_test.go'],cwd=source)
assert not formatted,formatted
run('fixed_setup_and_runtime_failure',[go,'test','-count=1','-run','TestSetupDoesNotLogCallerPathsOrListenAddress|TestRuntimeFailureRedactsEveryDiagnosticOutput','./v2/hcore'])
run('full_core_gate',[str(base/'tools/powershell/pwsh'),'-NoProfile','-File','scripts/test.ps1','-GoExecutable',go])
for row in manifest['files']:assert hashlib.sha256((source/row['path']).read_bytes()).hexdigest()==row['sha256']
report.update(status='PASS',completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat());save()
print(json.dumps({'status':report['status'],'steps':[{k:r[k] for k in ['label','expected_exit','exit_code']} for r in report['steps']]}))
