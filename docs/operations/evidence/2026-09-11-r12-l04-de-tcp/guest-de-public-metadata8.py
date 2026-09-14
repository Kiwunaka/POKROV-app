import json,pathlib,hashlib
p=json.loads(pathlib.Path('/var/lib/pokrov/profiles/active-profile.json').read_bytes());h=lambda x:hashlib.sha256(str(x).encode()).hexdigest()
a=[x for x in p['outbounds'] if h(x.get('server',''))=='9cbe63494f2822fa475d6f2c0d71e9f22e05e841811d12c0472c632f50a5b7a7' and x.get('type')=='vless' and not x.get('detour')];assert a
rows=[]
for v in a:
 tls=v.get('tls',{});reality=tls.get('reality',{})
 rows.append({'server_sha256':h(v.get('server','')),'server_port':v.get('server_port'),'uuid_sha256':h(v.get('uuid','')),'flow':v.get('flow'),'tls_enabled':tls.get('enabled'),'server_name_sha256':h(tls.get('server_name','')),'reality_enabled':reality.get('enabled'),'public_key_sha256':h(reality.get('public_key','')),'short_id_sha256':h(reality.get('short_id','')),'utls_fingerprint':tls.get('utls',{}).get('fingerprint'),'transport_type':v.get('transport',{}).get('type')})
out=pathlib.Path('/home/pokrovqa/acceptance-inputs/candidate8-de-public-metadata.json');assert not out.exists();out.write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows))
