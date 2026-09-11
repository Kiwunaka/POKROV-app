import json,pathlib,subprocess,hashlib,socket,time
r=pathlib.Path('/home/pokrovqa/acceptance-inputs')
for _ in range(90):
 with socket.socket(socket.AF_UNIX) as sock:
  sock.connect('/run/pokrov/pokrov-linuxd.sock');sock.sendall(b'{"protocol":"pokrov-linuxd-v1","request_id":"diag7","action":"status","payload":{}}\n');state=json.loads(sock.makefile('rb').readline(65537)).get('snapshot',{})
 if state.get('phase')=='running':break
 time.sleep(2)
assert state.get('phase')=='running'
time.sleep(3)
result=[]
for attempt in range(3):
 for label,url in [('app','https://app.pokrov.space/'),('marker','https://app.pokrov.space/api/public/authenticated-egress-probe')]:
  q=subprocess.run(['curl','-4','--silent','--show-error','--max-time','12','--output','/dev/null','--write-out','%{json}',url],capture_output=True,text=True)
  try:v=json.loads(q.stdout)
  except ValueError:v={}
  result.append({'attempt':attempt+1,'target':label,'curl_exit':q.returncode,'http_code':v.get('http_code'),'peer_sha256':hashlib.sha256(v.get('remote_ip','').encode()).hexdigest(),'ssl_verify_result':v.get('ssl_verify_result'),'error_kinds':[k for k in ['SSL_ERROR_SYSCALL','Connection reset by peer','unexpected eof','wrong version number','certificate','timed out'] if k.lower() in q.stderr.lower()]})
out=r/'candidate7-full-http-diagnostic.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

config=json.loads(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').read_text())
first=config['outbounds'][0]
summary={'first_transport_server_sha256':hashlib.sha256(first.get('server','').encode()).hexdigest(),'first_transport_server_port':first.get('server_port'),'first_transport_type':first.get('type'),'tls_sni_sha256':hashlib.sha256(first.get('tls',{}).get('server_name','').encode()).hexdigest(),'utls_fingerprint':first.get('tls',{}).get('utls',{}).get('fingerprint'),'core_processes':subprocess.check_output(['pgrep','-c','-x','pokrov-core'],text=True).strip()}
(r/'candidate7-full-transport-shape.json').write_text(json.dumps(summary,indent=2)+'\n')
