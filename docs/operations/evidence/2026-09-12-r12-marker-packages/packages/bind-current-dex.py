from pathlib import Path
import json,hashlib,zipfile
out=Path(__file__).parent
prior=Path('C:/r12-c05-packages-20260911')
source='8067520c7b9230ab0c66823fae9ae78791f1a838'
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
print('PASS all current DEX bytes exactly match prior parsed artifacts')
