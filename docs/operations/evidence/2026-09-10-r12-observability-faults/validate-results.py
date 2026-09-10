from pathlib import Path
import datetime, json
out=Path(__file__).parent
read=lambda n:json.loads((out/n).read_text(encoding='utf-8-sig'))
before=read('network-before-valid.json');after=read('network-disconnected.json')
traffic=read('tunnel-traffic-full.json');full=read('disk-full.json')
checks={
 'isolated_volume_32_mib':read('volume-created.json')['disk_size_bytes']==33554432,
 'actual_windows_disk_full':full['probe_error_win32']==112 and full['remaining_bytes']==0,
 'system_volume_not_full':full['system_free_bytes']>1024**3,
 'same_installed_304_before_after':all(read(n)['matched_files']==304 and read(n)['different']==0 and read(n)['missing']==0 and read(n)['client_source']=='6816aaba1e9526ba84182d8b13ecd20569e37d23' for n in ['installed-before.json','installed-final.json']),
 'ui_visible_while_volume_full':read('diskfull-ui.json')['visible_window_count']==1 and read('diskfull-ui.json')['volume_free_bytes']==0,
 'operational_log_could_not_grow':any(f['Name']=='operational-events.v1.0.jsonl' and f['Length']==0 for f in read('diskfull-ui.json')['files']),
 'connected_runtime_verified':all(all(traffic[s][k] for k in ['running','core_ready','dns_ready','egress_validated','effective_matches_staged']) for s in ['before','after']),
 'ten_https_markers':len(traffic['requests'])==10 and all(r['status']==204 and r['marker_valid'] for r in traffic['requests']),
 'positive_tun_counters':traffic['tun_received_delta']>0 and traffic['tun_sent_delta']>0,
 'original_journals_preserved_during_traffic':read('storage-during-tunnel.json')['original_diagnostic_hashes_match'] and read('storage-during-tunnel.json')['volume_free_bytes']==0,
 'exact_routes_dns_recovered':before['routes_sha256']==after['routes_sha256'] and before['dns_sha256']==after['dns_sha256'],
 'disconnected_without_tun':not after['status']['running'] and not any(a['is_pokrov_tun'] for a in after['adapters']),
 'outside_https_recovered':after['http_status']==204 and after['marker_valid'],
 'original_two_journals_restored':read('storage-restored.json')['original_diagnostic_hashes_match'] and read('storage-restored.json')['preserved_files']==2,
 'fixture_volume_detached':not read('volume-detached.json')['image_attached'] and not read('volume-detached.json')['drive_r_present'],
 'vm_baseline_restored':read('vm-restoration.json')['state']=='poweroff' and read('vm-restoration.json')['nic1']=='none',
 'defender_unchanged':read('defender-final.json')['defender_detection_or_action_count']==0 and all(read('defender-final.json')['protection'].values()),
 'corrupt_and_schema_harness':read('corrupt-schema.json')['status']=='PASS',
 'queue_storm_harness':read('queue-storm.json')['status']=='PASS' and read('queue-storm.json')['queue_depth']==4096 and read('queue-storm.json')['dropped']==15904,
 'clock_harness':read('clock-jumps.json')['status']=='PASS',
 'http_timeout_harness':read('http-upload-timeout.json')['status']=='PASS' and read('http-upload-timeout.json')['http_chunk_timeouts']==3,
 'exact_source_packages':len(read('harness-binding.json')['resolved_packages'])==5 and read('harness-binding.json')['source_package_diff']=='NONE',
}
assert all(checks.values()),checks
r={'status':'PASS_BOUNDED_V03_FAULTS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'source':'6816aaba1e9526ba84182d8b13ecd20569e37d23','checks':checks,
 'limits':['Actual disk exhaustion is limited to the isolated diagnostic volume; the system/account volume remains writable.',
 'Clock changes are injected into the Dart diagnostic clock; the OS clock is not changed.',
 'Queue, corrupt/schema and HTTP timeout runs are current-source harnesses, not installed Android/Win10 or real user/provider traffic.',
 'The upload case proves retention of one encrypted envelope; total accumulated support-outbox capacity is not proven.',
 'TUN byte counters include ambient traffic; exact per-request attribution and geolocation are not claimed.',
 'No durable fault-period local timeline can be recovered from the full volume; memory behavior has separate source evidence.']}
(out/'validation.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8')
print(json.dumps({'status':r['status'],'checks':len(checks)}))
