import sys,time,json
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
print(json.dumps(labels()))
tap('Подключить');time.sleep(15)
tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(5)
strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()]
assert any('Туннель, DNS и выход через VPN подтверждены' in x for x in strings)
run('shell','input','keyevent','KEYCODE_BACK')
a=snapshot('reboot-before');assert a['vpn_service'] and a['foreground'] and a['tun_interfaces'] and 'Франкфурт' in a['ui']['known_labels']
b={'boot_id_sha256':hashlib.sha256(run('shell','cat','/proc/sys/kernel/random/boot_id').encode()).hexdigest(),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'protection_confirmed_before':True}
(ROOT/'reboot-start.json').write_text(json.dumps(b,indent=2)+'\n');print(json.dumps(b));run('reboot');print('REBOOT_SENT')
