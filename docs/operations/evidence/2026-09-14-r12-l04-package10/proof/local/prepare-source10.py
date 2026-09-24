from pathlib import Path
import subprocess,tarfile,hashlib,json
r=Path(__file__).parent;client=Path('E:/r12client');revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=client,text=True).strip();assert revision.startswith('361b0e4')
with tarfile.open('C:/r12-l04-ui-poll-20260911/linux-client-aa08746.tar.gz') as tar:paths=[m.name.removeprefix('client/') for m in tar if m.isfile()]
assert all(p.startswith(('apps/linux_shell/','packages/','config/')) for p in paths)
changed=[p for p in subprocess.check_output(['git','diff','--name-only','aa0874615e2ccdd4213df9f72dfd9a994979edef',revision,'--','packages','apps/linux_shell'],cwd=client,text=True).splitlines() if '/lib/' in p or p.startswith('apps/linux_shell/linux/')];assert changed and all(p in paths for p in changed)
out=r/'linux-client-361b0e4.tar.gz'
if not out.exists():subprocess.run(['git','archive','--format=tar.gz','--prefix=client/','--output='+str(out),revision,'--',*paths],cwd=client,check=True)
with tarfile.open(out) as tar:
 for p in changed:assert tar.extractfile('client/'+p).read().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',revision+':'+p],cwd=client).replace(b'\r\n',b'\n'),p
v={'client_revision':revision,'source_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_bytes':out.stat().st_size,'source_files':len(paths),'changed_source_files':len(changed),'scope':'same source list as prior Linux UI build; exact committed fix'};(r/'source10.json').write_text(json.dumps(v,indent=2));print(json.dumps(v))
