import pathlib,json,hashlib,subprocess,stat,os
r=pathlib.Path('/home/pokrovqa/acceptance-inputs')
result={'candidate_sha256':json.loads((r/'clean-install.json').read_text())['sha256'],'permissions':{},'payload_hashes':{},'service_properties':{}}
for p in ['/var/lib/pokrov','/var/lib/pokrov/profiles','/var/lib/pokrov/profiles/active-profile.json','/run/pokrov','/run/pokrov/pokrov-linuxd.sock','/usr/bin/pokrov','/usr/lib/pokrov/ui/pokrov','/usr/lib/pokrov/pokrov-linuxd','/usr/lib/pokrov/pokrov-core','/usr/lib/systemd/system/pokrov-linuxd.service']:
 x=pathlib.Path(p);s=x.stat();result['permissions'][p]={'mode':oct(s.st_mode&0o777),'uid':s.st_uid,'gid':s.st_gid,'type':'socket' if stat.S_ISSOCK(s.st_mode) else 'directory' if x.is_dir() else 'file'}
for name in ['pokrov-linuxd','pokrov-core']:
 p=pathlib.Path('/usr/lib/pokrov')/name;result['payload_hashes'][name]=hashlib.sha256(p.read_bytes()).hexdigest()
for unit in ['pokrov-linuxd.service','pokrov-linuxd.socket','pokrov-linux-sleep.service']:
 result['service_properties'][unit]=subprocess.check_output(['systemctl','show',unit,'-p','User','-p','Group','-p','StateDirectoryMode','-p','KillMode','-p','LoadState','-p','UnitFileState'],text=True).splitlines()
p=r/'candidate7-installed-permissions.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
