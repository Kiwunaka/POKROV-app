import sys,json,time,importlib.util
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,ROOT/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
rev=load('rev','revoke-start.py');sw=load('sw','lockdown-switch.py')
audit=json.loads((ROOT/'alwayson-build/abi-package-audit.json').read_bytes());apk=next(a for a in audit['artifacts'] if a['abi']=='arm64-v8a');rev.app();s=snapshot('alwayson-updated-app');assert s['apk_sha256']==apk['sha256'];assert all(x in s['ui']['known_labels'] for x in ('Франкфурт','Только выбранные','Доступ активен'))
run('shell','am','force-stop',PACKAGE);time.sleep(1);assert not sw.state()['service'];rev.open_settings();tap('Изменить');time.sleep(.5);assert sw.state()['always_on']=='null'
r={'status':'RUNNING','source':audit['client_source'],'apk_sha256':apk['sha256'],'visible_context_retained':True,'app_forced_stopped_before_system_start':True,'samples':[]}
try:
 r['enable_action']=sw.switch('Постоянная VPN')
 for delay in (1,4,10):
  time.sleep(delay);st=sw.state();r['samples'].append(st)
 assert r['samples'][-1]['foreground'] and r['samples'][-1]['tun'],r['samples']
 rev.app();s=snapshot('alwayson-fixed-connected');r['app_observed_system_tunnel']=s['vpn_service'] and s['foreground'] and bool(s['tun_interfaces']);assert r['app_observed_system_tunnel']
 tap('Статус защиты:',contains=True);time.sleep(.5);tap('Обновить проверки');time.sleep(5);r['protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in (n.get('text','')+' '+n.get('content-desc','')) for n in ui());assert r['protection_confirmed'];run('shell','input','keyevent','KEYCODE_BACK');r['status']='PASS_SYSTEM_START_WITHOUT_APP_CONNECT';r['settings_left_for_authorized_reboot']=sw.state()
finally:
 r['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(ROOT/'alwayson-system-start-result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
 if r['status']!='PASS_SYSTEM_START_WITHOUT_APP_CONNECT':
  rev.open_settings();tap('Изменить');time.sleep(.5)
  if sw.state()['always_on']==PACKAGE:sw.switch('Постоянная VPN')
  run('shell','am','force-stop',PACKAGE);rev.app();print('Restored disabled always-on after failed check')
