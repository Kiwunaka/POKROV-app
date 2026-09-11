import pathlib,subprocess,json,hashlib,datetime,concurrent.futures
r=pathlib.Path(__file__).parent;hosts={}
for alias in ['pokrov-de','pokrov-mini']:
 p=subprocess.run(['ssh','-G',alias],capture_output=True,text=True,check=True);hosts[alias]=next(x.split(' ',1)[1] for x in p.stdout.splitlines() if x.startswith('hostname '))
base='''import pathlib,subprocess,json,time,re,signal,hashlib
hosts=HOSTS
origin=ORIGIN
capture_filter='host '+hosts['pokrov-de']+' and ((dst port 443 and src host '+hosts['pokrov-mini']+') or (src port 443 and dst host '+hosts['pokrov-mini']+')) and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'
p=subprocess.Popen(['tcpdump','-i',INTERFACE,'-nn','-tt','-l','-s','96',capture_filter],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
time.sleep(1);assert p.poll() is None
ARM
print(json.dumps({'phase':'CAPTURE_READY','origin':origin}),flush=True)
try:out,err=p.communicate(timeout=55)
except subprocess.TimeoutExpired:
 p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=4)
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
print(json.dumps({'origin':origin,'capture_exit':p.returncode,'flows':flows,'raw_packets_or_text_retained':False,'filter_scope':'only SYN/RST between task-owned MINI and DE:443'}),flush=True)
'''.replace('HOSTS',repr(hosts))
arm=(r/'guest-arm-de-wire8.py').read_text()
mini_arm="guestroot=pathlib.Path('/tmp/pokrov-r12-l04-clean-20260911')\nassert pathlib.Path('/proc/1919043').exists()\na=['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(guestroot/'guest-known-hosts'),'-i',str(guestroot/'guest-key'),'-p','22265','pokrovqa@127.0.0.1','sudo -n python3 -']\nq=subprocess.run(a,input="+repr(arm)+",capture_output=True,text=True,timeout=15);assert q.returncode==0,q.stderr[:120]\nprint(json.dumps({'guest_unit':q.stdout.strip()}),flush=True)"
processes=[]
for alias in ['pokrov-de','pokrov-mini']:
 s=base.replace('ORIGIN',repr(alias)).replace('INTERFACE',repr('enp3s0' if alias=='pokrov-mini' else 'any')).replace('ARM',mini_arm if alias=='pokrov-mini' else '')
 p=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',alias,'sudo -n python3 -'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 p.stdin.write(s);p.stdin.close();p.stdin=None;lines=[]
 while True:
  line=p.stdout.readline();assert line,alias+' capture failed before ready';v=json.loads(line);lines.append(v)
  if v.get('phase')=='CAPTURE_READY':break
 print(json.dumps({'armed':alias,'events':lines}),flush=True);processes.append((alias,p))
results=[]
for alias,p in processes:
 out,err=p.communicate(timeout=60);assert p.returncode==0,alias+' capture failed';results.append(json.loads(out))
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'OBSERVATION_COMPLETE','target_alias':'pokrov-de','target_sha256':hashlib.sha256(hosts['pokrov-de'].encode()).hexdigest(),'results':results,'runtime':'native package8 exact DE path; root fixture with original profile/network restoration','no_firewall_or_service_change':True}
out=r/'candidate8-de-concurrent-wire.json';assert not out.exists();out.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
