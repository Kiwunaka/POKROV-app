import sys,json
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
print(json.dumps({'boot_completed':run('shell','getprop','sys.boot_completed'),'known_ui':labels()}))
s=snapshot('reboot-after-unlock');before=json.loads((ROOT/'reboot-start.json').read_bytes());r={'new_boot':hashlib.sha256(run('shell','cat','/proc/sys/kernel/random/boot_id').encode()).hexdigest()!=before['boot_id_sha256'],'before_app_launch_service':s['vpn_service'],'before_app_launch_tun':s['tun_interfaces'],'owner_unlocked':True,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()};(ROOT/'reboot-after-boot.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
