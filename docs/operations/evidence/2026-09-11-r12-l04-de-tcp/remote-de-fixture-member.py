import pathlib,subprocess,json,hashlib,time
p=pathlib.Path('/proc/1326');args=[x.decode() for x in (p/'cmdline').read_bytes().split(b'\0') if x];index=next(i for i,x in enumerate(args) if x in ('-c','-config','--config'));config=(p/'cwd').resolve()/args[index+1];v=json.loads(config.read_bytes());expected='c1ede843da00a502d12f3074c7863ae09c7d9f29c76db86be5cc32ebd49285dc';matches=[]
for inbound in v.get('inbounds',[]):
 if str(inbound.get('port'))!='443':continue
 for client in inbound.get('settings',{}).get('clients',[]):
  if hashlib.sha256(client.get('id','').encode()).hexdigest()==expected:matches.append({'id_hash_matches_fixture':True,'flow':client.get('flow'),'level':client.get('level')})
print(json.dumps({'pid':1326,'config_sha256':hashlib.sha256(config.read_bytes()).hexdigest(),'fixture_client_matches':matches,'scope':'current on-disk Xray inbound only; not proof of loaded dynamic user map'}))
