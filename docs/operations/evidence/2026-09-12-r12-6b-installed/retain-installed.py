from pathlib import Path
import datetime,hashlib,json,re,subprocess
out=Path(__file__).parent;client=Path('E:/r12client');package=Path('C:/r12-c05-setup-privacy-20260912')
source='2aa57015783ceb3415e3be62bbf0a698729011c4';core='6b271decead88b708e2fc03984b703b0a4e63ebd'
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(name):return json.loads((out/name).read_text(encoding='utf-8-sig'))
expected=read('expected.json');baseline=read('baseline.json');installed=read('installed-before-launch.json');launched=read('installed-after-launch.json')
assert expected['client_source']==source and expected['core_source']==core
assert installed['matched_files']==launched['matched_files']==304
for key in ['state_sha256','secure_store_sha256','outbox_count']:assert baseline[key]==installed[key]==launched[key]
assert installed['service_state']=='Running' and installed['service_account']=='LocalSystem'
assert installed['ui_count']==0 and launched['ui_count']==1
traffic=read('tunnel-traffic.json');assert len(traffic['requests'])==10 and all(r['status']==204 and r['marker_valid'] for r in traffic['requests'])
assert traffic['tun_received_delta']>0 and traffic['tun_sent_delta']>0
cases=read('canary-six-results.json');assert len(cases)==6 and {r['canary_index'] for r in cases}==set(range(6))
assert all(r['core_failed_closed'] and not r['response_contains_canary'] and not r['running'] for r in cases)
before=read('scan-before.json');after=read('scan-after.json')
assert before['canary_matches']==after['canary_matches']==0
assert after['service_start_failure_occurrences']-before['service_start_failure_occurrences']==6
assert read('native-admin-payload-scan.json')['status']=='PASS_NATIVE_SUMMARY_CANARY_SCAN'
assert read('profile-restoration.json')['canary_present'] is False
assert read('canary-outbox.json')['file_count']==0 and read('canary-probe-cleanup.json')['task_probe_removed']
assert read('canary-final-recovery.json')['status']=='PASS_FINAL_GUI_DISCONNECT_RECOVERY'
assert read('canary-disconnected.json')['status']['running'] is True
for prefix in ['canary','canary-network','canary-final']:
    r=read(prefix+'-vm-result.json');assert r['status']=='PASS_VM_POWERED_OFF' and r['continuous_floor_sampled_pass'] and r['growth_budget_pass']
host=read('host-network-canary-final-after.json');assert host['routes_match_before'] and host['dns_match_before']
life=read('current-core-lifecycle.json');assert life['status']=='PASS_BOUNDED' and life['cycles']==300 and life['loopback_sessions_cancelled']==600
assert life['dll_sha256']==expected['files']['pokrov-core.dll']
ci=json.loads((package/'promotion/core-ci-main.json').read_bytes());run=ci['runs'][0]
assert run['head_sha']=='fc301b94aeafc4589cca7b6f8718129187ca3747' and run['conclusion']=='success'
steps={s['name']:s['conclusion'] for j in run['jobs'] for s in j['steps']}
required=['Test','Race-test supported runtime packages','Check release lifecycle resource ownership','Vet and race-test mobile Core event bridge','Fuzz the config and profile parser']
assert all(steps[n]=='success' for n in required)
log=(out/'core-main-test.log').read_text(encoding='utf-8-sig')
assert 'goroutines before=22 after=24; OS resources before=14 after=12' in log and 'execs: 45629' in log
assert 'WARNING: DATA RACE' not in log
artifacts=json.loads((package/'package-receipt.json').read_bytes())['artifacts']
for r in artifacts:
    p=Path(r['path']);assert p.stat().st_size==r['size'] and sha(p.read_bytes())==r['sha256']
