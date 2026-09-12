from pathlib import Path
import datetime,json
out=Path(__file__).parent
def read(name):return json.loads((out/(name+'.json')).read_text(encoding='utf-8-sig'))
installed=read('installed');assert installed['preferences_unchanged'] and installed['uid_preserved']
before=read('precrash-observability');dead=read('crashed-observability');after=read('relaunched-observability');final=read('final-observability')
assert before['app_pid']==read('crash')['old_app_pid'] and dead['app_pid'] is None
assert before['marker']==dead['marker'] and before['marker']['state']=='active'
assert after['marker']['run_id_sha256']!=before['marker']['run_id_sha256']
oldids={r['event_id_sha256'] for r in before['current_source_events']}
assert oldids and oldids<={r['event_id_sha256'] for r in dead['current_source_events']}
assert oldids<={r['event_id_sha256'] for r in after['current_source_events']}
detected=[r for r in after['current_source_events'] if r['run_id_sha256']==after['marker']['run_id_sha256'] and r['name']=='app.previous_exit.detected']
assert len(detected)==1 and detected[0]['error_code']=='APP-BOOT-006'
assert any(r['name'].startswith('app.connection.') for r in before['current_source_events'])
assert all(r['build_number']=='4053' for r in final['current_source_events'])
baseline=read('baseline');crashed=read('after-crash');disconnected=read('disconnected')
for current in [crashed,disconnected]:
    assert not current['tun_interfaces']
    assert current['ipv6_semantic_sha256']==baseline['ipv6_semantic_sha256']
    assert all(v==current['network_state_hashes'][k] for k,v in baseline['network_state_hashes'].items() if k!='ipv6_routes')
assert not disconnected['vpn_service_running']
freeze=read('freeze');assert freeze['resumed'] and freeze['same_process_after_resume'] and 15<=freeze['freeze_seconds']<20
assert read('reconnected-observability')['marker']==read('afterfreeze-observability')['marker']
for name in ['before-crash-http','after-crash-http','reconnected-http','after-freeze-http','final-http']:
    probe=read(name);assert probe['status']=='PASS' and len(probe['requests'])==3
assert read('before-freeze')['tun_interfaces']==read('after-freeze')['tun_interfaces']
result={'status':'PASS_BOUNDED_CURRENT_PROCESS_CRASH_MARKER_AND_RECOVERY','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':installed['source_client'],'source_core':installed['source_core'],'installed_apk_sha256':installed['after_apk_sha256'],'retained_precrash_event_count':len(oldids),'final_current_source_event_count':len(final['current_source_events']),'recognized_previous_exit_error':'APP-BOOT-006','previous_exit_kind':'unclean','native_crash_did_not_invoke_dart_handler':True,'crash_index_or_CRASH_001_proof':False,'rooted_lab':True,'physical_arm64_proof':False,'freeze':{'method':'SIGSTOP/SIGCONT whole own process','seconds':freeze['freeze_seconds'],'probe_observation':'15 second harness TimeoutExpired; no HTTP result produced before resume','probe_success_while_frozen':False,'post_resume_https_pass':3,'same_process_and_marker':True,'ANR_classification_proven':False},'network_recovery':'IPv4 and DNS exact; IPv6 equal after normalizing only observed expiry countdown','crashed_service_record':'Record presence is not live process: marker observer confirms app PID absent; final disconnect record absent','harness_limits':['The first three observability snapshots skipped files due to adb su argument quoting; their zero current-source event counts are not product evidence. Corrected precrash/crashed/relaunched/final snapshots read both bounded journal files.','The freeze probe exceeded the harness timeout; finally resumed the same PID. No full leak or ANR claim is made.'],'root_restoration':'VERIFY_SEPARATE_ROOTLESS_BOOT_RECEIPT','crash_bundle_delivery':'NOT_PROVEN_BY_THIS_SLICE'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['freeze','harness_limits']}))
