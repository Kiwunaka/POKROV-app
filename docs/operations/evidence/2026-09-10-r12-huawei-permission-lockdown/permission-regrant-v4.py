import sys,json,time
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
nodes=ui();assert any(n.get('content-desc')=='Разрешение на VPN не выдано' for n in nodes);assert any(n.get('content-desc')=='Повторить запрос' for n in nodes)
r={'dialog_package':'com.android.vpndialogs','permission_dialog_observed':True,'denial_executed_by':'permission-regrant-v2.py before harness assertion','denial_feedback_observed':'Android ждёт разрешение на VPN; Не удалось подключиться; Повторить; Разрешить VPN','retry_explanation_sheet':True,'retry_sheet_action': 'Повторить запрос','denied_native_snapshot':'permission-denied.json'}
tap('Повторить запрос')
for _ in range(12):
 time.sleep(1);nodes=ui()
 if any(n.get('package')=='com.android.vpndialogs' and n.get('text')=='OK' for n in nodes):break
else:raise AssertionError('No repeat permission dialog')
r['grant_action']=tap('OK');time.sleep(15);s=snapshot('permission-regranted');assert s['vpn_service'] and s['foreground'] and s['tun_interfaces'];tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(5)
r['protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in (n.get('text','')+' '+n.get('content-desc','')) for n in ui());assert r['protection_confirmed'];run('shell','input','keyevent','KEYCODE_BACK');time.sleep(.5);tap('Отключить');time.sleep(4);final=snapshot('permission-final-restored');base=json.loads((ROOT/'revoke-baseline.json').read_bytes());r['restoration']={'no_service':not final['vpn_service'],'no_tun':not final['tun_interfaces'],'rules_exact':final['rules_hashes']==base['rules_hashes'],'routes_exact':final['routes_sha256']==base['routes_sha256'],'same_apk':final['apk_sha256']==base['apk_sha256'],'same_package_fields':final['package_fields']==base['package_fields'],'wifi_mobile_same':(final['wifi_on'],final['mobile_data'])==(base['wifi_on'],base['mobile_data'])};assert all(r['restoration'].values());r['status']='PASS_BOUNDED_REVOKE_DENY_REGRANT';r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'permission-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
