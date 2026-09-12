from pathlib import Path
import json,hashlib,zipfile
out=Path(__file__).parent
prior=Path('C:/r12-c05-packages-20260911')
source='2aa57015783ceb3415e3be62bbf0a698729011c4'
sha=lambda b:hashlib.sha256(b).hexdigest()
old=json.loads((prior/'android-dex-identity.json').read_bytes())
rows=[]
for row in old:
    p=Path(row['path'])
    with zipfile.ZipFile(p) as z:
        dex={n:sha(z.read(n)) for n in z.namelist() if n.endswith('.dex')}
    assert dex==row['dex'], p.name
    rows.append({'path':str(p),'sha256':sha(p.read_bytes()),'dex':dex,'exact_prior_dex_sha256_match':True})
(out/'android-dex-current-binding.json').write_text(json.dumps({'status':'PASS_EXACT_PRIOR_PARSED_DEX_BYTES','source_client':source,'prior_identity_sha256':sha((prior/'android-dex-identity.json').read_bytes()),'artifacts':rows},indent=2)+'\n')
text=(prior/'audit-android.py').read_text().replace("out = Path('C:/r12-c05-packages-20260911')","out = Path(__file__).parent\nprior = Path('C:/r12-c05-packages-20260911')\nsource_client='"+source+"'")
old_line="expected_core = {abi: sha((Path('C:/r12-c05-utls-update-20260911/binary-scans/native') / f'libpokrov-core-{abi}.so').read_bytes()) for abi in flutter}"
assert old_line in text
text=text.replace(old_line,"with zipfile.ZipFile('C:/r12corec02/dist/android/pokrov-core.aar') as core_archive:\n    expected_core = {abi: sha(core_archive.read('jni/'+abi+'/libpokrov-core.so')) for abi in flutter}")
text=text.replace("else: assert n.endswith('/libapp.so'), f'Unclassified library: {n}'", "else:\n                assert n.endswith('/libapp.so'), f'Unclassified library: {n}'\n                assert source_client.encode() in b, 'Expected compiled client revision absent'")
text=text.replace("(out / ('android-dex-packages-'", "(prior / ('android-dex-packages-'")
text=text.replace("(out/'android-dex-parsing.json')", "(prior/'android-dex-parsing.json')")
text=text.replace("'observed_at': datetime", "'source_client': source_client, 'source_core': '6b271decead88b708e2fc03984b703b0a4e63ebd',\n          'dex_current_binding': ref(out/'android-dex-current-binding.json'),\n          'observed_at': datetime")
(out/'audit-android.py').write_text(text,encoding='utf-8')
print('PASS exact prior parsed DEX bytes in all five current packages; audit prepared')
