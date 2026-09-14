import pathlib,os,signal,time,json
assert os.getuid()==0
p=pathlib.Path('/proc/1590');expected=pathlib.Path('/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1');assert p.stat().st_uid==1000 and (p/'exe').resolve()==expected
assert not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
os.kill(1590,signal.SIGTERM)
for _ in range(20):
 if not (p/'exe').exists():break
 time.sleep(.1)
assert not (p/'exe').exists()
agents=[]
for entry in pathlib.Path('/proc').iterdir():
 if entry.name.isdigit():
  try:
   if (entry/'exe').resolve()==expected and entry.stat().st_uid==1000:agents.append(int(entry.name))
  except OSError:pass
assert not agents
out=pathlib.Path('/home/pokrovqa/acceptance-inputs/candidate8-auth-agent-stop.json');assert not out.exists();v={'status':'STOPPED_EXACT_DESKTOP_AGENT','pid':1590,'uid':1000,'executable':str(expected),'remaining_same_user_agents':agents,'no_policy_change':True,'epoch':time.time()};out.write_text(json.dumps(v,indent=2)+'\n');out.chmod(0o644);print(json.dumps(v))
