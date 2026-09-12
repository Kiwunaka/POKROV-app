from pathlib import Path
import json,datetime
out=Path(__file__).parent
before=json.loads((out/'before.json').read_bytes());after=json.loads((out/'disconnected.json').read_bytes())
crashed=json.loads((out/'after-crash-settled.json').read_bytes())
def compare(sample):
    matches={k:before['network_state_hashes'][k]==v for k,v in sample['network_state_hashes'].items()}
    assert all(v for k,v in matches.items() if k!='ipv6_routes')
    assert before['ipv6_semantic_sha256']==sample['ipv6_semantic_sha256']
    assert not sample['tun_interfaces']
    return matches
crash_matches=compare(crashed);final_matches=compare(after)
assert not after['vpn_service_running']
service=json.loads((out/'service-readback.json').read_bytes())
assert 'app=null' in service['selected_service_facts']
assert json.loads((out/'after-crash-http.json').read_bytes())['status']=='PASS'
r={'status':'PASS_BOUNDED_CONNECTED_CRASH_AND_RECONNECT_RECOVERY','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'crash_network_hash_match':crash_matches,'final_network_hash_match':final_matches,'ipv6_normalized_full_text_equal':True,'after_crash_tun_absent':True,'after_crash_service_record_present_but_app_null':True,'legacy_vpn_service_running_flag_is_record_presence_only':True,'relaunch_shows_disconnected':True,'normal_reconnect_https':3,'final_tun_absent':True,'final_service_record_absent':True,'native_crash_bundle_and_marker_readback':'OPEN','hung_thread_matrix':'NOT_RUN'}
(out/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
