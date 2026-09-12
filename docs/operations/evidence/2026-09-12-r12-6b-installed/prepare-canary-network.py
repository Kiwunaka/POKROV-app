from pathlib import Path
out=Path(__file__).parent
text=(out/'watch-canary-vm.py').read_text()
text=text.replace("'canary-vm-", "'canary-network-vm-")
text=text.replace("'nic':'none'", "'nic_before':'none','nic_for_runtime':'bridged','bridge':'Intel(R) Ethernet Controller (3) I225-V'")
needle="with (out/'canary-network-vm-start.log').open('wb') as log:"
assert text.count(needle)==1
text=text.replace(needle,"subprocess.run([v,'modifyvm',vm,'--nic1','bridged','--bridgeadapter1','Intel(R) Ethernet Controller (3) I225-V'],check=True)\n"+needle)
text=text.replace('elapsed>=480','elapsed>=600')
needle="(out/'canary-network-vm-result.json').write_text"
assert text.count(needle)==1
text=text.replace(needle,"if not paused:\n    subprocess.run([v,'modifyvm',vm,'--nic1','none'],check=True)\n    r['nic_restored']='none'\n"+needle)
(out/'watch-canary-network-vm.py').write_text(text)
print('Prepared guarded network VM stage; same prior physical bridge, shutdown at 400MiB, pause at 700MiB, 10 minute timeout')
