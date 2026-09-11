from pathlib import Path
import subprocess,json,re,hashlib,datetime,xml.etree.ElementTree as E
out=Path(__file__).parent;adb='C:/Users/kiwun/AppData/Local/Android/Sdk/platform-tools/adb.exe';serial='emulator-5560';pkg='space.pokrov.pokrov_android_shell'
def run(*a):return subprocess.run([adb,'-s',serial,*a],capture_output=True,timeout=35,check=True).stdout
pid=run('shell','pidof','-s',pkg).decode().strip();assert pid.isdigit()
raw=run('logcat','-d','--pid='+pid,'-v','threadtime')
patterns={'connection_uri':rb'(?i)\b(?:vless|vmess|trojan|ss|hysteria2|tuic|wireguard)://','bearer_value':rb'(?i)\bBearer\s+[A-Za-z0-9_./+=-]{12,}','jwt':rb'\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\b','private_key_pem':rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----','credential_assignment':rb'(?i)["\x27]?(?:access_token|refresh_token|private_key|client_secret|password)["\x27]?\s*[:=]\s*["\x27]?[A-Za-z0-9_+/=-]{12,}','email':rb'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'}
counts={name:len(re.findall(pattern,raw)) for name,pattern in patterns.items()}
ui=run('exec-out','uiautomator','dump','/dev/tty').decode('utf8');ui=ui[ui.index('<?xml'):];tree=E.fromstring(ui[:ui.index('</hierarchy>')+12]);texts=[e.get('text') or e.get('content-desc') or '' for e in tree.iter('node') if e.get('package')==pkg]
services=run('shell','dumpsys','activity','services',pkg)
path=run('shell','pm','path',pkg).decode().strip().removeprefix('package:');sha=run('shell','sha256sum',path).decode().split()[0]
result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'PASS_BOUNDED_STARTUP_LOG_SCAN' if not any(counts.values()) else 'REQUIRES_MATCH_CLASSIFICATION','apk_sha256':sha,'main_ui_visible':any(t=='POKROV VPN' for t in texts),'stored_location_preserved':any(t=='Санкт-Петербург' for t in texts),'stored_routing_preserved':any(t=='Россия напрямую' for t in texts),'entitlement_requires_renewal':any('Продлите доступ' in t for t in texts),'vpn_service_running':bool(re.search(rb'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',services)),'app_logcat_bytes':len(raw),'app_logcat_sha256':hashlib.sha256(raw).hexdigest(),'pattern_counts':counts,'fatal_exception_seen':b'FATAL EXCEPTION' in raw,'anr_seen':b'ANR in '+pkg.encode() in raw,'raw_logs_exported':False,'scope':'Current main process startup only. Regex scan is bounded and is not proof of absence of every secret in every sink.'}
(out/'startup-privacy.json').write_text(json.dumps(result,indent=2)+'\n')
(out/'after-ui.png').write_bytes(run('exec-out','screencap','-p'))
print(json.dumps(result));assert sha=='9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee'
