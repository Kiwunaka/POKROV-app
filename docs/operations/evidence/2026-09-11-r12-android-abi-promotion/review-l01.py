from pathlib import Path
import hashlib,json,subprocess
root=Path('C:/r12-current-windows-source-20260911');out=Path('E:/r12-android-abi-promotion-20260911')
paths=['apps/linux_shell/README.md','config/platform-matrix.seed.json','apps/linux_shell/daemon/internal/host/support-matrix.v1.json','apps/linux_shell/daemon/internal/host/probe_linux.go','apps/linux_shell/daemon/internal/host/probe_linux_test.go','apps/linux_shell/daemon/internal/service/service_linux.go','apps/linux_shell/daemon/internal/service/service_linux_test.go','apps/linux_shell/daemon/internal/auth/peer_linux.go','apps/linux_shell/daemon/internal/auth/peer_linux_test.go','apps/linux_shell/packaging/polkit/space.pokrov.linux.policy','apps/linux_shell/packaging/install-layout.v1.json','apps/linux_shell/packaging/systemd/pokrov-linuxd.service','apps/linux_shell/test/linux_packaging_contract_test.dart','apps/linux_shell/test/linux_shell_contract_test.dart','scripts/run-tests.ps1','.github/workflows/release-v2-contract.yml']
source=json.loads((out/'source-promoted.json').read_bytes());rows=[];content={}
for path in paths:
 raw=subprocess.check_output(['git','-C',str(root),'show',source['signed_commit']+':'+path])
 assert raw==subprocess.check_output(['git','-C',str(root),'show',source['source']+':'+path])
 assert raw==subprocess.check_output(['git','-C','E:/r12client','show','HEAD:'+path])
 rows.append({'path':path,'git_blob':subprocess.check_output(['git','-C',str(root),'rev-parse',source['signed_commit']+':'+path],text=True).strip(),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)})
 content[path]=raw.decode('utf-8')
matrix=json.loads(content[paths[2]]);supported=[r for r in matrix['entries'] if r['status']=='foundation_supported'];assert len(supported)==1
row=supported[0];assert (row['distro_id'],row['version_id'],row['architecture'])==('ubuntu','24.04','amd64')
assert (row['init'],row['network_manager'],row['dns_manager'],row['firewall'])==('systemd','NetworkManager','systemd-resolved','nftables')
platforms=json.loads(content[paths[1]]);assert platforms['public_release_targets']==['android','windows'] and platforms['conditional_beta_targets']==['linux']
service=content['apps/linux_shell/daemon/internal/service/service_linux.go'];assert 'SupportsLiveConnect: false' in service and 'linux_live_connect_unavailable' in service
layout=json.loads(content['apps/linux_shell/packaging/install-layout.v1.json']);assert layout['ui_user']=='non-root' and layout['daemon_user']=='root'
assert 'space.pokrov.linux.manage' in content['apps/linux_shell/packaging/polkit/space.pokrov.linux.policy']
assert '"pkcheck"' in content['apps/linux_shell/daemon/internal/auth/peer_linux.go']
assert 'TestProbeRequiresExactFoundationMatrixAndHostStack' in content['apps/linux_shell/daemon/internal/host/probe_linux_test.go']
result={'schema':'pokrov.r12.l01-source-scope/v1','status':'PASS_SOURCE_REVIEW','signed_source':source['signed_commit'],'reviewed_tree':source['tree'],'files':rows,'source_feature_and_tested_objects_equal':True,'foundation_row':row,'public_targets':platforms['public_release_targets'],'conditional_beta_targets':platforms['conditional_beta_targets'],'current_supports_live_connect':False,'current_connect_result':'linux_live_connect_unavailable','polkit_action':'space.pokrov.linux.manage','dependency':'R12-G01 verified/I3 EXECUTION-G01-M01.md','scope_only':True,'linux_live_network_proof':False,'linux_public_release':False,'required_ci':'Existing Linux Flutter scope/packaging tests and Go host/auth/service packages on the exact reviewed tree; final run binding is separate.'}
(out/'l01-source-review.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('PASS: L01 scope review, 16 exact source objects, one Ubuntu24.04 amd64 row, conditional-only and live-connect unavailable')
