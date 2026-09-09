import sys,json,time
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
assert '--owner-confirmed-unlock' in sys.argv
before=json.loads((ROOT/'alwayson-reboot-start.json').read_bytes())
assert run('shell','getprop','sys.boot_completed')=='1'
s=snapshot('alwayson-after-unlock-native',include_ui=False)
r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'owner_confirmed_unlock':True,'app_activity_launched_by_runner':False,'new_boot':hashlib.sha256(run('shell','cat','/proc/sys/kernel/random/boot_id').encode()).hexdigest()!=before['boot_id_sha256'],'apk_sha256':s['apk_sha256'],'always_on':run('shell','settings','get','secure','always_on_vpn_app'),'lockdown':run('shell','settings','get','secure','always_on_vpn_lockdown'),'service':s['vpn_service'],'foreground':s['foreground'],'tun':s['tun_interfaces']}
r['status']='PASS_AUTOMATIC_AFTER_REBOOT_NATIVE' if all((r['new_boot'],r['apk_sha256']==before['apk_sha256'],r['always_on']==PACKAGE,r['service'],r['foreground'],bool(r['tun']))) else 'OBSERVED_REBOOT_GATE_NOT_MET'
(ROOT/'alwayson-after-unlock-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
