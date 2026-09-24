from pathlib import Path
import hashlib,json,runpy,sys,subprocess,tarfile,shutil
r=Path('/tmp/pokrov-l04-health-package-20260914');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert shutil.disk_usage(r).free>2*2**30
assert sha(r/'linux-ui-361b0e4.tar.gz')=='6747c07a6c5bc5bb3b8a790eb820d7eb92293114c5a0cb2d8e855a2741f1ab72'
assert sha(r/'pokrov-core-health')=='2bb57afc2a0ee7f8becb49a411fd099d78468a7ad5610ddf1186e6dea589f5bd'
assert sha(r/'pokrov-linuxd-health')=='a9ffb06a9f7c0824e67159df63e3a2039ccb16aab234dc0c24aa4f11e4272915'
ui=r/'ui10';ui.mkdir()
with tarfile.open(r/'linux-ui-361b0e4.tar.gz') as tar:tar.extractall(ui,filter='data')
build=json.loads((r/'l04-client-build-10-bundle.json').read_text());assert build['exit_code']==0
for row in build['bundle_files']:assert sha(ui/'bundle'/row['path'])==row['sha256']
def file_digest(stream,algorithm):
 digest=hashlib.new(algorithm)
 for chunk in iter(lambda:stream.read(1024*1024),b''):digest.update(chunk)
 return digest
hashlib.file_digest=file_digest
source=r/'source/apps/linux_shell/packaging/build-deb.py'
sys.argv=[str(source),'--bundle',str(ui/'bundle'),'--daemon',str(r/'pokrov-linuxd-health'),'--core',str(r/'pokrov-core-health'),'--client-revision','361b0e4399fde51ab0be42d7350900fc4886571c','--core-revision','86aca407103daed2623df80874414ad0e94f8261','--package-revision','10','--output',str(r/'package10')]
runpy.run_path(str(source),run_name='__main__')
out=r/'package10/pokrov_1.2.0~beta.30-10_amd64.deb'
receipt={'status':'ASSEMBLED_UNSIGNED','command':sys.argv,'client_revision':build['client_revision'],'core_revision':'86aca407103daed2623df80874414ad0e94f8261','daemon_built_at':'318801a6726b5de6f8966c2a878c24531065d525','daemon_source_unchanged_at_client_revision':True,'ui_bundle_sha256':sha(r/'linux-ui-361b0e4.tar.gz'),'package_sha256':sha(out),'package_bytes':out.stat().st_size,'assembly_source_sha256':sha(r/'package-source.tar'),'packaging_source_unchanged_since':'318801a6726b5de6f8966c2a878c24531065d525','core_sha256':sha(r/'pokrov-core-health'),'daemon_sha256':sha(r/'pokrov-linuxd-health'),'python':'3.10 file_digest supplied only by retained wrapper','installed':False,'published':False}
(r/'package10-assembly.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt))
