import sys,json,time,importlib.util
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
sw=load('sw','lockdown-switch.py');start=load('start','lockdown-start.py');rev=load('rev','revoke-start.py')
r={'status':'RUNNING','origin':'physical Huawei shell UID 2000; not general application matrix','samples':[]}
try:
 assert any(n.get('text')=='Использовать сеть VPN?' and n.get('package')=='com.android.settings' for n in ui());r['enable_action']=tap('ВКЛЮЧИТЬ');time.sleep(2)
 st=sw.state();assert st['lockdown']=='1' and st['always_on']==PACKAGE;probe=start.http();r['samples'].append({'label':'lockdown-no-tunnel','state':st,'http':probe});assert probe['status']=='NETWORK_FAILED',probe
 rev.app();r['app_without_tun']=labels();tap('Подключить');time.sleep(18);s=snapshot('lockdown-manual-connected');r['manual_connect_native']={'service':s['vpn_service'],'foreground':s['foreground'],'tun':s['tun_interfaces']};assert s['vpn_service'] and s['foreground'] and s['tun_interfaces']
 tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(5);r['protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in (n.get('text','')+' '+n.get('content-desc','')) for n in ui());r['samples'].append({'label':'lockdown-tunnel-active','state':sw.state(),'http':start.http()});assert r['protection_confirmed']
 run('shell','input','keyevent','KEYCODE_BACK');time.sleep(.5);tap('Отключить');time.sleep(5);probe=start.http();r['samples'].append({'label':'lockdown-after-disconnect','state':sw.state(),'http':probe});assert probe['status']=='NETWORK_FAILED';r['status']='PASS_BOUNDED_LOCKDOWN_MANUAL_PATH'
finally:
 rev.open_settings();tap('Изменить');time.sleep(.5)
 if sw.state()['lockdown']=='1':sw.switch('Разрешить соединение только через VPN');time.sleep(1)
 if sw.state()['always_on']==PACKAGE:sw.switch('Постоянная VPN');time.sleep(2)
 r['settings_after_restore']=sw.state();r['http_after_restore']=start.http();rev.app();r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'lockdown-result.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r))
