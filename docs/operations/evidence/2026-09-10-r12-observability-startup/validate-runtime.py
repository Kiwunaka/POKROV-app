from pathlib import Path
import json,datetime
out=Path(__file__).parent
read=lambda n:json.loads((out/n).read_text(encoding='utf-8-sig'))
installed=read('wizard-readback.json');final=read('installed-final.json')
before=read('network-before.json');after=read('network-disconnected.json')
traffic=read('tunnel-traffic-fault.json');timeline=read('timeline-restored.json')['events']
source=read('source-promoted.json')['signed_commit']
checks={
 'old_package_window_absent':read('old-package-fault-final.json')['visible_window_count']==0 and read('old-package-fault-final.json')['seconds_since_process_start']>=30,
 'fixed_package_window_present_with_same_fault':read('fixed-package-fault.json')['visible_window_count']==1,
 'installed_304_match':installed['matched_files']==304 and not installed['missing'] and not installed['different'],
 'session_secure_store_preserved_after_install':installed['state_preserved'] and installed['secure_store_preserved'],
 'installed_service_running':installed['service_state']=='Running' and final['service_state']=='Running',
 'final_304_match':final['matched_files']==304 and final['missing']==0 and final['different']==0,
 'fixture_and_original_hashes_unchanged_during_traffic':read('storage-during-tunnel.json')['status']=='PASS',
 'ten_https_markers':len(traffic['requests'])==10 and all(x['status']==204 and x['marker_valid'] for x in traffic['requests']),
 'positive_tun_counters':traffic['tun_received_delta']>0 and traffic['tun_sent_delta']>0,
 'fresh_effective_proof':all(all(traffic[s][k] for k in ['running','core_ready','dns_ready','egress_validated','effective_matches_staged']) for s in ['before','after']),
 'exact_route_dns_recovery':before['routes_sha256']==after['routes_sha256'] and before['dns_sha256']==after['dns_sha256'],
 'disconnected_no_tun':not after['status']['running'] and not any(a['is_pokrov_tun'] for a in after['adapters']),
 'outside_https_after_disconnect':after['http_status']==204 and after['marker_valid'],
 'original_journal_hashes_restored':read('storage-restored.json')['status']=='PASS',
 'persistence_resumed_after_restore':len(timeline)>=4 and any(e['name']=='app.bootstrap.ui_ready.finished' and e['outcome']=='succeeded' for e in timeline),
 'restored_records_exact_build':all(e['git_revision']==source and e['build_number']=='4053' for e in timeline),
 'vm_baseline_restored':read('vm-restoration.json')['status']=='PASS',
 'defender_enabled_no_new_detections':read('defender-final.json')['defender_detection_or_action_count']==0 and all(read('defender-final.json')['protection'].values()),
}
assert all(checks.values()),checks
r={'status':'PASS_BOUNDED_STORAGE_FAILURE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'checks':checks,'retained_original_files':2,'tun_delta_bytes_each':traffic['tun_received_delta'],'limits':['An actual path conflict is tested; this does not substitute for disk-full, clock-jump, event-storm, upload-timeout or full Android/Win10 acceptance.','Fault-period events exist only in memory; no invented durable timeline. After restoration four bootstrap records were captured.','Connection counters include ambient traffic and do not identify per-request traffic.','The lab stopped the disconnected UI process to restore files; this is not user-tray-exit proof.','Initial network-connecting snapshot straddles route application; steady network-connected and traffic proof are the accepted observations.']}
(out/'runtime-validation.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8')
print(json.dumps(r))
