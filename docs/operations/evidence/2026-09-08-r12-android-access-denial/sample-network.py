import datetime,hashlib,json,re,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parent
adb='E:/POKROV-workspace-cache/android-sdk/platform-tools/adb.exe'
def run(*args):
    return subprocess.check_output([adb,'shell',*args],text=True,encoding='utf-8',timeout=20).strip()
rules=run('ip','rule','show')
routes=run('ip','route','show','table','all')
svc=run('dumpsys','activity','services','space.pokrov.pokrov_android_shell')
value={'label':sys.argv[1],'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'vpn_service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'foreground':'isForeground=true' in svc,'rule_line_hashes':sorted(hashlib.sha256(x.encode()).hexdigest() for x in rules.splitlines()),'routes_sha256':hashlib.sha256(routes.encode()).hexdigest(),'tun_interfaces':sorted(x for x in run('ls','/sys/class/net').split() if re.fullmatch(r'tun\d+',x)),'wifi_on':run('settings','get','global','wifi_on'),'mobile_data':run('settings','get','global','mobile_data')}
(root/f'{sys.argv[1]}.json').write_text(json.dumps(value,indent=2)+'\n')
print(json.dumps({k:value[k] for k in ['label','vpn_service','tun_interfaces']}))
