from pathlib import Path
import json,urllib.request,datetime
out=Path('C:/r12-c05-packages-20260911');queries={};cohorts={}
for surface in ['android','windows']:
 d=json.loads(Path(f'C:/r12-c05-packages-20260911/{surface}-pub-deps.json').read_bytes());by={p['name']:p for p in d['packages']}; todo=[d['root']];seen=set()
 while todo:
  name=todo.pop()
  if name in seen:continue
  seen.add(name);p=by[name];todo.extend(p.get('directDependencies',p['dependencies']))
  if p['source']=='hosted':
   k=('Pub',name,p['version']);queries[k]={'package':{'ecosystem':'Pub','name':name},'version':p['version']};cohorts.setdefault(k,[]).append(surface)
mods=json.loads((out/'android-gradle-modules-direct.json').read_bytes());store=json.loads((out/'android-gradle-modules-store.json').read_bytes());assert mods==store;excluded=[]
for p in mods:
 if not p['group'] or p['group']=='io.flutter':excluded.append(p);continue
 name=p['group']+':'+p['name'];k=('Maven',name,p['version']);queries[k]={'package':{'ecosystem':'Maven','name':name},'version':p['version']};cohorts[k]=['android']
keys=sorted(queries);payload={'queries':[queries[k]for k in keys]};(out/'osv-query-public-packages.json').write_bytes((json.dumps(payload,indent=2)+'\n').encode())
req=urllib.request.Request('https://api.osv.dev/v1/querybatch',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json','User-Agent':'POKROV-local-dependency-review'},method='POST')
with urllib.request.urlopen(req,timeout=45) as r:result=json.load(r)
(out/'osv-response-public-packages.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());assert len(result['results'])==len(keys)
assert not any(x.get('next_page_token') for x in result['results']),'Unconsumed pagination: inspect before using summary'
rows=[{'ecosystem':k[0],'name':k[1],'version':k[2],'surfaces':sorted(set(cohorts[k])),'advisories':r.get('vulns',[])}for k,r in zip(keys,result['results'])]
report={'observed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Dart hosted runtime dependency graph (may include inactive platform implementations) plus selected Android directRelease and storeRelease Maven modules (exact graph equality checked); only public package names/versions queried. Not byte-level reachability or native/Flutter engine clearance.','packages':rows,'excluded_non_public_or_engine_coordinates':excluded,'advisory_package_count':sum(bool(x['advisories']) for x in rows)}
(out/'osv-runtime-graph-summary.json').write_bytes((json.dumps(report,indent=2)+'\n').encode());print('Queries',len(rows),'Pub',sum(x['ecosystem']=='Pub'for x in rows),'Maven',sum(x['ecosystem']=='Maven'for x in rows),'packages with findings',report['advisory_package_count'])
for row in rows:
 if row['advisories']:print(row['ecosystem'],row['name'],row['version'],[x['id'] for x in row['advisories']])
