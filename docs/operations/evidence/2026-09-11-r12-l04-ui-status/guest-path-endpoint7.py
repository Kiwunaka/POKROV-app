import json,pathlib,hashlib,socket,ipaddress,time
p=json.loads(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').read_text());rows=[]
for index in [0,5,34]:
 v=p['outbounds'][index];server=v['server'];port=v['server_port'];row={'outbound_index':index,'server_sha256':hashlib.sha256(server.encode()).hexdigest()}
 try:ipaddress.ip_address(server);row['server_is_ip']=True
 except ValueError:row['server_is_ip']=False
 try:
  infos=socket.getaddrinfo(server,port,type=socket.SOCK_STREAM);row['resolved_endpoints']=[]
  for family,stype,proto,_,address in infos:
   endpoint={'family':family,'ip_sha256':hashlib.sha256(address[0].encode()).hexdigest()};start=time.monotonic()
   try:
    with socket.socket(family,stype,proto) as s:s.settimeout(4);s.connect(address)
    endpoint['tcp']='PASS'
   except Exception as e:endpoint['tcp']=type(e).__name__
   endpoint['seconds']=round(time.monotonic()-start,2);row['resolved_endpoints'].append(endpoint)
 except Exception as e:row['resolve']=type(e).__name__
 rows.append(row)
out=pathlib.Path('/home/pokrovqa/acceptance-inputs/candidate7-path-endpoint-diagnostic.json');assert not out.exists();out.write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows,indent=2))
