from pathlib import Path
import json,subprocess,shutil,psutil,datetime
out=Path(__file__).parent;v='C:/Program Files/Oracle/VirtualBox/VBoxManage.exe';vm='e42043a3-dd4d-452b-b151-410ad5d49543'
s=subprocess.check_output([v,'showvminfo',vm,'--machinereadable'],text=True)
assert 'VMState="poweroff"' in s and 'nic1="none"' in s
ids=[l for l in s.splitlines() if l.startswith('SnapshotUUID')]
old=json.loads((out/'vm-before.json').read_bytes())
assert ids==[l for l in old['before'] if l.startswith('SnapshotUUID')]
floor=40*2**30;free={p:shutil.disk_usage(p).free for p in ['C:/','E:/']}
leaf=Path(old['leaf']);growth=leaf.stat().st_size-old['leaf_bytes_before']
assert growth<old['growth_budget_bytes'] and free['E:/']>floor+int(1.5*2**30) and free['C:/']>floor+256*2**20
assert psutil.virtual_memory().available>12*2**30
assert not subprocess.check_output([v,'list','runningvms'],text=True).strip()
report={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'vm':vm,'snapshots_retained':len(ids),'offline_stage_poweroff':True,'free_before':free,'leaf_growth_offline':growth,'nic_before':'none','nic_for_runtime':'bridged','bridge':'Intel(R) Ethernet Controller (3) I225-V','host_network_mutation':'NONE','budget_usd':0,'remaining_leaf_growth_budget_bytes':old['growth_budget_bytes']-growth,'restore_target':'poweroff; nic1 none'}
(out/'network-vm-before.json').write_text(json.dumps(report,indent=2)+'\n')
subprocess.run([v,'modifyvm',vm,'--nic1','bridged','--bridgeadapter1',report['bridge']],check=True)
with (out/'network-vm-start.log').open('wb') as log:subprocess.run([v,'startvm',vm,'--type','separate'],stdout=log,stderr=subprocess.STDOUT,check=True)
print('PASS same managed VM started with guest bridge; all snapshots retained')
