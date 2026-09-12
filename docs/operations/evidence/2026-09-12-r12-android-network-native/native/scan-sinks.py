from pathlib import Path
import json,shlex,datetime
import baseline as b
from exercise import scan
out=Path(__file__).parent
paths=b.root('find '+shlex.quote(b.private)+' -type f').decode().splitlines()
selected=[p for p in paths if '/r12-private-rollback-' not in p and (p.endswith(('.log','.jsonl')) or p.endswith('/previous-exit.v1.json'))]
rows=[]
for p in selected:
 raw=b.read(p)
 rows.append({'relative_path':p.removeprefix(b.private+'/'),'bytes':len(raw),'sha256':b.sha(raw),'markers':scan(raw)})
r={'status':'PASS' if rows and all(not any(x['markers'].values()) for x in rows) else 'FAIL','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'existing app-private .log .jsonl and previous-exit.v1.json files after six injected native service failures','sinks':rows,'raw_content_exported':False}
(out/'persisted-sinks.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
assert r['status']=='PASS'
