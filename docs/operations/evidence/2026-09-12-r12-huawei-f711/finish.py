from device import *
import shutil
restoration=json.loads((ROOT/'final-restoration.json').read_bytes())
assert all(restoration['checks'].values())
assert all(json.loads((ROOT/'forced-stop-result.json').read_bytes())['checks'].values())
assert json.loads((ROOT/'profile-ui-preserved.json').read_bytes())['all_visible_text_same']
assert json.loads((ROOT/'install-result.json').read_bytes())['status']=='PASS'
assert run('shell','sha256sum',run('shell','pm','path',PACKAGE).removeprefix('package:')).split()[0]=='78d7a1361d03d808c6f6554fb65bc7411a9b411ed436c6ccbf79114d13737c91'
probe=Path('E:/r12-huawei-current-20260910/r12-http.jar')
remote_probe=run('shell','sha256sum','/data/local/tmp/r12-http.jar').split()[0]
assert hashlib.sha256(probe.read_bytes()).hexdigest()==remote_probe
save('http-helper-binding',{'jar_sha256':remote_probe,'source_sha256':hashlib.sha256(Path('E:/r12-huawei-current-20260910/R12Http.java').read_bytes()).hexdigest(),'url':'https://pokrov.space/__build.json','payload_exported':False})
processes=run('shell','ps','-A')
assert not any(x in processes for x in ('UiTreeProbe','R12Http'))
save('result',{'status':'PASS_BOUNDED_PHYSICAL_ARM64_INSTALL_AND_RECOVERY','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_client':'f7115c505c314a7322481997a46343b03dae1127','source_core':'6b271decead88b708e2fc03984b703b0a4e63ebd','installed_apk_sha256':'78d7a1361d03d808c6f6554fb65bc7411a9b411ed436c6ccbf79114d13737c91','device_model':'ADA-AL00U','sdk':31,'abi':'arm64-v8a','same_version_update':True,'same_signer_uid_first_install_time':True,'visible_profile_text_hashes_exact':True,'access_active_after_update':True,'ordinary_connect_reconnect':True,'background_resume':True,'force_stop_cleanup_https':True,'cold_reconnect_protection':True,'final_network_exact_restored':True,'final_vpn':'OFF','final_wifi_mobile':'ON_UNCHANGED','final_always_on_lockdown':'OFF_UNCHANGED','final_https':'3/3 HTTP200','observer_processes_remaining':False,'disk_free_bytes':{x:shutil.disk_usage(x+':/').free for x in ('C','E')},'limits':['Local adb install -r at version4053; no distribution channel or successor version test.','Only Huawei API31 ARM64; no other OEM/API matrix.','No current Wi-Fi/LTE handoff, IPv6-only/NAT64, MTU, UDP53, captive portal, reboot, Doze or battery run.','Force-stop is not native uncaught crash, Dart CRASH-001 or ANR proof.','UI hash comparison and continuing access prove visible state only; private secure-storage bytes were not read.','Initial old UI helper lacked active root on the app; direct accessibility observer succeeded. Initial SDK ADB server handover briefly had no device; no installation occurred then.']})
print('PASS_PHYSICAL_ARM64_FINAL_RESTORATION')
