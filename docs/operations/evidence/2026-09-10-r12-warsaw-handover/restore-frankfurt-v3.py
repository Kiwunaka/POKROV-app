from device import *
import time
r={'status':'RUNNING','selection_restored_to_frankfurt':True,'reason':'selected location is Frankfurt; home still reports last applied Warsaw until reconnect'}
tap('Защита',contains=True);time.sleep(.5);tap('Подключить');time.sleep(20)
after=snapshot('frankfurt-restored-connected');r['frankfurt_home_visible']='Франкфурт' in after['ui']['known_labels'];assert r['frankfurt_home_visible']
tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(5)
strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()];r['protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings);assert r['protection_confirmed']
run('shell','input','keyevent','KEYCODE_BACK');time.sleep(.5);tap('Отключить');time.sleep(5)
final=snapshot('warsaw-final-restored');initial=json.loads((ROOT/'initial.json').read_bytes());r['checks']={'frankfurt_home_visible':'Франкфурт' in final['ui']['known_labels'],'selected_apps_visible':'Только выбранные' in final['ui']['known_labels'],'vpn_off':not final['vpn_service'],'no_tun':not final['tun_interfaces'],'routes_exact_restore':final['routes_sha256']==initial['routes_sha256'],'same_apk':final['apk_sha256']==initial['apk_sha256'],'wifi_mobile_unchanged':(final['wifi_on'],final['mobile_data'])==(initial['wifi_on'],initial['mobile_data'])};assert all(r['checks'].values());r['status']='PASS_RESTORED_WITH_OS_NETWORK_ID_CHANGE';r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'warsaw-final-restoration.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
