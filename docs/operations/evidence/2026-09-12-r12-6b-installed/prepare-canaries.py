from pathlib import Path
import subprocess,json,hashlib
out=Path(__file__).parent;prior=Path('C:/r12-v01-native-20260910');src=out/'probe-source';src.mkdir(exist_ok=True)
source='2aa57015783ceb3415e3be62bbf0a698729011c4';root=Path('E:/r12client')
files=['service_client.cpp','service_pipe_client.cpp','service_protocol.cpp','service_profile_identity.cpp','service_client.h','service_protocol.h']
rows=[]
for name in files:
    rel='apps/windows_shell/windows/service/'+name;p=root/rel
    current=p.read_bytes();committed=subprocess.check_output(['git','-C',str(root),'show',source+':'+rel])
    assert current.replace(b'\r\n',b'\n')==committed.replace(b'\r\n',b'\n')
    rows.append({'path':rel,'sha256':hashlib.sha256(current).hexdigest()})
text=(prior/'probe-source/main.cpp').read_text().replace('r12v01-20260910','r126b-20260912').replace('203.0.113.197','203.0.113.198')
(src/'main.cpp').write_text(text)
text=(prior/'probe-source/CMakeLists.txt').read_text().replace('E:/r12-diagnostics-canvas-source-20260910','E:/r12client').replace('r12_v01_probe','r12_v01_probe_6b')
(src/'CMakeLists.txt').write_text(text)
text=(prior/'scan-sinks.ps1').read_text().replace('r12v01-20260910','r126b-20260912').replace('203.0.113.197','203.0.113.198')
(out/'scan-sinks.ps1').write_text(text)
(out/'probe-source-binding.json').write_text(json.dumps({'status':'PASS_EXACT_CURRENT_SERVICE_CLIENT_SOURCES','source_client':source,'source_core':'6b271decead88b708e2fc03984b703b0a4e63ebd','files':rows,'fixture':'Six synthetic unknown outbound types, actual protected service IPC, no real secrets in inputs'},indent=2)+'\n')
print('PASS current service-client sources bound to canary fixture')
