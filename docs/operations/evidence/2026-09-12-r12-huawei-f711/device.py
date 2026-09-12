from pathlib import Path
import datetime,hashlib,json,re,subprocess,sys,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parent
ADB='E:/POKROV-workspace-cache/android-sdk/platform-tools/adb.exe'
PACKAGE='space.pokrov.pokrov_android_shell'
devices=subprocess.check_output([ADB,'devices'],text=True,timeout=20)
serials=re.findall(r'^(\S+)\s+device$',devices,re.M)
assert len(serials)==1 and not serials[0].startswith('emulator-')
SERIAL=serials[0]
def run(*args,timeout=35):
 return subprocess.check_output([ADB,'-s',SERIAL,*args],timeout=timeout).decode('utf8').strip()
assert run('shell','getprop','ro.product.model')=='ADA-AL00U'
def save(name,value):
 path=ROOT/(name+'.json');assert not path.exists(),name
 path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def digest(text):return hashlib.sha256(text.encode()).hexdigest()
def ui():
 raw=run('shell','env','CLASSPATH=/data/local/tmp/r12-huawei-f711-20260912/ui.dex','app_process','/data/local/tmp/r12-huawei-f711-20260912','UiTreeProbe')
 start=raw.find('<?xml');end=raw.rfind('</hierarchy>')+12
 assert start>=0 and end>start
 return list(ET.fromstring(raw[start:end]).iter('node'))
def labels(nodes):
 values=[n.get('text','')+' '+n.get('content-desc','') for n in nodes]
 vocab=['Подключить','Отключить','Не защищено','Защищено','Частичная защита','Защита подтверждена','Проверка пройдена','Статус защиты','Главная','Профиль','Правила','Локации','Варшава','Франкфурт','Милан','Срок доступа','Доступ активен','Нет доступа','Россия напрямую','Все приложения','Только выбранные','WARP','Мой аккаунт','Подключение','Обновить проверки','Войти','Купить','Продолжить','Туннель, DNS и выход через VPN подтверждены','Защита','Настройки','Диагностика','Поддержка','Разрешить VPN','Повторить запрос','OK','ОК']
 return {'known_labels':[s for s in vocab if any(s in v for v in values)],'node_count':len(nodes),'packages':sorted(set(n.get('package','') for n in nodes))}
def tap(label,contains=False):
 matches=[n for n in ui() if any((label in n.get(k,'') if contains else label==n.get(k,'')) for k in ('text','content-desc'))]
 assert len(matches)==1,{'target':label,'matches':len(matches)}
 x1,y1,x2,y2=map(int,re.findall(r'\d+',matches[0].get('bounds')))
 run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
 return {'target':label,'bounds':matches[0].get('bounds'),'derived_from':'fresh UI tree'}
def snapshot(label,include_ui=True):
 rules=run('shell','ip','rule','show');routes=run('shell','ip','route','show','table','all')
 svc=run('shell','dumpsys','activity','services',PACKAGE);pkg=run('shell','dumpsys','package',PACKAGE)
 path=run('shell','pm','path',PACKAGE).removeprefix('package:')
 fields={key:re.search(r'\b'+key+r'=([^\n]+)',pkg).group(1).strip() for key in ('versionCode','versionName','primaryCpuAbi','firstInstallTime','lastUpdateTime','userId')}
 r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'label':label,'apk_sha256':run('shell','sha256sum',path).split()[0],'apk_bytes':int(run('shell','stat','-c','%s',path)),'device_model':run('shell','getprop','ro.product.model'),'sdk':run('shell','getprop','ro.build.version.sdk'),'package_fields':fields,'vpn_service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'foreground':'isForeground=true' in svc,'rules_hashes':sorted(digest(x) for x in rules.splitlines()),'routes_sha256':digest(routes),'tun_interfaces':sorted(x for x in run('shell','ls','/sys/class/net').split() if re.fullmatch(r'tun\d+',x)),'wifi_on':run('shell','settings','get','global','wifi_on'),'mobile_data':run('shell','settings','get','global','mobile_data'),'always_on':run('shell','settings','get','secure','always_on_vpn_app'),'lockdown':run('shell','settings','get','secure','always_on_vpn_lockdown'),'ui':labels(ui()) if include_ui else None}
 save(label,r);return r
if __name__=='__main__':
 if sys.argv[1]=='snapshot':print(json.dumps(snapshot(sys.argv[2]),ensure_ascii=False))
 elif sys.argv[1]=='start':run('shell','am','start','-n',PACKAGE+'/.MainActivity')
 elif sys.argv[1]=='read':print(json.dumps(labels(ui()),ensure_ascii=False))
 elif sys.argv[1]=='tap':print(json.dumps(tap(sys.argv[2],len(sys.argv)>3),ensure_ascii=False))
