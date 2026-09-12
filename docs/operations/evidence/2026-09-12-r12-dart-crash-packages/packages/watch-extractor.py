from pathlib import Path
import datetime, json, psutil, shutil, subprocess, time
out=Path(__file__).parent
vbox='C:/Program Files/Oracle/VirtualBox/VBoxManage.exe'
vm='POKROV-r12-b08-linux-20260906'
disk=Path('E:/r12-b08-linux-lab/lab.vdi')
floor=40*2**30
def info():
    return subprocess.check_output([vbox,'showvminfo',vm,'--machinereadable'],text=True)
assert not subprocess.check_output([vbox,'list','runningvms'],text=True).strip()
assert 'VMState="poweroff"' in info()
assert all(r.split(',')[4]=='0' for r in subprocess.check_output(['E:/LDPlayer/LDPlayer14/ldconsole.exe','list2'],text=True).splitlines())
assert shutil.disk_usage('C:/').free>floor+512*2**20
assert shutil.disk_usage('E:/').free>floor+512*2**20
assert psutil.virtual_memory().available>8*2**30
base=disk.stat().st_size
r={'status':'RUNNING','vm':vm,'before_state':'poweroff','disk_path':str(disk),'disk_bytes_before':base,'floor_bytes':floor,'growth_budget_bytes':350*2**20,'shutdown_at_growth_bytes':256*2**20,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'samples':[]}
(out/'extractor-vm-budget.json').write_text(json.dumps(r,indent=2)+'\n')
subprocess.run([vbox,'startvm',vm,'--type','headless'],check=True,capture_output=True)
start=time.monotonic();closing=False;maxgrowth=0;mins={d:shutil.disk_usage(d).free for d in ['C:/','E:/']}
while True:
    growth=disk.stat().st_size-base;maxgrowth=max(maxgrowth,growth)
    free={d:shutil.disk_usage(d).free for d in mins};mins={d:min(mins[d],free[d]) for d in mins}
    state=info();elapsed=time.monotonic()-start
    r['samples'].append({'seconds':round(elapsed,1),'growth_bytes':growth,'free':free,'powered_off':'VMState="poweroff"' in state})
    (out/'extractor-vm-progress.json').write_text(json.dumps(r,indent=2)+'\n')
    if 'VMState="poweroff"' in state:break
    if not closing and (growth>256*2**20 or elapsed>600 or min(free.values())<floor+256*2**20):
        subprocess.run([vbox,'controlvm',vm,'acpipowerbutton'],check=True,capture_output=True)
        r['guard_shutdown']={'elapsed':elapsed,'growth_bytes':growth};closing=True
    if growth>=350*2**20 or min(free.values())<floor+128*2**20:
        subprocess.run([vbox,'controlvm',vm,'poweroff'],check=True,capture_output=True)
        r['emergency_poweroff']=True
    time.sleep(.5)
r.update(status='PASS_POWERED_OFF_WITHIN_GROWTH_BUDGET',minimum_free=mins,max_growth_bytes=maxgrowth,disk_bytes_after=disk.stat().st_size,final_power_state='poweroff',installer_executed=False)
assert maxgrowth<350*2**20 and min(mins.values())>floor
(out/'extractor-vm-restoration.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:v for k,v in r.items() if k!='samples'}))
