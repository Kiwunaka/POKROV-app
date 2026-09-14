import pathlib,subprocess,json,hashlib,base64,importlib.util
pid=1326;p=pathlib.Path('/proc')/str(pid);exe=(p/'exe').resolve();assert exe.name=='xray-linux-amd64'
version=subprocess.check_output([str(exe),'version'],text=True).splitlines()[0]
args=[x.decode() for x in (p/'cmdline').read_bytes().split(b'\0') if x];config=None
for i,a in enumerate(args):
 if a in ['-c','-config','--config'] and i+1<len(args):config=(p/'cwd').resolve()/args[i+1]
assert config is not None and config.is_file()
raw=config.read_bytes();v=json.loads(raw);h=lambda x:hashlib.sha256(str(x).encode()).hexdigest();rows=[]
for inbound in v.get('inbounds',[]):
 if str(inbound.get('port'))!='443':continue
 stream=inbound.get('streamSettings',{});reality=stream.get('realitySettings',{});row={'protocol':inbound.get('protocol'),'network':stream.get('network'),'security':stream.get('security'),'server_name_sha256':[h(x) for x in reality.get('serverNames',[])],'short_id_sha256':[h(x) for x in reality.get('shortIds',[])],'target_sha256':h(reality.get('dest') or reality.get('target')),'show':reality.get('show'),'maxTimeDiff':reality.get('maxTimeDiff')}
 if reality.get('privateKey') and importlib.util.find_spec('cryptography'):
  from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
  from cryptography.hazmat.primitives import serialization
  key=reality['privateKey'];priv=X25519PrivateKey.from_private_bytes(base64.urlsafe_b64decode(key+'='*((-len(key))%4)));pub=priv.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw);row['public_key_sha256']=h(base64.urlsafe_b64encode(pub).decode().rstrip('='));priv=None;key=None
 rows.append(row)
logs={k:{'configured':bool(x),'basename':pathlib.Path(x).name if isinstance(x,str) else None,'exists':pathlib.Path(x).is_file() if isinstance(x,str) else False} for k,x in v.get('log',{}).items() if k in ('access','error')}
result={'pid':pid,'version':version,'binary_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'config_sha256':hashlib.sha256(raw).hexdigest(),'inbound443':rows,'log_level':v.get('log',{}).get('loglevel'),'logs':logs,'private_material_exported':False}
print(json.dumps(result))
