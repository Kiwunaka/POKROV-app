import pathlib,subprocess,json,datetime
r=pathlib.Path(__file__).parent
script='''import subprocess,json,shutil
def run(args):
 p=subprocess.run(args,capture_output=True,text=True,timeout=8)
 if p.returncode:return {'exit':p.returncode}
 return json.loads(p.stdout)
links=run(['ip','-details','-json','link','show']);rows=[]
for link in links:
 name=link['ifname']
 if name=='lo':continue
 row={'interface':name,'link_kind':link.get('linkinfo',{}).get('info_kind'),'xdp':link.get('xdp',{}),'qdisc':link.get('qdisc')}
 if shutil.which('tc'):
  qs=run(['tc','-j','-s','qdisc','show','dev',name]);row['qdiscs']=qs
  fs={}
  for direction in ['ingress','egress']:
   v=run(['tc','-j','-s','filter','show','dev',name,direction]);fs[direction]=v
  row['filters']=fs
 rows.append(row)
# Project only attachment kinds and counters; never publish filter matches or raw link data.
safe=[]
for row in rows:
 out={k:row[k] for k in ['interface','link_kind','qdisc']};out['xdp_attached']=bool(row['xdp']);out['xdp_mode']=row['xdp'].get('mode') if isinstance(row['xdp'],dict) else None
 out['qdiscs']=[{k:q.get(k) for k in ['kind','handle','parent','root','drops','overlimits','requeues','backlog','qlen']} for q in row.get('qdiscs',[]) if isinstance(q,dict)]
 out['filter_summary']={k:([{'kind':f.get('kind'),'pref':f.get('pref'),'options_present':bool(f.get('options'))} for f in v] if isinstance(v,list) else v) for k,v in row.get('filters',{}).items()};safe.append(out)
print(json.dumps({'links':safe,'raw_network_material_exported':False}))
'''
results=[]
for alias in ['pokrov-mini','pokrov-de']:
 p=subprocess.run(['ssh','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',alias,'sudo -n python3 -'],input=script,capture_output=True,text=True,timeout=30)
 results.append({'origin':alias,'exit':p.returncode,'projection':json.loads(p.stdout) if p.returncode==0 else None})
out=r/'de-hook-boundary.json';assert not out.exists();receipt={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'read-only link XDP and TC attachment/counter projection; no configuration changes','results':results};out.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
