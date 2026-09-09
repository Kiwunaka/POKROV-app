import sys,time,json
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
base=json.loads((ROOT/'reboot-app-resumed.json').read_bytes());assert not base['vpn_service'] and not base['tun_interfaces'] and 'Не защищено' in base['ui']['known_labels']
assert 'Франкфурт' in base['ui']['known_labels'] and 'Только выбранные' in base['ui']['known_labels']
r={'status':'RUNNING','owner_unlocked':True,'post_boot_false_success_absent':True,'manual_reconnect':True,'actions':[tap('Подключить')]};time.sleep(15)
after=snapshot('reboot-reconnected');r['connected']=after['vpn_service'] and after['foreground'] and bool(after['tun_interfaces']);assert r['connected']
r['actions'].append(tap('Статус защиты:',contains=True));time.sleep(.5);r['actions'].append(tap('Обновить проверки'));time.sleep(5)
strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()];r['protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings);assert r['protection_confirmed']
run('shell','input','keyevent','KEYCODE_BACK');time.sleep(.5);r['actions'].append(tap('Отключить'));time.sleep(4)
final=snapshot('reboot-final-restored');prior=json.loads((ROOT/'reboot-before.json').read_bytes());r['checks']={'service_stopped':not final['vpn_service'],'tun_removed':not final['tun_interfaces'],'postboot_rules_restored':final['rules_hashes']==base['rules_hashes'],'postboot_routes_restored':final['routes_sha256']==base['routes_sha256'],'wifi_mobile_same_as_before_reboot':(final['wifi_on'],final['mobile_data'])==(prior['wifi_on'],prior['mobile_data']),'same_apk':final['apk_sha256']==prior['apk_sha256'],'same_package_fields':final['package_fields']==prior['package_fields'],'frankfurt_retained':'Франкфурт' in final['ui']['known_labels'],'selected_apps_retained':'Только выбранные' in final['ui']['known_labels']};assert all(r['checks'].values()),r['checks'];r['status']='PASS_BOUNDED_MANUAL_RECONNECT_AFTER_REBOOT';r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'reboot-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r))
