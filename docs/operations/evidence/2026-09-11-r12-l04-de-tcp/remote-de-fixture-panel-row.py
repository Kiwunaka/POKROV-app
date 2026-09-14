import pathlib,sqlite3,json,hashlib,time
p=pathlib.Path('/etc/x-ui/x-ui.db');assert p.is_file();db=sqlite3.connect(p.as_uri()+'?mode=ro',uri=True,timeout=5);rows=[];expected='c1ede843da00a502d12f3074c7863ae09c7d9f29c76db86be5cc32ebd49285dc'
for settings,enabled in db.execute('SELECT settings,enable FROM inbounds WHERE port = 443'):
 v=json.loads(settings)
 for client in v.get('clients',[]):
  if hashlib.sha256(client.get('id','').encode()).hexdigest()==expected:
   expiry=client.get('expiryTime',0);rows.append({'fixture_uuid_matches':True,'inbound_enabled':bool(enabled),'client_enabled':client.get('enable'),'flow':client.get('flow'),'expiry_set':bool(expiry),'expiry_future':expiry>time.time()*1000 if expiry>0 else None,'relative_expiry':expiry<0})
db.close();print(json.dumps({'scope':'read-only x-ui SQLite client settings for exact task-fixture UUID hash','matches':rows,'raw_customer_material_exported':False}))
