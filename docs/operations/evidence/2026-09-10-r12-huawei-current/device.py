from pathlib import Path
import datetime,hashlib,json,re,subprocess,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent
ADB='E:/POKROV-workspace-cache/android-sdk/platform-tools/adb.exe';SERIAL='2UCUT24716017005';PACKAGE='space.pokrov.pokrov_android_shell'
def run(*args,timeout=30):return subprocess.check_output([ADB,'-s',SERIAL,*args],text=True,encoding='utf8',timeout=timeout).strip()
def ui():
 raw=run('exec-out','uiautomator','runtest','/system/framework/android.test.base.jar','r12-tree.jar','-c','R12Tree');start=raw.find('<?xml');end=raw.rfind('</hierarchy>')+len('</hierarchy>');assert start>=0 and end>start
 return list(ET.fromstring(raw[start:end]).iter('node'))
def tap(label,contains=False):
 nodes=[n for n in ui() if any((label in n.get(k,'') if contains else label==n.get(k,'')) for k in ('text','content-desc'))]
 assert len(nodes)==1,{'target':label,'matches':len(nodes)}
 x1,y1,x2,y2=map(int,re.findall(r'\d+',nodes[0].get('bounds')))
 run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
 return {'target':label,'bounds':nodes[0].get('bounds'),'derived_from':'fresh UI tree'}
def labels():
 nodes=ui();strings=[n.get('text','')+' '+n.get('content-desc','') for n in nodes]
 vocabulary=['Подключить','Отключить','Не защищено','Защищено','Частичная защита','Защита подтверждена','Проверка пройдена','Статус защиты','Главная','Профиль','Правила','Локации','Варшава','Франкфурт','Милан','Срок доступа','Доступ активен','Нет доступа','Россия напрямую','Все приложения','Только выбранные','WARP','Мой аккаунт','Подключение','Обновить','Проверить','Туннель','DNS','VPN','Войти','Купить','Завершить','Продолжить','Доступ к сети','Приложение']
 return {'known_labels':[s for s in vocabulary if any(s in value for value in strings)],'node_count':len(nodes),'packages':sorted(set(n.get('package','') for n in nodes))}
def snapshot(label,include_ui=True):
 rules=run('shell','ip','rule','show');routes=run('shell','ip','route','show','table','all');svc=run('shell','dumpsys','activity','services',PACKAGE);pkg=run('shell','dumpsys','package',PACKAGE);path=run('shell','pm','path',PACKAGE).split(':',1)[1]
 data={'label':label,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'apk_sha256':run('shell','sha256sum',path).split()[0],'apk_bytes':int(run('shell','stat','-c','%s',path)),'device_model':run('shell','getprop','ro.product.model'),'android_release':run('shell','getprop','ro.build.version.release'),'sdk':run('shell','getprop','ro.build.version.sdk'),'pid':run('shell','pidof',PACKAGE) if re.search('ServiceRecord',svc) else None,'package_fields':{key:re.search(r'\b'+key+r'=([^\n]+)',pkg).group(1).strip() for key in ('versionCode','versionName','primaryCpuAbi','firstInstallTime','lastUpdateTime')},'vpn_service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'foreground':'isForeground=true' in svc,'rules_hashes':sorted(hashlib.sha256(x.encode()).hexdigest() for x in rules.splitlines()),'routes_sha256':hashlib.sha256(routes.encode()).hexdigest(),'tun_interfaces':sorted(x for x in run('shell','ls','/sys/class/net').split() if re.fullmatch(r'tun\d+',x)),'wifi_on':run('shell','settings','get','global','wifi_on'),'mobile_data':run('shell','settings','get','global','mobile_data'),'ui':labels() if include_ui else None}
 target=ROOT/(label+'.json');assert not target.exists();target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8');return data
if __name__=='__main__':
 import sys
 print(json.dumps(snapshot(sys.argv[1])))
