from pathlib import Path
import concurrent.futures,json,subprocess,time

r=Path(__file__).parent
mini=(r/'mini-default-dns8-20260912.py').read_text(encoding='utf-8')
mini=mini.replace('import subprocess,json,socket,ipaddress,hashlib','import subprocess,json,socket,ipaddress,hashlib,time')
mini=mini.replace("print(json.dumps({'guest_dns':project(v['addresses']),'mini_host_dns':project(host),'same_dns_answers':host==v['addresses']}))", """rows=[]
for i in range(2):
 start=time.monotonic()
 try:
  with socket.create_connection((v['server'],v['port']),timeout=4):pass
  result='PASS'
 except OSError as e:result=type(e).__name__
 rows.append({'attempt':i+1,'result':result,'seconds':round(time.monotonic()-start,3)})
print(json.dumps({'captured_epoch':time.time(),'origin':'MINI host without VPN','guest_dns':project(v['addresses']),'mini_host_dns':project(host),'same_dns_answers':host==v['addresses'],'tcp443':rows}))""")
brain='''import hashlib,json,socket,subprocess,time
p=subprocess.run(['runuser','-u','postgres','--','psql','-X','-d','portal','-At','-c',"SELECT host FROM nodes WHERE code='de' AND enabled=true;"],capture_output=True,text=True,timeout=10);assert p.returncode==0
host=p.stdout.strip();assert hashlib.sha256(host.encode()).hexdigest()=='3d297432f8ce6dbcac91f560a4a7de1deb28bfb64f691de605a645eb4bb8339e'
ips=sorted(set(hashlib.sha256(x[4][0].encode()).hexdigest() for x in socket.getaddrinfo(host,443,type=socket.SOCK_STREAM)));rows=[]
for i in range(2):
 start=time.monotonic()
 try:
  with socket.create_connection((host,443),timeout=4):pass
  result='PASS'
 except OSError as e:result=type(e).__name__
 rows.append({'attempt':i+1,'result':result,'seconds':round(time.monotonic()-start,3)})
print(json.dumps({'captured_epoch':time.time(),'origin':'brain host','resolved_ip_hashes':ips,'tcp443':rows}))
'''
de='''import hashlib,json,subprocess,time
p=subprocess.run(['ip','-j','address'],capture_output=True,text=True,timeout=8);assert p.returncode==0
ips=[{'family':a['family'],'scope':a['scope'],'sha256':hashlib.sha256(a['local'].encode()).hexdigest()} for x in json.loads(p.stdout) for a in x['addr_info'] if a['scope']=='global']
print(json.dumps({'captured_epoch':time.time(),'origin':'DE current global interface addresses','addresses':ips}))
'''
def run(item):
 name,alias,script=item
 args=['ssh']+(['-J','pokrov-brain'] if alias=='pokrov-mini' else [])+['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',alias,'sudo -n python3 -']
 p=subprocess.run(args,input=script,capture_output=True,text=True,timeout=45);assert p.returncode==0,name+' failed'
 return name,json.loads(p.stdout)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:result=dict(pool.map(run,[('mini','pokrov-mini',mini),('brain','pokrov-brain',brain),('de_interfaces','pokrov-de',de)]))
out=r/'candidate8-default-path-controls-20260912.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result))
