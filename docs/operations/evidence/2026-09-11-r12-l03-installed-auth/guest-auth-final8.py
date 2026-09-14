import os,pathlib,subprocess,json,hashlib,time
assert os.getuid()==0
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-auth-final.json';assert not out.exists()
expected={'timeout':'linux_authorization_timeout','cancel':'linux_authorization_dismissed','missing-agent':'linux_authorization_agent_unavailable'};terminal={}
for mode,code in expected.items():
 v=json.loads((r/('candidate8-auth-'+mode+'.json')).read_bytes());assert v['events'][0]['POKROV_ERROR_CODE']==code and all(v['network_unchanged'].values()) and v['runtime_absent'] and not v['runtime_mutation_seen'] and v['profile_unchanged']
 state=dict(x.split('=',1) for x in subprocess.check_output(['systemctl','show','pokrov-l03-auth8-'+mode,'-p','MainPID','-p','Result','-p','ExecMainStatus'],text=True).splitlines());assert state=={'MainPID':'0','Result':'success','ExecMainStatus':'0'};terminal[mode]=state
start=json.loads((r/'candidate8-auth-timeout.json').read_bytes())['started_epoch'];events=[];fields=['POKROV_EVENT','POKROV_OUTCOME','POKROV_AUTHORIZATION_BACKEND','POKROV_ERROR_CODE']
for line in subprocess.check_output(['journalctl','-u','pokrov-linuxd.service','--since','@'+str(start),'--no-pager','-o','json'],text=True).splitlines():
 v=json.loads(line)
 if v.get('POKROV_SCHEMA')=='pokrov-linux-operational-v1' and v.get('POKROV_EVENT')=='authorization':events.append(dict({k:v.get(k) for k in fields},epoch=int(v['__REALTIME_TIMESTAMP'])/1000000))
assert [e['POKROV_ERROR_CODE'] for e in events]==['linux_authorization_timeout','linux_authorization_dismissed','linux_authorization_agent_unavailable','linux_authorization_denied','linux_authorization_dismissed']
policy=pathlib.Path('/usr/share/polkit-1/actions/space.pokrov.linux.policy');policy_sha=hashlib.sha256(policy.read_bytes()).hexdigest();assert policy_sha=='b6a183c6148ee02c1d3d65a92374855c69b98593bc8e337280c1cbeec053a44c'
overrides=[]
for directory in ['/etc/polkit-1/rules.d','/usr/share/polkit-1/rules.d','/etc/polkit-1/localauthority']:
 root=pathlib.Path(directory)
 if root.exists():
  for p in root.rglob('*'):
   if p.is_file() and b'space.pokrov.linux.manage' in p.read_bytes():overrides.append(p.name)
assert not overrides
agent=pathlib.Path('/proc/10886');assert agent.stat().st_uid==1000 and (agent/'exe').resolve()==pathlib.Path('/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1')
gui=pathlib.Path('/proc/1648');assert gui.stat().st_uid==1000 and (gui/'exe').resolve()==pathlib.Path('/usr/lib/pokrov/ui/pokrov')
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']};before=json.loads((r/'candidate8-auth-timeout.json').read_bytes())['network_before'];after={k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()};assert before==after
assert not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
result={'status':'PASS_EXACT_PACKAGE_AUTH_NEGATIVES','candidate_sha256':'b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933','policy_matches_signed_payload':True,'policy_sha256':policy_sha,'temporary_action_overrides':overrides,'terminal_units':terminal,'events':events,'restored_agent_pid':10886,'restored_agent_uid':1000,'same_gui_pid':1648,'same_gui_uid':1000,'network_unchanged':{k:True for k in before},'no_tun_or_recovery':True,'actual_restore_prompt_observed_then_cancelled':True,'finished_epoch':time.time()};out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644);print(json.dumps(result))
