from pathlib import Path
import subprocess,hashlib,json,re,sys,xml.etree.ElementTree as ET
sys.stdout.reconfigure(encoding='utf-8')
out=Path(__file__).parent
adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell'
def run(*args):return subprocess.check_output([adb,'-s',serial,*args],timeout=35)
def tree():
 raw=run('exec-out','uiautomator','dump','/dev/tty').decode();start=raw.index('<?xml');return ET.fromstring(raw[start:raw.index('</hierarchy>')+12])
def texts(t):
 result=[]
 for n in t.iter('node'):
  text=n.get('text') or n.get('content-desc') or ''
  text=re.sub(r'\b(?:[A-Fa-f0-9]{8}-[A-Fa-f0-9-]{27,}|\d{8,}|[\w.+-]+@[\w.-]+\.[A-Za-z]{2,})\b','[private identifier]',text)
  if text:result.append({'text':text,'bounds':n.get('bounds'),'clickable':n.get('clickable')})
 return result
if __name__=='__main__':
 boot=run('shell','cat','/proc/sys/kernel/random/boot_id').strip();indexed=subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','adb','--index','3','--command','shell cat /proc/sys/kernel/random/boot_id'],timeout=35).strip();assert boot==indexed and len(boot)==36
 if sys.argv[1]=='start':
  path=run('shell','pm','path',pkg).decode().strip().removeprefix('package:');assert run('shell','sha256sum',path).decode().split()[0]=='baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52';run('shell','am','start','-n',pkg+'/.MainActivity')
 elif sys.argv[1]=='tap':
  t=tree();matches=[n for n in t.iter('node') if (n.get('text') or n.get('content-desc') or '').endswith(sys.argv[2])];assert len(matches)==1
  v=list(map(int,re.findall(r'\d+',matches[0].get('bounds'))));run('shell','input','tap',str((v[0]+v[2])//2),str((v[1]+v[3])//2))
 elif sys.argv[1]=='scroll':
  t=tree();matches=[n for n in t.iter('node') if n.get('scrollable')=='true'];assert len(matches)==1
  v=list(map(int,re.findall(r'\d+',matches[0].get('bounds'))));x=(v[0]+v[2])//2;y1=(v[1]+3*v[3])//4;y2=(3*v[1]+v[3])//4;run('shell','input','swipe',str(x),str(y1),str(x),str(y2),'350')
 elif sys.argv[1]!='read':raise ValueError('unknown')
 else:print(json.dumps(texts(tree()),ensure_ascii=False,indent=2))
