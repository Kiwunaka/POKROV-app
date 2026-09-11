from pathlib import Path
import json,zipfile,hashlib,subprocess,os,datetime
out=Path('C:/r12-c05-packages-20260911');rows=json.loads((out/'android-dex-identity.json').read_bytes())
assert len(rows)==5 and len({tuple(r['dex'].values()) for r in rows[:4]})==1
universal=next(r for r in rows if r['path'].endswith('app-direct-release.apk'));store=rows[-1]
container=out/'store-dex-only-container.apk';assert not container.exists()
with zipfile.ZipFile(store['path']) as source,zipfile.ZipFile(container,'x',zipfile.ZIP_DEFLATED) as target:
 for n,expected in store['dex'].items():
  b=source.read(n);assert hashlib.sha256(b).hexdigest()==expected;target.writestr(Path(n).name,b)
env=dict(os.environ,JAVA_HOME='C:/Users/kiwun/tools/jdk/17.0.18');cmd='C:/Users/kiwun/AppData/Local/Android/Sdk/cmdline-tools/latest/bin/apkanalyzer.bat'
receipts=[]
for label,path in [('direct',universal['path']),('store',str(container))]:
 log=out/f'android-dex-packages-{label}.log';err=out/f'android-dex-packages-{label}.stderr.log'
 with log.open('wb') as stdout,err.open('wb') as stderr:r=subprocess.run([cmd,'dex','packages',path],stdout=stdout,stderr=stderr,env=env)
 receipts.append({'label':label,'source':path,'exit':r.returncode,'log':log.name,'stderr':err.name})
 assert r.returncode==0,label
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS_TWO_EXACT_DEX_INPUTS_PARSED','commands':receipts,'direct_four_packages_have_identical_dex':True,'store_input':'Synthetic ZIP contains only exact DEX bytes extracted from original signed AAB; it is not an installable APK','source_artifacts':rows,'store_dex_container_sha256':hashlib.sha256(container.read_bytes()).hexdigest()}
(out/'android-dex-parsing.json').write_text(json.dumps(receipt,indent=2)+'\n');print(receipt['status'])
