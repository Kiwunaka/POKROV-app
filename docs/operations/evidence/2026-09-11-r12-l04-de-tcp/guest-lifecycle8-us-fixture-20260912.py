from pathlib import Path
import copy,hashlib,json,os,platform,socket,subprocess,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-lifecycle-us-fixture-20260912.json';assert not out.exists()
profile=Path('/var/lib/pokrov/profiles/active-profile.json');original=profile.read_bytes();assert hashlib.sha256(original).hexdigest()=='9b6f73f24726f32a97ee646081879bc6dfd19f63376cb2c33f58c7766c80d257'
assert not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists()
config=json.loads(original);node=config['outbounds'][29];assert node['type']=='vless' and not node.get('detour') and hashlib.sha256(node['server'].encode()).hexdigest()=='3ec0f5e9e476fe6621718f62f9aaea224016d6e710946c868b601a15ecfa046b'
with socket.create_connection((node['server'],node['server_port']),timeout=4):pass
commands={'routes4':['ip','-j','-4','route','show','table','all'],'routes6':['ip','-j','-6','route','show','table','all'],'rules4':['ip','-j','-4','rule'],'rules6':['ip','-j','-6','rule'],'nft':['nft','-j','list','ruleset'],'dns':['resolvectl','dns'],'domains':['resolvectl','domain']}
network=lambda:{k:hashlib.sha256(subprocess.check_output(v)).hexdigest() for k,v in commands.items()};before=network()
selected=copy.deepcopy(node);selected['tag']=config['outbounds'][0]['tag'];config['outbounds'][0]=selected
result={'artifact_sha256':'b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933','origin':'existing MINI Ubuntu guest; root fixture IPC','started_epoch':time.time(),'original_profile_sha256':hashlib.sha256(original).hexdigest(),'fixture_source_outbound_index':29,'fixture_server_sha256':hashlib.sha256(node['server'].encode()).hexdigest(),'tcp_preflight_pass':True,'default_de_failure_remains_open':True}
def save():out.write_text(json.dumps(result,indent=2)+'\n');out.chmod(0o644)
save()
try:
 profile.write_text(json.dumps(config));profile.chmod(0o600);result['fixture_profile_sha256']=hashlib.sha256(profile.read_bytes()).hexdigest();save()
 with (r/'candidate8-lifecycle-us-outer-20260912.log').open('w') as log:
  p=subprocess.run(['python3',str(r/'guest-lifecycle8-us-20260912.py')],stdout=log,stderr=subprocess.STDOUT)
 result['lifecycle_exit']=p.returncode
finally:
 if Path('/sys/class/net/pokrov0').exists() or Path('/var/lib/pokrov/network-recovery.json').exists():
  with socket.socket(socket.AF_UNIX) as s:
   s.settimeout(130);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall(b'{"protocol":"pokrov-linuxd-v1","request_id":"l04-us-fixture-restore","action":"disconnect","payload":{}}\n');assert json.loads(s.makefile('rb').readline(65537)).get('ok')
 profile.write_bytes(original);profile.chmod(0o600);result['original_profile_restored']=hashlib.sha256(profile.read_bytes()).hexdigest()==result['original_profile_sha256']
 after=network();result['network_restored']={k:v==after[k] for k,v in before.items()};result['runtime_absent']=not Path('/sys/class/net/pokrov0').exists() and not Path('/var/lib/pokrov/network-recovery.json').exists();result['finished_epoch']=time.time();result['status']='PASS_US_FIXTURE_LIFECYCLE_AND_ORIGINAL_RESTORATION' if result.get('lifecycle_exit')==0 and result['original_profile_restored'] and all(result['network_restored'].values()) and result['runtime_absent'] else 'FAIL_WITH_RESTORATION';save()
print(json.dumps(result));assert result['status'].startswith('PASS_US')
