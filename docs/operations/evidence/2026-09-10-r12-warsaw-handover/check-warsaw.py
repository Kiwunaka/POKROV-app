from device import *
import time
act=tap('После выбора, Белые списки');time.sleep(1);tap('Защита',contains=True);time.sleep(1)
before=snapshot('warsaw-before-connect');assert not before['vpn_service']
act2=tap('Подключить');time.sleep(25)
after=snapshot('warsaw-connected');tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(6)
strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()]
terms=['Защита работает','выход через VPN подтверждены','Выход через VPN не подтверждён','DNS','Туннель','Проверка не прошла','Частичная защита','Интернет недоступен','Подключено','Маршруты назначены','Не удалось']
r={'status':'OBSERVED','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'apk_sha256':after['apk_sha256'],'selection_action':act,'connect_action':act2,'native_service':after['vpn_service'],'foreground':after['foreground'],'tun':after['tun_interfaces'],'known_status_phrases':[w for w in terms if any(w in s for s in strings)],'protection_confirmed':any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings)}
(ROOT/'warsaw-protection.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r))
