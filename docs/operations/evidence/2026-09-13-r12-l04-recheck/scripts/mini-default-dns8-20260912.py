from pathlib import Path
import subprocess,json,socket,ipaddress,hashlib
r=Path('/tmp/pokrov-r12-l04-clean-20260911')
p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(r/'guest-known-hosts'),'-i',str(r/'guest-key'),'-p','22265','pokrovqa@127.0.0.1','sudo -n python3 -'],input="from pathlib import Path\nimport json,socket\nx=json.loads(Path('/var/lib/pokrov/profiles/active-profile.json').read_text())['outbounds'][0];print(json.dumps({'server':x['server'],'port':x['server_port'],'addresses':sorted(set(v[4][0] for v in socket.getaddrinfo(x['server'],x['server_port'],type=socket.SOCK_STREAM)))}))\n",capture_output=True,text=True,timeout=20);assert p.returncode==0;v=json.loads(p.stdout);host=sorted(set(x[4][0] for x in socket.getaddrinfo(v['server'],v['port'],type=socket.SOCK_STREAM)))
def project(xs):
 return [{'sha256':hashlib.sha256(x.encode()).hexdigest(),'is_global':ipaddress.ip_address(x).is_global,'fake_ip_range':ipaddress.ip_address(x) in ipaddress.ip_network('198.18.0.0/15'),'is_loopback':ipaddress.ip_address(x).is_loopback} for x in xs]
print(json.dumps({'guest_dns':project(v['addresses']),'mini_host_dns':project(host),'same_dns_answers':host==v['addresses']}))
