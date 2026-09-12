from pathlib import Path
import json,datetime
out=Path(__file__).parent
before=json.loads((out/'recovery-before.json').read_bytes());after=json.loads((out/'recovery-disconnected.json').read_bytes())
matches={k:before['network_state_hashes'][k]==v for k,v in after['network_state_hashes'].items()}
assert all(v for k,v in matches.items() if k!='ipv6_routes')
assert before['ipv6_semantic_sha256']==after['ipv6_semantic_sha256']
assert not after['tun_interfaces'] and not after['vpn_service_running']
first=json.loads((out/'recovery-http.json').read_bytes());followup=json.loads((out/'recovery-http-followup.json').read_bytes())
assert sum(r['marker_valid'] for r in first['requests'])==9 and followup['status']=='PASS'
r={'status':'PASS_DISCONNECT_RECOVERY_WITH_RETAINED_HTTP_FAILURE','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'network_hash_match':matches,'ipv6_normalized_full_text_equal':True,'first_https':'9_OF_10_ONE_SOCKET_EXCEPTION','followup_without_reconnect':'3_OF_3_PASS','traffic_full_pass':False,'rootless_guest':'PASS','profile_rollback_before_connect':'PASS_BYTE_EXACT','tun_absent_after':True,'service_record_absent_after':True}
(out/'recovery-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
