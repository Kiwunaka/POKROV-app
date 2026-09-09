import sys,json,time,re
sys.path.insert(0,'E:/r12-huawei-current-20260910')
from device import *
def switch(label):
 nodes=ui();n=next(n for n in nodes if n.get('text')==label);current=n
 while True:
  matches=[x for x in current.iter('node') if x.get('class')=='android.widget.Switch']
  if len(matches)==1:break
  current=next(p for p in nodes if current in list(p))
 x1,y1,x2,y2=map(int,re.findall(r'\d+',matches[0].get('bounds')));run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));return {'label':label,'bounds':matches[0].get('bounds'),'source':'fresh ancestor row switch'}
def state():
 svc=run('shell','dumpsys','activity','services',PACKAGE)
 return {'always_on':run('shell','settings','get','secure','always_on_vpn_app'),'lockdown':run('shell','settings','get','secure','always_on_vpn_lockdown'),'service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'foreground':'isForeground=true' in svc,'tun':sorted(x for x in run('shell','ls','/sys/class/net').split() if re.fullmatch(r'tun\d+',x))}
if __name__=='__main__':
 r={'action':switch('Постоянная VPN'),'samples':[]}
 for delay in (1,2,7):time.sleep(delay);r['samples'].append(state())
 (ROOT/'alwayson-toggle-observed.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');print(json.dumps(r));print(json.dumps([n.get('text') for n in ui() if n.get('text')]))
