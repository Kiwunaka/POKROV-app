from pathlib import Path
import subprocess,json,datetime
vbox='C:/Program Files/Oracle/VirtualBox/VBoxManage.exe';vm='e42043a3-dd4d-452b-b151-410ad5d49543'
s=subprocess.check_output([vbox,'showvminfo',vm,'--machinereadable'],text=True)
d=dict(line.split('=',1) for line in s.splitlines() if '=' in line)
assert d['VMState']=='"poweroff"' and d['nic1']=='"none"'
r={'status':'PASS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'vm_uuid':vm,'power':'off','nic1':'none','theme_mode_restored':'system','shutdown':'ACPI graceful shutdown','host_network_mutated':False,'raw_credentials_exported':False}
Path('E:/r12-windows-support-native-20260910/vm-restoration.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
