from pathlib import Path
import subprocess,json,hashlib,datetime,time
root=Path('C:/r12-l04-ui-poll-20260911');target=root/'de-port-control-20260912.json';assert not target.exists()
hosts={}
for alias in ['pokrov-mini','pokrov-de']:
 config=subprocess.check_output(['ssh.exe','-G',alias],text=True,stderr=subprocess.DEVNULL);hosts[alias]=next(x.split(' ',1)[1] for x in config.splitlines() if x.startswith('hostname '))
code=r'''import subprocess,json,time,signal,re,hashlib,socket
hosts=HOSTS;origin=ORIGIN;interface=INTERFACE
key=lambda client,port,server,dport:hashlib.sha256((client+'.'+str(port)+'->'+server+'.'+str(dport)).encode()).hexdigest()
filt='host '+hosts['pokrov-mini']+' and host '+hosts['pokrov-de']+' and (tcp port 443 or tcp port 22) and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'
qdev=interface if interface!='any' else 'eth0'
q=lambda:[{'kind':v.get('kind'),'drops':v.get('drops'),'overlimits':v.get('overlimits')} for v in json.loads(subprocess.check_output(['tc','-j','-s','qdisc','show','dev',qdev],text=True))]
before=q();p=subprocess.Popen(['tcpdump','-i',interface,'-nn','-tt','-l','-s','96',filt],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);time.sleep(1);assert p.poll() is None
print(json.dumps({'phase':'CAPTURE_READY','origin':origin}),flush=True)
trials=[]
if origin=='pokrov-mini':
 for i,port in enumerate([443,22,443,443,22,443,443,22,443]):
  s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.settimeout(4);started=time.monotonic();s.bind(('',0))
  try:s.connect((hosts['pokrov-de'],port));result='PASS'
  except OSError as e:result=type(e).__name__
  local=s.getsockname();trials.append({'trial':i+1,'port':port,'result':result,'seconds':round(time.monotonic()-started,3),'flow':key(local[0],local[1],hosts['pokrov-de'],port)});s.close();time.sleep(.15)
 try:out,err=p.communicate(timeout=1)
 except subprocess.TimeoutExpired:p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=5)
else:
 try:out,err=p.communicate(timeout=35)
 except subprocess.TimeoutExpired:p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=5)
flows={}
for line in out.splitlines():
 m=re.search(r'^([0-9.]+) .*?IP ([0-9.]+) > ([0-9.]+): Flags \[([^]]+)\]',line)
 if not m:continue
 stamp,src,dst,flags=m.groups();sip,sp=src.rsplit('.',1);dip,dp=dst.rsplit('.',1)
 if sip==hosts['pokrov-mini'] and dip==hosts['pokrov-de']:client,cport,server,sport=sip,int(sp),dip,int(dp);direction='client'
 elif dip==hosts['pokrov-mini'] and sip==hosts['pokrov-de']:client,cport,server,sport=dip,int(dp),sip,int(sp);direction='server'
 else:continue
 if sport not in (22,443):continue
 k=key(client,cport,server,sport);v=flows.setdefault(k,{'port':sport,'syn_client':0,'synack_server':0,'rst_client':0,'rst_server':0})
 if direction=='client' and 'S' in flags:v['syn_client']+=1
 if direction=='server' and 'S' in flags and '.' in flags:v['synack_server']+=1
 if 'R' in flags:v['rst_'+direction]+=1
stats={label:int(m.group(1)) for label in ['captured','received by filter','dropped by kernel'] if (m:=re.search(r'(\d+) packets? '+label,err))}
print(json.dumps({'origin':origin,'trials':trials,'flows':flows,'capture_exit':p.returncode,'capture_stats':stats,'qdisc_before':before,'qdisc_after':q(),'raw_packets_retained':False}),flush=True)
'''
processes=[]
for alias in ['pokrov-de','pokrov-mini']:
 script=code.replace('HOSTS',repr(hosts)).replace('ORIGIN',repr(alias)).replace('INTERFACE',repr('enp3s0' if alias=='pokrov-mini' else 'any'))
 p=subprocess.Popen(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',alias,'sudo -n python3 -'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True);p.stdin.write(script);p.stdin.close();p.stdin=None
 ready=p.stdout.readline();assert ready,alias+' observer failed';assert json.loads(ready)['phase']=='CAPTURE_READY';processes.append((alias,p));print(json.dumps({'observer_ready':alias}),flush=True)
results=[]
for alias,p in processes:
 output,err=p.communicate(timeout=50);assert p.returncode==0,alias+' observer failed';results.append(json.loads(output))
mini=next(r for r in results if r['origin']=='pokrov-mini');de=next(r for r in results if r['origin']=='pokrov-de')
for t in mini['trials']:
 t['mini_capture']=mini['flows'].get(t['flow']);t['de_capture']=de['flows'].get(t['flow'])
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'OBSERVATION_COMPLETE','purpose':'L04 known MINI-to-DE failure: paired existing VPN443 and SSH22 port control','target_alias':'pokrov-de','target_sha256':hashlib.sha256(hosts['pokrov-de'].encode()).hexdigest(),'results':results,'no_vm_or_firewall_or_service_mutation':True}
target.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({'status':receipt['status'],'trials':mini['trials'],'capture_stats':{r['origin']:r['capture_stats'] for r in results}}))
