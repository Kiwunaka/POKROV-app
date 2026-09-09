import sys,json,time,importlib.util
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
spec=importlib.util.spec_from_file_location('rev',ROOT/'revoke-start.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
def http():return json.loads(run('shell','CLASSPATH=/data/local/tmp/r12-http.jar','app_process','/system/bin','R12Http',timeout=20))
if __name__=='__main__':
 s=snapshot('lockdown-baseline');assert not s['vpn_service'];probe=http();assert probe['http_status']==200,probe
 (ROOT/'lockdown-http-baseline.json').write_text(json.dumps({'probe_uid':run('shell','id','-u'),'probe':probe},indent=2)+'\n');mod.open_settings();tap('Изменить');time.sleep(.5);tap('Постоянная VPN');time.sleep(10)
 s=snapshot('alwayson-enabled',include_ui=False);r={'always_on':run('shell','settings','get','secure','always_on_vpn_app'),'lockdown':run('shell','settings','get','secure','always_on_vpn_lockdown'),'service':s['vpn_service'],'foreground':s['foreground'],'tun':s['tun_interfaces'],'known_settings_labels':[n.get('text') for n in ui() if n.get('text')]};(ROOT/'alwayson-enabled-settings.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r))
