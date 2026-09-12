from pathlib import Path
import subprocess,hashlib,json,re,sys,xml.etree.ElementTree as ET
sys.stdout.reconfigure(encoding='utf-8')
out=Path(__file__).parent
adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell'
def run(*args):return subprocess.check_output([adb,'-s',serial,*args],timeout=35)
def tree():
 raw=run('shell','env','CLASSPATH=/data/local/tmp/r126bnetwork20260912/ui.dex','app_process','/data/local/tmp/r126bnetwork20260912','UiTreeProbe').decode();start=raw.index('<?xml');return ET.fromstring(raw[start:raw.index('</hierarchy>')+12])
def texts(t):
 result=[]
 for n in t.iter('node'):
  text=n.get('text') or n.get('content-desc') or ''
  text=re.sub(r'PSM1-[A-Za-z0-9._-]+','[private support code]',text)
  text=re.sub(r'\b(?:[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27,}|\d{8,}|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,})\b','[private identifier]',text)
  if text:result.append({'text':text,'bounds':n.get('bounds'),'clickable':n.get('clickable')})
 return result
if __name__=='__main__':
 boot=run('shell','cat','/proc/sys/kernel/random/boot_id').strip();indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip();assert boot==indexed and len(boot)==36
 if sys.argv[1]=='start':
  path=run('shell','pm','path',pkg).decode().strip().removeprefix('package:');assert run('shell','sha256sum',path).decode().split()[0]=='6d4b998756548c980937a1f9de7af39a1d65899ec06319594073daceab993e63';run('shell','am','start','-n',pkg+'/.MainActivity')
 elif sys.argv[1]=='tap':
  t=tree();matches=[n for n in t.iter('node') if (n.get('text') or n.get('content-desc') or '').endswith(sys.argv[2])];assert len(matches)==1
  v=list(map(int,re.findall(r'\d+',matches[0].get('bounds'))));run('shell','input','tap',str((v[0]+v[2])//2),str((v[1]+v[3])//2))
 elif sys.argv[1]=='scroll':
  t=tree();matches=[n for n in t.iter('node') if n.get('scrollable')=='true'];assert len(matches)==1
  v=list(map(int,re.findall(r'\d+',matches[0].get('bounds'))));x=(v[0]+v[2])//2;y1=(v[1]+3*v[3])//4;y2=(3*v[1]+v[3])//4;run('shell','input','swipe',str(x),str(y1),str(x),str(y2),'350')
 elif sys.argv[1]!='read':raise ValueError('unknown')
 else:print(json.dumps(texts(tree()),ensure_ascii=False,indent=2))
