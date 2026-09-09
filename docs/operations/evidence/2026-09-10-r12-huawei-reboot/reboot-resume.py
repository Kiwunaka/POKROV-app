import sys,time,json
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
a=run('shell','cmd','package','resolve-activity','--brief',PACKAGE).splitlines()[-1];assert a.startswith(PACKAGE+'/');run('shell','am','start','-n',a);time.sleep(8)
s=snapshot('reboot-app-resumed');print(json.dumps({'ui':s['ui'],'service':s['vpn_service'],'tun':s['tun_interfaces']}))
