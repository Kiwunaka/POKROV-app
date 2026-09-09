from device import *
import time
r={'status':'RUNNING','scope':'current installed ARM64 Warsaw whitelist; Wi-Fi to cellular to Wi-Fi; current physical origin','samples':[]}
def save():(ROOT/'warsaw-handover.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def physical():
 raw=run('shell','dumpsys','connectivity');default=re.search(r'Active default network:\s*(\d+)',raw).group(1);lines=raw.splitlines();matches=[]
 for i,line in enumerate(lines):
  if 'NetworkAgentInfo' in line and ('network{'+default+'}') in line:
   block='\n'.join(lines[i:i+6]);match=re.search(r'Transports:\s*([A-Z| ]+?)(?:Capabilities:|\])',block);assert match
   matches.append(match[1].strip().split('|'))
 assert len(matches)==1,{'default_id':default,'matching_count':len(matches)}
 return {'default_network_id':default,'transports':matches[0],'radio_type':run('shell','getprop','gsm.network.type')}
def sample(label,expected):
 tap('Обновить проверки');time.sleep(6)
 native=snapshot(label);strings=[n.get('text','')+' '+n.get('content-desc','') for n in ui()]
 value={'label':label,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'physical':physical(),'pid':native['pid'],'vpn_service':native['vpn_service'],'foreground':native['foreground'],'tun':native['tun_interfaces'],'protection_confirmed':any('Туннель, DNS и выход через VPN подтверждены' in s for s in strings),'wifi_on':native['wifi_on'],'mobile_data':native['mobile_data']}
 r['samples'].append(value);save();assert expected in value['physical']['transports'];assert value['vpn_service'] and value['foreground'] and value['tun'];print(json.dumps(value),flush=True);return value
before=sample('warsaw-wifi','WIFI');assert before['wifi_on']=='1' and before['mobile_data']=='1'
try:
 run('shell','svc','wifi','disable');time.sleep(20);mobile=sample('warsaw-cellular','CELLULAR')
finally:
 run('shell','svc','wifi','enable');time.sleep(20);restored=sample('warsaw-wifi-restored','WIFI')
 r['same_pid']=len({s['pid'] for s in r['samples']})==1;r['status']='PASS_BOUNDED' if len(r['samples'])==3 and all(s['protection_confirmed'] for s in r['samples']) and r['same_pid'] else 'FAIL_OR_INCOMPLETE';save();print(json.dumps({'status':r['status'],'same_pid':r['same_pid']}),flush=True)
