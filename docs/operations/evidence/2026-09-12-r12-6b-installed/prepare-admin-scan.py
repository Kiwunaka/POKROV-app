from pathlib import Path
import json
out=Path(__file__).parent;prior=Path('C:/r12-v01-native-20260910')
before=json.loads((out/'owned-support-before.json').read_bytes());after=json.loads((out/'owned-support-after.json').read_bytes())
old={b['expected_sha256'] for t in before['tickets'] for b in t['bundles']}
new=[(t,b) for t in after['tickets'] for b in t['bundles'] if b['expected_sha256'] not in old]
assert len(new)==1;t,b=new[0]
assert t['case_number']==57 and b['status']=='validated' and b['diagnostic_profile']=='summary'
text=(prior/'admin-scan-remote.py').read_text()
changes={"CASE = 52":"CASE = 57", "a4e7d6897198a9d9419d351590c423c9b28221a53cb84d8178e9d88cfb3a98ad":b['expected_sha256'], 'r12v01-20260910':'r126b-20260912','203.0.113.197':'203.0.113.198',"SupportBundleUpload.ticket_id == CASE).one()":"SupportBundleUpload.ticket_id == CASE, SupportBundleUpload.expected_sha256 == CIPHER_SHA).one()", "bundles = detail['support_bundles']; assert len(bundles) == 1":"bundles = [b for b in detail['support_bundles'] if b['diagnostic_profile'] == 'summary']; assert len(bundles) == 1", "        ticket.status = 'closed'; ticket.closed_at = now(); ticket.updated_at = now(); s.commit()\n        report['own_case_closed'] = True":"        report['existing_case_status_preserved'] = ticket.status"}
for old,new in changes.items():assert old in text; text=text.replace(old,new)
compile(text,'admin-scan-remote.py','exec')
(out/'admin-scan-remote.py').write_text(text)
(out/'admin-scan.py').write_text((prior/'admin-scan.py').read_text())
profile=(prior/'profile-restoration.ps1').read_text().replace('r12v01-20260910','r126b-20260912').replace('203.0.113.197','203.0.113.198').replace('C:/Users/Public/R12V01Native','C:/Users/Public/R126b20260912')
(out/'profile-restoration.ps1').write_text(profile)
ob=(prior/'outbox-readback.ps1').read_text().replace('a4e7d6897198a9d9419d351590c423c9b28221a53cb84d8178e9d88cfb3a98ad',b['expected_sha256'])
(out/'outbox-readback.ps1').write_text(ob)
print('Prepared exact new summary bundle access scan; existing ticket status preserved')
