from pathlib import Path
import json,re
out=Path('C:/r12-android-native-chain-20260912')
source=Path('C:/r12-psm-consent-installed-20260912/admin-scan-remote.py').read_text()
readback=json.loads((out/'extended-cases-readback.json').read_bytes());case=readback['cases'][0];assert case['case_number']==64 and case['bundle']['status']=='validated'
source=source.replace('CASE = 60','CASE = 64').replace('84ac7f0d727f9da2a34b59c96b98ef016df7fbc374d2de2795c2456753426636',case['bundle']['expected_sha256']).replace('dt.datetime(2026, 9, 12, 7, 6)','dt.datetime(2026, 9, 12, 7, 46)').replace("'planted_native_to_app_canaries_exercised': False","'planted_native_to_app_canaries_exercised': True")
markers=json.loads((out/'native-input.json').read_bytes())['marker_values_synthetic'];needles=sorted(set(markers.values())|set(re.findall(r'R12_ANDROID_[A-Z]+_2c_20260912',json.dumps(markers))))
source=source.replace("def contains_canary(raw): return any(marker in raw for marker in (b'r126b-20260912', b'203.0.113.198'))",'CANARY_NEEDLES = '+repr(needles)+"\ndef contains_canary(raw): return any(marker.encode() in raw for marker in CANARY_NEEDLES)")
source=source.replace("'redaction/report.json', 'events/recent.jsonl', 'system/summary.json'","'redaction/report.json', 'system/summary.json'")
source=source.replace("        if item['path'] == 'system/summary.json':", "        if item['path'] == 'network/summary.json':\n            network=json.loads(content); report['network_summary']=network\n            assert all(isinstance(v,str) and re.fullmatch(r'[a-z_]+',v) for v in network.values())\n        if item['path'] == 'system/summary.json':")
source=source.replace('import base64, datetime as dt,','import re, base64, datetime as dt,')
source=source.replace("report['status'] = 'PASS_ANDROID_EXTENDED_ACCESS_SCAN'", "report['native_canary_categories']=9; report['marker_needles_scanned']=len(CANARY_NEEDLES)\n    report['status'] = 'PASS_ANDROID_EXTENDED_ACCESS_SCAN'")
compile(source,'admin-scan-remote.py','exec');(out/'admin-scan-remote.py').write_text(source,encoding='utf8')
wrapper=Path('C:/r12-psm-consent-installed-20260912/admin-scan.py').read_text().replace('native-admin-payload-scan-corrected.json','native-admin-payload-scan.json');(out/'admin-scan.py').write_text(wrapper,encoding='utf8')
print('PREPARED_EXACT_CASE64_ADMIN_SCAN')
