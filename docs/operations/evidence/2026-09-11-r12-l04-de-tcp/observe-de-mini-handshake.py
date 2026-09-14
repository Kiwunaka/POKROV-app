import pathlib,subprocess,json,hashlib,datetime,concurrent.futures
r=pathlib.Path(__file__).parent
hosts={}
for alias in ['pokrov-de','pokrov-mini','pokrov-brain']:
 p=subprocess.run(['ssh','-G',alias],capture_output=True,text=True,check=True);hosts[alias]=next(x.split(' ',1)[1] for x in p.stdout.splitlines() if x.startswith('hostname '))
server='''import subprocess,json,time,re,signal
hosts=HOSTS
capture_filter='host '+hosts['pokrov-de']+' and ((dst port 443 and (src host '+hosts['pokrov-mini']+' or src host '+hosts['pokrov-brain']+')) or (src port 443 and (dst host '+hosts['pokrov-mini']+' or dst host '+hosts['pokrov-brain']+'))) and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'
p=subprocess.Popen(['tcpdump','-i','any','-nn','-l','-s','96',capture_filter],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
time.sleep(1);assert p.poll() is None
print(json.dumps({'phase':'DE_OBSERVER_READY'}),flush=True)
try:out,err=p.communicate(timeout=16)
except subprocess.TimeoutExpired:
 p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=5)
rows={alias:{'syn_in':0,'synack_out':0,'rst_in':0,'rst_out':0} for alias in ['pokrov-mini','pokrov-brain']}
for line in out.splitlines():
 m=re.search(r'IP ([0-9.]+) > ([0-9.]+): Flags \\[([^]]+)\\]',line)
 if not m:continue
 src,dst,flags=m.groups()
 for alias,c in rows.items():
  address=hosts[alias]
  if src.startswith(address+'.') and dst==hosts['pokrov-de']+'.443':
   if 'S' in flags:c['syn_in']+=1
   if 'R' in flags:c['rst_in']+=1
  if dst.startswith(address+'.') and src==hosts['pokrov-de']+'.443':
   if 'S' in flags and '.' in flags:c['synack_out']+=1
   if 'R' in flags:c['rst_out']+=1
print(json.dumps({'capture_exit':p.returncode,'duration_seconds':17,'syn_rst_counts':rows,'captured_text_lines':len(out.splitlines()),'raw_packets_retained':False,'raw_text_retained':False}),flush=True)
'''.replace('HOSTS',repr(hosts))
observer=subprocess.Popen(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','pokrov-de','sudo -n python3 -'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
observer.stdin.write(server);observer.stdin.close();observer.stdin=None
ready=observer.stdout.readline();assert ready.strip()==json.dumps({'phase':'DE_OBSERVER_READY'}),ready[:150]
def client(alias):
 s="import socket,json,time\nt=time.monotonic()\ntry:\n with socket.create_connection((TARGET,443),timeout=5):pass\n outcome='PASS'\nexcept Exception as e:outcome=type(e).__name__\nprint(json.dumps({'tcp':outcome,'seconds':round(time.monotonic()-t,2)}))\n".replace('TARGET',repr(hosts['pokrov-de']))
 if alias=='pokrov-mini':s="import socket,json,time,subprocess,signal,re\nhost=TARGET\np=subprocess.Popen(['tcpdump','-i','enp3s0','-nn','-l','-s','96','host '+host+' and tcp port 443 and (tcp[tcpflags] & (tcp-syn|tcp-rst) != 0)'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)\ntime.sleep(1);assert p.poll() is None;t=time.monotonic()\ntry:\n with socket.create_connection((host,443),timeout=5):pass\n outcome='PASS'\nexcept Exception as e:outcome=type(e).__name__\nseconds=round(time.monotonic()-t,2);time.sleep(1);p.send_signal(signal.SIGINT);out,err=p.communicate(timeout=4)\ncounts={'syn_out':0,'synack_in':0,'rst_in':0}\nfor line in out.splitlines():\n m=re.search(r'IP ([0-9.]+) > ([0-9.]+): Flags \\[([^]]+)\\]',line)\n if not m:continue\n src,dst,flags=m.groups()\n if dst==host+'.443' and 'S' in flags:counts['syn_out']+=1\n if src==host+'.443':\n  if 'S' in flags and '.' in flags:counts['synack_in']+=1\n  if 'R' in flags:counts['rst_in']+=1\nprint(json.dumps({'tcp':outcome,'seconds':seconds,'capture_interface':'enp3s0','flags':counts,'raw_data_retained':False}))\n".replace('TARGET',repr(hosts['pokrov-de']))
 p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',alias,'sudo -n python3 -' if alias=='pokrov-mini' else 'python3 -'],input=s,capture_output=True,text=True,timeout=12)
 return {'origin':alias,'ssh_exit':p.returncode,'result':json.loads(p.stdout) if p.returncode==0 else 'SSH_NOT_AVAILABLE'}
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:clients=list(pool.map(client,['pokrov-mini','pokrov-brain']))
out,err=observer.communicate(timeout=23);assert observer.returncode==0,err[:250];capture=json.loads(out)
receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'target_alias':'pokrov-de','target_sha256':hashlib.sha256(hosts['pokrov-de'].encode()).hexdigest(),'clients':clients,'capture':capture,'scope':'bounded owned-host TCP handshake counters only; no packet payload retained; no firewall or service change'}
p=r/'de-mini-concurrent-handshake.json';assert not p.exists();p.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
