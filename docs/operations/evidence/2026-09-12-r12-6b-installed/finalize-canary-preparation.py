from pathlib import Path
import hashlib,json,re,subprocess
out=Path(__file__).parent;root=Path('E:/r12client');base=root/'apps/windows_shell/windows/service'
source='2aa57015783ceb3415e3be62bbf0a698729011c4'
names=set(re.findall(r'\$\{SOURCE\}/([^" ]+)',(out/'probe-source/CMakeLists.txt').read_text()))
todo=list(names)
while todo:
    name=todo.pop()
    for header in re.findall(r'^#include "([^"]+)"', (base/name).read_text(),re.M):
        if header not in names:names.add(header);todo.append(header)
rows=[]
for name in sorted(names):
    path=base/name;rel=path.relative_to(root).as_posix();raw=path.read_bytes()
    committed=subprocess.check_output(['git','-C',str(root),'show',source+':'+rel])
    assert raw.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
    rows.append({'path':rel,'sha256':hashlib.sha256(raw).hexdigest()})
exe=out/'probe-build/Release/r12_v01_probe_6b.exe';digest=hashlib.sha256(exe.read_bytes()).hexdigest()
report={'status':'PASS_EXACT_CURRENT_CANARY_HELPER_INPUTS','source_client':source,'source_core':'6b271decead88b708e2fc03984b703b0a4e63ebd','files':rows,'helper':{'path':str(exe),'size':exe.stat().st_size,'sha256':digest},'fixture':'Six synthetic unknown outbound types using installed protected service IPC; only synthetic secrets'}
(out/'probe-source-binding.json').write_text(json.dumps(report,indent=2)+'\n')
prior=Path('C:/r12-v01-native-20260910');guest='C:/Users/Public/R126b20260912'
state=(prior/'state.ps1').read_text().replace('C:/Users/Public/R12DiagnosticsCanvas',guest).replace('C:/Users/Public/R12V01Native',guest)
(out/'canary-state.ps1').write_text(state)
prepare=(prior/'prepare-elevated.ps1').read_text().replace('C:/Users/Public/R12V01Native',guest).replace('r12_v01_probe.exe','r12_v01_probe_6b.exe').replace('state.ps1','canary-state.ps1').replace('8A526FA90284AAC6AAA050EB0F1F30E70A39AC3DA82D0AEFE33C59109BFE9337',digest.upper())
(out/'prepare-elevated.ps1').write_text(prepare)
after=(prior/'after-elevated.ps1').read_text().replace('C:/Users/Public/R12V01Native',guest).replace('state.ps1','canary-state.ps1')
(out/'after-elevated.ps1').write_text(after)
print(json.dumps({'status':report['status'],'current_source_inputs':len(rows),'helper_sha256':digest,'helper_bytes':exe.stat().st_size}))
