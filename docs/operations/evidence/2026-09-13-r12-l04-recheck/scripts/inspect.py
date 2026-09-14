import pathlib,subprocess,json
root=pathlib.Path('C:/r12-l04-recheck-20260913')
script='''import pathlib,json,shutil,time
r=pathlib.Path('/tmp/pokrov-r12-l04-clean-20260911');p=r/'qemu.pid';n=int(p.read_text()) if p.exists() else 0
v={'epoch':time.time(),'pid':n,'live':bool(n and pathlib.Path('/proc',str(n)).exists()),'free_bytes':shutil.disk_usage('/tmp').free}
if v['live']:v['expected_disk_in_cmdline']=str(r/'guest.qcow2').encode() in pathlib.Path('/proc',str(n),'cmdline').read_bytes()
print(json.dumps(v))
'''
p=subprocess.run(['ssh','-J','pokrov-brain','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=15','pokrov-mini','sudo -n python3 -'],input=script,text=True,capture_output=True,timeout=40)
assert p.returncode==0,p.stderr
v=json.loads(p.stdout);(root/'mini-readback.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v))
