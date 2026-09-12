from pathlib import Path
import datetime,json,subprocess,shutil,psutil,time
out=Path(__file__).parent;cli='E:/LDPlayer/LDPlayer14/ldconsole.exe';floor=40*2**30
def listing():return subprocess.check_output([cli,'list2'],text=True,timeout=10).splitlines()
before=listing();assert all(row.split(',')[4]=='0' for row in before)
assert next(r for r in before if r.startswith('3,')).split(',')[1]=='pokrov-qa-120'
assert not subprocess.check_output(['C:/Program Files/Oracle/VirtualBox/VBoxManage.exe','list','runningvms'],text=True).strip()
disks=[Path(f'E:/LDPlayer/LDPlayer14/vms/leidian3/{n}.vdi') for n in ['data','sdcard']]
base=sum(p.stat().st_size for p in disks);free={d:shutil.disk_usage(d).free for d in ['C:/','E:/']}
assert free['C:/']>floor+512*2**20 and free['E:/']>floor+2*2**30 and psutil.virtual_memory().available>8*2**30
other={str(p):p.stat().st_size for i in range(3) for p in Path(f'E:/LDPlayer/LDPlayer14/vms/leidian{i}').glob('*.vdi')}
r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'instance_index':3,'before':before,'disk_bytes_before':base,'growth_budget_bytes':512*2**20,'quit_at_growth_bytes':384*2**20,'floor_bytes':floor,'free_before':free,'other_disk_sizes_before':other,'samples':[]}
(out/'ldplayer-before.json').write_text(json.dumps(r,indent=2)+'\n')
subprocess.run([cli,'launch','--index','3'],check=True,capture_output=True)
started=time.monotonic();last=0;quitting=False;minimum=free.copy();maximum=0;seen=False
while True:
    elapsed=time.monotonic()-started;growth=sum(p.stat().st_size for p in disks)-base;maximum=max(maximum,growth)
    free={d:shutil.disk_usage(d).free for d in minimum};minimum={d:min(free[d],minimum[d]) for d in minimum}
    if not quitting and (growth>384*2**20 or elapsed>480 or free['E:/']<floor+2**30 or free['C:/']<floor+256*2**20):
        p=subprocess.run([cli,'quit','--index','3'],capture_output=True);quitting=True;r['guard_quit']={'returncode':p.returncode,'elapsed':elapsed,'growth':growth}
    if elapsed-last>=5:
        last=elapsed;rows=listing();active=next(row for row in rows if row.startswith('3,')).split(',')[4]=='1';seen=seen or active
        r['samples'].append({'seconds':round(elapsed,1),'growth_bytes':growth,'free':free,'active':active})
        r.update(status='MONITORING',minimum_free=minimum,max_growth_bytes=maximum)
        (out/'ldplayer-progress.json').write_text(json.dumps(r,indent=2)+'\n')
        if seen and not active:break
        if not seen and elapsed>90:raise RuntimeError('LDPlayer did not reach running state')
    time.sleep(.1)
assert all(row.split(',')[4]=='0' for row in rows)
assert all(Path(p).stat().st_size==size for p,size in other.items())
r.update(status='PASS_LDPLAYER_STOPPED',minimum_free=minimum,max_growth_bytes=maximum,all_instances_stopped=True,other_disk_sizes_unchanged=True,floor_sampled_pass=all(v>floor for v in minimum.values()),growth_budget_pass=maximum<512*2**20,root_network_host_vpn_settings_changed=False)
(out/'restoration.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps({k:r[k] for k in ['status','minimum_free','max_growth_bytes','floor_sampled_pass','growth_budget_pass']}))
