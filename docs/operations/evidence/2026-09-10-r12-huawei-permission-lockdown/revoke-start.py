import sys,time,json,re
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
def open_settings():
 run('shell','am','start','-a','android.settings.VPN_SETTINGS');time.sleep(.7)
 nodes=ui()
 if not any(n.get('text')=='POKROV' for n in nodes):run('shell','input','keyevent','KEYCODE_BACK');time.sleep(.5);nodes=ui()
 n=next(n for n in nodes if n.get('text')=='POKROV');x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')));x=str((x1+x2)//2);y=str((y1+y2)//2);run('shell','input','swipe',x,y,x,y,'1000');time.sleep(.5)
def app():
 activity=run('shell','cmd','package','resolve-activity','--brief',PACKAGE).splitlines()[-1];assert activity.startswith(PACKAGE+'/');run('shell','am','start','-n',activity);time.sleep(2)
if __name__=='__main__':
 app();base=snapshot('revoke-baseline');assert not base['vpn_service'];tap('Подключить');time.sleep(15);s=snapshot('revoke-connected');assert s['vpn_service'] and s['foreground'];open_settings();tap('Удалить');time.sleep(.5)
 print(json.dumps([{'text':n.get('text'),'desc':n.get('content-desc'),'bounds':n.get('bounds')} for n in ui() if n.get('text') or n.get('content-desc')],ensure_ascii=True))
