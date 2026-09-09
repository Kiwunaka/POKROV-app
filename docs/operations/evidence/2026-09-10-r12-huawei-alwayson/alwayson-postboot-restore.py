import sys,json,time,importlib.util
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
rev=load('rev','revoke-start.py');sw=load('sw','lockdown-switch.py')
r={'status':'RUNNING','actions':[]};before=json.loads((ROOT/'alwayson-after-unlock-result.json').read_bytes());assert before['status']=='PASS_AUTOMATIC_AFTER_REBOOT_NATIVE'
try:
 rev.app();time.sleep(3);s=snapshot('alwayson-postboot-app');assert s['foreground'] and s['tun_interfaces']
 r['actions'].append(tap('Статус защиты:',contains=True));time.sleep(.5);r['actions'].append(tap('Обновить проверки'));time.sleep(5)
 r['postboot_protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in (n.get('text','')+' '+n.get('content-desc','')) for n in ui())
 run('shell','input','keyevent','KEYCODE_BACK');assert r['postboot_protection_confirmed']
finally:
 rev.open_settings();tap('Изменить');time.sleep(.5)
 if sw.state()['lockdown']=='1':r['actions'].append(sw.switch('Разрешить соединение только через VPN'))
 if sw.state()['always_on']==PACKAGE:r['actions'].append(sw.switch('Постоянная VPN'))
 rev.app();time.sleep(1)
 if sw.state()['tun']:r['actions'].append(tap('Отключить'));time.sleep(4)
 r['final_settings']=sw.state();final=snapshot('alwayson-postboot-restored');r['checks']={'always_on_disabled':r['final_settings']['always_on']=='null','lockdown_disabled':r['final_settings']['lockdown'] in ('null','0'),'service_stopped':not final['vpn_service'],'tun_removed':not final['tun_interfaces'],'same_apk':final['apk_sha256']==before['apk_sha256'],'frankfurt_retained':'Франкфурт' in final['ui']['known_labels'],'selected_apps_retained':'Только выбранные' in final['ui']['known_labels']};r['status']='PASS_POSTBOOT_PROTECTION_AND_SETTINGS_RESTORED' if r.get('postboot_protection_confirmed') and all(r['checks'].values()) else 'CHECK_NOT_MET';r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'alwayson-postboot-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r));assert all(r['checks'].values())
