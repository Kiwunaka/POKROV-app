import sys,json,time,importlib.util
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
spec=importlib.util.spec_from_file_location('rev',ROOT/'revoke-start.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
nodes=ui();assert any(n.get('text')=='Удалить POKROV?' and n.get('package')=='com.android.settings' for n in nodes)
action=tap('УДАЛИТЬ');time.sleep(4)
rev=snapshot('permission-revoked-native',include_ui=False);base=json.loads((ROOT/'revoke-baseline.json').read_bytes());r={'action':action,'checks':{'vpn_stopped':not rev['vpn_service'],'tun_removed':not rev['tun_interfaces'],'rules_restored':rev['rules_hashes']==base['rules_hashes'],'routes_restored':rev['routes_sha256']==base['routes_sha256'],'same_apk':rev['apk_sha256']==base['apk_sha256']}};assert all(r['checks'].values());mod.app();s=snapshot('permission-revoked-app');r['honest_disconnected']='Не защищено' in s['ui']['known_labels'];r['reconnect_available']='Подключить' in s['ui']['known_labels'];assert r['honest_disconnected'] and r['reconnect_available'];(ROOT/'permission-revoked.json').write_text(json.dumps(r,indent=2)+'\n');tap('Подключить');time.sleep(2)
allowed=['POKROV','Запрос','подключ','ОК','OK','ОТМЕНА','Разрешить','VPN','Продолжить']
print(json.dumps([{'text':n.get('text'),'desc':n.get('content-desc'),'bounds':n.get('bounds'),'package':n.get('package')} for n in ui() if any(x in (n.get('text','')+' '+n.get('content-desc','')) for x in allowed)],ensure_ascii=True));print(json.dumps(r))
