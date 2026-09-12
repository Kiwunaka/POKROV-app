from pathlib import Path
import json,xml.etree.ElementTree as ET,shlex,datetime
import baseline as b
import ui
out=Path(__file__).parent;record=json.loads((out/'rollback-prepared.json').read_bytes())
backup=b.private+'/files/r12-private-rollback-a9-20260912'
prefs=b.private+'/shared_prefs/pokrov_runtime_profile.xml'
original=b.read(backup+'/preferences');content=b.read(backup+'/profile')
assert b.sha(original)==record['preferences_sha256'] and b.sha(content)==record['profile_sha256']
tree=ET.fromstring(original);profile=next(n.text for n in tree if n.get('name')=='config_path')
assert profile.startswith(b.private+'/files/pokrov-runtime/working/configs/') or profile.startswith('/data/data/'+ui.pkg+'/files/pokrov-runtime/working/configs/')
ui.run('shell','am','force-stop',ui.pkg)
b.root('cat '+shlex.quote(backup+'/profile')+' > '+shlex.quote(profile)+' && cat '+shlex.quote(backup+'/preferences')+' > '+shlex.quote(prefs))
assert b.read(profile)==content and b.read(prefs)==original
r={'status':'PASS_BYTE_EXACT_PRIVATE_ROLLBACK','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'profile_sha256':b.sha(content),'preferences_sha256':b.sha(original),'backup_retained_guest_private':True,'app_force_stopped':True,'in_memory_core_events_lost_by_restart':True,'method':'guest-local retained rollback; no live profile in host command line'}
(out/'profile-restored.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
