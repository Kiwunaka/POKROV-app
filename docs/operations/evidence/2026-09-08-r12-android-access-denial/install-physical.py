import datetime, hashlib, json, re, subprocess
from pathlib import Path

root=Path(__file__).resolve().parent
adb='E:/POKROV-workspace-cache/android-sdk/platform-tools/adb.exe'
package='space.pokrov.pokrov_android_shell'
apk=root/'pokrov-r12-arm64-v8a.apk'
old=Path('E:/r12-integrated-acceptance-20260908/android/pokrov-r12-arm64-v8a.apk')
def run(*args):
    return subprocess.check_output([adb,*args],text=True,timeout=120).strip()
def snapshot():
    path=run('shell','pm','path',package).removeprefix('package:')
    installed=run('shell','sha256sum',path).split()[0]
    detail=run('shell','dumpsys','package',package)
    first=re.search(r'firstInstallTime=([^\n]+)',detail).group(1).strip()
    svc=run('shell','dumpsys','activity','services',package)
    return {'sha256':installed,'first_install_time':first,'vpn_service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'wifi_on':run('shell','settings','get','global','wifi_on'),'mobile_data':run('shell','settings','get','global','mobile_data')}
assert len(re.findall(r'\tdevice$',run('devices'),re.M))==1
assert run('shell','getprop','ro.product.model')=='ADA-AL00U'
before=snapshot()
assert not before['vpn_service']
assert before['sha256']==hashlib.sha256(old.read_bytes()).hexdigest()
receipt={'scope':'same-version local integrated package replacement; not channel update','started_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'before':before,'rollback_apk':str(old),'apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest()}
(root/'physical-install.json').write_text(json.dumps(receipt,indent=2)+'\n')
result=run('install','-r',str(apk))
assert 'Success' in result
after=snapshot()
assert after['sha256']==receipt['apk_sha256']
assert after['first_install_time']==before['first_install_time']
receipt.update({'after':after,'result':'PASS_INSTALL_BYTES_FIRST_INSTALL_TIME','limits':['account and preferences require UI readback','not final release/channel upgrade']})
(root/'physical-install.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'result':receipt['result'],'installed_sha256':after['sha256'],'vpn_service':after['vpn_service']}))
