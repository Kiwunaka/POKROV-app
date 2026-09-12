from device import *
import time
baseline=json.loads((ROOT/'pre-install-home.json').read_bytes())
connected=snapshot('reconnected-before-background')
assert connected['vpn_service'] and connected['foreground'] and connected['tun_interfaces']
run('shell','input','keyevent','KEYCODE_HOME')
time.sleep(8)
background=snapshot('background-active',False)
assert background['vpn_service'] and background['tun_interfaces']
run('shell','am','start','-n',PACKAGE+'/.MainActivity')
time.sleep(3)
action=tap('Статус защиты',True)
tap('Обновить проверки')
time.sleep(5)
resumed=snapshot('resumed-protection')
assert 'Туннель, DNS и выход через VPN подтверждены' in resumed['ui']['known_labels']
run('shell','am','force-stop',PACKAGE)
time.sleep(4)
stopped=snapshot('forced-stop',False)
probe=json.loads(run('shell','CLASSPATH=/data/local/tmp/r12-http.jar','app_process','/system/bin','R12Http',timeout=20))
checks={'background_tun_preserved':bool(background['tun_interfaces']),'resumed_protection_confirmed':True,'force_stop_no_tun':not stopped['tun_interfaces'],'force_stop_no_service':not stopped['vpn_service'],'force_stop_exact_rules':stopped['rules_hashes']==baseline['rules_hashes'],'force_stop_exact_routes':stopped['routes_sha256']==baseline['routes_sha256'],'https_after_force_stop':probe.get('http_status')==200}
save('forced-stop-result',{'checks':checks,'http_probe':probe,'probe_origin':'physical Huawei shell UID 2000; selected-app VPN coverage not inferred','limits':['Android am force-stop is controlled termination; not an uncaught Dart crash or ANR.','Home/background resume is not system suspend or Doze.']})
run('shell','am','start','-n',PACKAGE+'/.MainActivity')
time.sleep(4)
cold=snapshot('cold-reopened')
assert 'Подключить' in cold['ui']['known_labels']
tap('Подключить')
print(json.dumps(checks))
