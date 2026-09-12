from pathlib import Path
import json,subprocess,shutil,psutil,datetime,time
out=Path(__file__).parent;v='C:/Program Files/Oracle/VirtualBox/VBoxManage.exe';vm='e42043a3-dd4d-452b-b151-410ad5d49543'
def info():return subprocess.check_output([v,'showvminfo',vm,'--machinereadable'],text=True)
s=info();assert 'VMState="poweroff"' in s and 'nic1="none"' in s
old=json.loads((out/'vm-before.json').read_bytes());leaf=Path(old['leaf']);floor=40*2**30
ids=[l for l in s.splitlines() if l.startswith('SnapshotUUID')]
assert ids==[l for l in old['before'] if l.startswith('SnapshotUUID')]
free={p:shutil.disk_usage(p).free for p in ['C:/','E:/']}
assert free['E:/']>floor+int(1.5*2**30) and free['C:/']>floor+512*2**20
assert psutil.virtual_memory().available>12*2**30
assert not subprocess.check_output([v,'list','runningvms'],text=True).strip()
baseline=leaf.stat().st_size
r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'vm':vm,'snapshots_retained':len(ids),'nic_before':'none','nic_for_runtime':'bridged','bridge':'Intel(R) Ethernet Controller (3) I225-V','leaf':str(leaf),'leaf_before_bytes':baseline,'growth_budget_bytes':2**30,'shutdown_at_growth_bytes':400*2**20,'pause_at_growth_bytes':700*2**20,'floor_bytes':floor,'free_before':free,'host_network_mutation':'NONE','budget_usd':0,'samples':[]}
(out/'canary-network-vm-before.json').write_text(json.dumps(r,indent=2)+'\n')
subprocess.run([v,'modifyvm',vm,'--nic1','bridged','--bridgeadapter1','Intel(R) Ethernet Controller (3) I225-V'],check=True)
with (out/'canary-network-vm-start.log').open('wb') as log:subprocess.run([v,'startvm',vm,'--type','separate'],stdout=log,stderr=subprocess.STDOUT,check=True)
started=time.monotonic();last=0;shutdown=False;paused=False;minimum=free.copy();max_growth=0
while True:
    elapsed=time.monotonic()-started;free={p:shutil.disk_usage(p).free for p in minimum};growth=leaf.stat().st_size-baseline
    minimum={p:min(minimum[p],free[p]) for p in minimum};max_growth=max(max_growth,growth)
    if not paused and (growth>=700*2**20 or free['E:/']<floor+768*2**20 or free['C:/']<floor+256*2**20):
        result=subprocess.run([v,'controlvm',vm,'pause'],capture_output=True,text=True)
        paused=result.returncode==0
        r['pause_result']={'returncode':result.returncode,'elapsed_seconds':round(elapsed,2),'growth_bytes':growth}
        if paused:break
    if not shutdown and (growth>=400*2**20 or elapsed>=600):
        result=subprocess.run([v,'controlvm',vm,'acpipowerbutton'],capture_output=True,text=True);shutdown=result.returncode==0
        r['shutdown_result']={'returncode':result.returncode,'elapsed_seconds':round(elapsed,2),'growth_bytes':growth}
    if elapsed-last>=5:
        last=elapsed;s=info();state=next(l for l in s.splitlines() if l.startswith('VMState='))
        r['samples'].append({'seconds':round(elapsed,1),'growth_bytes':growth,'free':free,'state':state})
        r.update(minimum_free=minimum,max_growth_bytes=max_growth,status='MONITORING')
        (out/'canary-network-vm-progress.json').write_text(json.dumps(r,indent=2)+'\n')
        if state=='VMState="poweroff"':break
    time.sleep(.1)
r.update(status='PAUSED_FOR_STORAGE_RESERVE' if paused else 'PASS_VM_POWERED_OFF',minimum_free=minimum,max_growth_bytes=max_growth,final_state=[l for l in info().splitlines() if l.startswith(('VMState=','nic1=','SnapshotUUID'))],sample_interval_seconds=.1,continuous_floor_sampled_pass=all(n>floor for n in minimum.values()),growth_budget_pass=max_growth<2**30)
if not paused:
    subprocess.run([v,'modifyvm',vm,'--nic1','none'],check=True)
    r['nic_restored']='none'
(out/'canary-network-vm-result.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:r[k] for k in ['status','minimum_free','max_growth_bytes','continuous_floor_sampled_pass','growth_budget_pass']}))