report={'status':'PASS_BOUNDED_CURRENT_WINDOWS_INSTALL_PRIVACY_AND_C02','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'client_source':source,'core_source':core,'installer_sha256':expected['installer_sha256'],'installed_files':304,'install_state_secure_store_outbox_preserved':True,'core_lifecycle':{'status':'PASS_BOUNDED','dll_cycles':300,'session_cancellations':600,'last_twenty_handles':life['last_twenty_handle_range'],'final_handles':life['final_handles'],'file_handle_range':[min(r['types'].get('File',0) for r in life['samples']),max(r['types'].get('File',0) for r in life['samples'])],'linux_source_goroutines':[22,24],'linux_source_fd':[14,12],'fuzz_inputs':45629,'source_ci_url':run['html_url'],'steps':{n:steps[n] for n in required}},'native_secret_categories':6,'journal_files':after['file_count'],'journal_marker_matches':0,'summary_upload_case':57,'summary_ciphertext_sha256':read('canary-outbox.json')['accepted_ciphertext_sha256'],'summary_payload_files':3,'current_origin_https_requests':10,'final_gui_disconnect_recovery':'PASS','host_routes_dns_unchanged':True,'vm_snapshots_retained':13,'vm_final_power':'poweroff','vm_final_nic':'none','source_of_observer_label_0218e89':'Retained status observer executable only; installed app identity is independently bound by 304 hashes and current AOT manifest','limitations':['Windows 11 owned VM only; no current Android installed or physical-device claim','Summary profile omits events/system/crash; no fresh extended/crash acceptance from this upload','Operator step-up used the controlled owned fixture; external OIDC not retested','Initial installed VM growth budget exceeded by 192937984 bytes; final floor readback only for that initial run','Three subsequent guarded runs stayed above sampled 40GiB floor and below their growth budget','canary-disconnected.json is a failed UI action with active TUN; only canary-final-disconnected.json proves recovery','canary-state.ps1 name-only adapter count misses tun-numbered adapters; recovery uses network.ps1 full adapter detection','Secure-store byte preservation applies to installation only; normal subsequent API/diagnostic use updated it','Windows Authenticode SKIPPED_BY_OWNER; full licensing/source delivery and release remain open'],'six_artifacts_unchanged':True,'production_deploy':False,'public_release':False}
(out/'installed-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
family=client/'docs/operations/evidence/2026-09-12-r12-6b-installed';assert not family.exists();family.mkdir()
names=sorted(p.name for p in out.iterdir() if p.is_file() and p.suffix in ['.json','.py','.ps1','.log','.png'])
names += ['probe-source/main.cpp','probe-source/CMakeLists.txt']
captures=[]
for name in names:
    raw=(out/name).read_bytes()
    assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',raw),name
    p=family/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    captures.append({'path':name,'bytes':len(raw),'sha256':sha(raw)})
(family/'capture-manifest.json').write_text(json.dumps(captures,indent=2)+'\n')
(family/'.gitattributes').write_text('* -text whitespace=cr-at-eol\n*.log -whitespace\n')
(family/'README.md').write_text('''# Core6b installed Windows and lifecycle evidence — 2026-09-12

Document class: EVIDENCE. [Receipt](installed-receipt.json), [capture hashes](capture-manifest.json).
Client `2aa57015783ceb3415e3be62bbf0a698729011c4`, Core `6b271decead88b708e2fc03984b703b0a4e63ebd`.

Ordinary installer upgrade on the owned Windows 11 VM preserved app state,
secure-store bytes and empty outbox. All 304 installed files match; LocalSystem
service and ordinary UI startup pass. Ten authenticated HTTPS markers pass with
TUN traffic; initial and final GUI disconnects restore exact route/DNS hashes.

Six synthetic categories passed through current service IPC and failed closed.
Seven actual/rotated service and app sinks contain zero markers and six service
failures. Current summary preview/consent, encrypted upload to owned case 57,
worker validation, operator lookup and audited download pass with zero markers.
Step-up denial and grant replay denial pass. The controlled operator session was
revoked and prior sessions/case status preserved. The summary's three files omit
events, system and crash data; this does not renew extended/crash acceptance.

The current packaged DLL completed the existing 300-cycle start/restart/stop
fixture and cancelled 600 sessions. Last 20 handle samples and final count are
436; File handles remain 20. Exact main CI source lifecycle records goroutines
22→24, fd 14→12 and 45,629 fuzz inputs; supported race/event/backpressure tests
pass. C02 is verified/I3 for its finite original DoD. This is not unbounded
stability or full release approval.

The first VM run exceeded its 1GiB growth budget by 184MiB; only its final
40GiB floor readback is known. Forty-two completed Android intermediates were
archived on owned DE and every member verified before local relocation; all six
signed packages remain byte-identical. Three later VM runs used shutdown at
400MiB and pause at 700MiB, with 100ms free-space samples. All finished off and
within reserve. Thirteen snapshots remain, NIC is none, host route/DNS match.

`canary-disconnected.json` is retained as a failed UI action: UAC overlapped the
click and TUN stayed active. `canary-final-recovery.json` and its full native
readbacks prove the successful repeat. The old status helper's `0218e89` label
identifies that observer, not the installed app. Name-only adapter counts in
`canary-state.ps1` miss `tunN`; use `network.ps1` captures. Secure-store bytes
changed during later normal API/diagnostic activity; install preservation alone
is claimed. Synthetic helper cleanup and empty encrypted outbox pass.

Current Android installed/JNI proof, complete source/license obligations,
external OIDC, physical devices and release gates remain separate. Authenticode
is `SKIPPED_BY_OWNER`; no public release, store submission or deploy occurred.
Phone and host Hiddify were untouched.
''',encoding='utf8')
owner=client/'docs/operations/windows-release-readiness.md'
with owner.open('a',encoding='utf8') as f:f.write('''
## 2026-09-12 Core6b installed Windows acceptance

[Current installed evidence](evidence/2026-09-12-r12-6b-installed/README.md)
proves 304-file upgrade/state preservation, SCM startup, ten TUN HTTPS probes,
six native secret categories with zero journal markers, summary upload and
audited operator access, profile restoration and exact GUI disconnect recovery.
The current DLL also passed 300 lifecycle cycles/600 cancellations; exact source
race/fuzz/resource checks pass. C02 finite DoD is verified/I3. Failed VM budget
and overlapped-click attempts are retained. Full C05/V01, current Android,
licensing/source delivery and release gates remain open.
''')
print(json.dumps({'status':report['status'],'captures':len(captures),'bytes':sum(r['bytes'] for r in captures),'lifecycle':report['core_lifecycle']}))
