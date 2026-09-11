import pathlib,subprocess,json,hashlib,datetime,concurrent.futures
r=pathlib.Path(__file__).parent;hosts={}
for alias in ['pokrov-de','pokrov-mini']:
 p=subprocess.run(['ssh','-G',alias],capture_output=True,text=True,check=True);hosts[alias]=next(x.split(' ',1)[1] for x in p.stdout.splitlines() if x.startswith('hostname '))
base='''import pathlib,subprocess,json,time,re,signal,hashlib
hosts=HOSTS
origin=ORIGIN
capture_filter='host '+hosts['pokrov-de']+' and ((dst port 443 and src host '+hosts['pokrov-mini']+') or (src port 443 and dst host '+hosts['pokrov-mini']+')) and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'
before=json.loads(subprocess.check_output(['tc','-j','-s','qdisc','show','dev',INTERFACE if INTERFACE!='any' else 'eth0'],text=True))
p=subprocess.Popen(['tcpdump','-i',INTERFACE,'-nn','-tt','-l','-s','96',capture_filter],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
time.sleep(1);assert p.poll() is None
ARM
print(json.dumps({'phase':'CAPTURE_READY','origin':origin}),flush=True)
try:out,err=p.communicate(timeout=20)
except subprocess.TimeoutExpired:
 p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=4)
after=json.loads(subprocess.check_output(['tc','-j','-s','qdisc','show','dev',INTERFACE if INTERFACE!='any' else 'eth0'],text=True))
counts={label:int(m.group(1)) for label in ['captured','received by filter','dropped by kernel'] if (m:=re.search(r'(\\d+) packets? '+label,err))}
queue=lambda rows:[{'kind':q.get('kind'),'drops':q.get('drops'),'overlimits':q.get('overlimits'),'requeues':q.get('requeues')} for q in rows]
flows={}
for line in out.splitlines():
 m=re.search(r'^([0-9.]+) .*?IP ([0-9.]+) > ([0-9.]+): Flags \\[([^]]+)\\]',line)
 if not m:continue
 stamp,src,dst,flags=m.groups();client=src if dst==hosts['pokrov-de']+'.443' else dst;server=dst if dst==hosts['pokrov-de']+'.443' else src
 if server!=hosts['pokrov-de']+'.443':continue
 key=hashlib.sha256((client+'->'+server).encode()).hexdigest();v=flows.setdefault(key,{'syn_client':0,'synack_server':0,'rst_client':0,'rst_server':0,'first_epoch':float(stamp)})
 v['last_epoch']=float(stamp)
 if dst==server:
  if 'S' in flags:v['syn_client']+=1
  if 'R' in flags:v['rst_client']+=1
 else:
  if 'S' in flags and '.' in flags:v['synack_server']+=1
  if 'R' in flags:v['rst_server']+=1
print(json.dumps({'origin':origin,'capture_exit':p.returncode,'capture_stats':counts,'qdisc_before':queue(before),'qdisc_after':queue(after),'flows':flows,'raw_packets_or_text_retained':False,'filter_scope':'only SYN/RST between task-owned MINI and DE:443'}),flush=True)
'''.replace('HOSTS',repr(hosts))
mini_arm="import concurrent.futures,socket\ndef probe(i):\n started=time.time()\n try:\n  c=socket.create_connection((hosts['pokrov-de'],443),timeout=6);local=c.getsockname();key=hashlib.sha256((local[0]+'.'+str(local[1])+'->'+hosts['pokrov-de']+'.443').encode()).hexdigest();c.close();return {'i':i,'result':'PASS','flow':key,'seconds':round(time.time()-started,2)}\n except OSError as e:return {'i':i,'result':type(e).__name__,'seconds':round(time.time()-started,2)}\nwith concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool: outcomes=list(pool.map(probe,range(6)))\nprint(json.dumps({'native_host_tcp':outcomes}),flush=True)\n"
processes=[]
for alias in ['pokrov-de','pokrov-mini']:
 s=base.replace('ORIGIN',repr(alias)).replace('INTERFACE',repr('enp3s0' if alias=='pokrov-mini' else 'any')).replace('ARM',mini_arm if alias=='pokrov-mini' else '')
 p=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',alias,'sudo -n python3 -'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 p.stdin.write(s);p.stdin.close();p.stdin=None;lines=[]
 while True:
  line=p.stdout.readline();assert line,alias+' capture failed before ready';v=json.loads(line);lines.append(v)
  if v.get('phase')=='CAPTURE_READY':break
 print(json.dumps({'armed':alias,'events':lines}),flush=True);processes.append((alias,p,lines))
results=[]
for alias,p,ready in processes:
 out,err=p.communicate(timeout=60);assert p.returncode==0,alias+' capture failed';results.append(dict(json.loads(out),ready_events=ready))
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'OBSERVATION_COMPLETE','target_alias':'pokrov-de','target_sha256':hashlib.sha256(hosts['pokrov-de'].encode()).hexdigest(),'results':results,'runtime':'six concurrent MINI native host TCP probes to owned DE443; no VM/profile operation','no_firewall_or_service_change':True}
out=r/'de-native-host-wire-counters.json';assert not out.exists();out.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
