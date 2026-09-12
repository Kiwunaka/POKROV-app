import datetime,json,pathlib,subprocess
p=pathlib.Path(__file__).parent
report=[]
for label,repo in [('core','Kiwunaka/pokrov-core'),('client','Kiwunaka/POKROV-app')]:
 after=json.loads(subprocess.check_output(['gh','api',f'repos/{repo}/branches/main/protection']))
 before=json.loads((p/(label+'-protection-before.json')).read_bytes())
 assert after==before
 (p/(label+'-protection-after.json')).write_text(json.dumps(after,indent=2)+'\n')
 report.append({'repository':repo,'protection_unchanged':True,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
(p/'protection-comparison.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
