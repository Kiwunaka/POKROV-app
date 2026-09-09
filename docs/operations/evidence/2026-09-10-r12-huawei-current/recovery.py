from device import *
import time
r={'scope':'same exact installed ARM64; forced deep Doze resume then force-stop/relaunch/reconnect without clearing data','status':'RUNNING','samples':[]}
def save():(ROOT/'recovery.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def snap(label,ui=True):
 s=snapshot(label,include_ui=ui);r['samples'].append(s);save();return s
try:
 actions=[]
 actions.append(tap('Защита',contains=True));time.sleep(.5)
 actions.append(tap('Статус защиты:',contains=True));time.sleep(.5)
 actions.append(tap('Обновить проверки'));time.sleep(5)
 strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()]
 r['post_doze_protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings);assert r['post_doze_protection_confirmed'];save()
 run('shell','input','keyevent','KEYCODE_BACK');snap('doze-resume')
 run('shell','am','force-stop',PACKAGE);time.sleep(4)
 stopped=snap('forced-stop',False);assert not stopped['vpn_service'] and not stopped['tun_interfaces']
 initial=json.loads((ROOT/'initial.json').read_bytes());r['force_stop_rules_restore']=stopped['rules_hashes']==initial['rules_hashes'];r['force_stop_routes_restore']=stopped['routes_sha256']==initial['routes_sha256'];save()
 run('shell','am','start','-n',PACKAGE+'/.MainActivity');time.sleep(5)
 cold=snap('cold-reopened');assert 'Подключить' in cold['ui']['known_labels']
 actions.append(tap('Подключить'));time.sleep(18)
 connected=snap('cold-reconnected');assert connected['vpn_service'] and connected['foreground'] and connected['tun_interfaces']
 actions.append(tap('Статус защиты:',contains=True));time.sleep(.5);actions.append(tap('Обновить проверки'));time.sleep(5)
 strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()]
 r['reconnect_protection_confirmed']=any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings);assert r['reconnect_protection_confirmed']
 r['actions']=actions;r['status']='PASS_BOUNDED';save()
finally:
 print(json.dumps({'status':r['status'],'post_doze_protection_confirmed':r.get('post_doze_protection_confirmed'),'reconnect_protection_confirmed':r.get('reconnect_protection_confirmed'),'force_stop_rules_restore':r.get('force_stop_rules_restore'),'force_stop_routes_restore':r.get('force_stop_routes_restore')}))
