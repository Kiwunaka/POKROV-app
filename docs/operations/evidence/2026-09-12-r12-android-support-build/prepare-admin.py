from pathlib import Path
import json
out=Path(__file__).parent;v=json.loads((out/'owned-case-readback.json').read_bytes())
s=Path('C:/r12-6b-installed-20260912/admin-scan-remote.py').read_text()
for old,new in {'CASE = 57':'CASE = 58',"dt.datetime(2026, 9, 10, 14, 7)":"dt.datetime(2026, 9, 12, 4, 23)",'a33b11cc8d38e396fcfb0c34b8fcb475929a5d7ce056f4e9a3aa9da52ecfbde5':v['bundle']['expected_sha256'],'fe746f1300ba28298736b684b3b272af2f0c3d02cf4934def66ee98f581475d0':v['install_sha256'],'PASS_NATIVE_SUMMARY_CANARY_SCAN':'PASS_ANDROID_SUMMARY_ACCESS_SCAN'}.items():assert old in s;s=s.replace(old,new)
s=s.replace("'external_oidc_retested': False", "'external_oidc_retested': False, 'planted_native_to_app_canaries_exercised': False")
s=s.replace("        assert not contains_canary(content)\n", "        assert not contains_canary(content)\n        if item['path'] == 'build/identity.json':\n            ident = json.loads(content)\n            report['build_identity'] = {k: ident.get(k) for k in ['app_version','build_number','platform','channel','candidate_label','git_revision','architecture']}\n")
compile(s,'admin-scan-remote.py','exec');(out/'admin-scan-remote.py').write_text(s,encoding='utf8')
s=Path('C:/r12-6b-installed-20260912/admin-scan.py').read_text().replace('PASS_NATIVE_SUMMARY_CANARY_SCAN','PASS_ANDROID_SUMMARY_ACCESS_SCAN')
(out/'admin-scan.py').write_text(s,encoding='utf8')
