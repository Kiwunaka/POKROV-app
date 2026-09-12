from pathlib import Path
import json
out=Path('C:/r12-android-exit-marker-20260912');out.mkdir(exist_ok=True)
assert {p.name for p in out.iterdir()}=={'observe.py'}
old=Path('C:/r12-android-native-chain-20260912')
expected=next(r for r in json.loads((Path(__file__).parent/'direct-apks-verified.json').read_bytes())['artifacts'] if r['abi']=='x86_64')['sha256']
for name in ['ui.py','network.py','capture-ui.py','set-root.py','watch-ldplayer.py']:
    text=(old/name).read_text().replace('8dc6c2e6671b7ea3d2331c1ec31c5a788458fd10de9dd9a9693abfcd8eab62ad',expected)
    (out/name).write_text(text,encoding='utf8')
text=(old/'host-network.ps1').read_text().replace('C:\\r12-android-native-chain-20260912',str(out)).replace('C:/r12-6b-android-20260912/host-network-after.json','C:/r12-android-exit-marker-20260912/host-network-installed-before.json')
(out/'host-network.ps1').write_text(text,encoding='utf8')
print('Prepared current x86_64 marker/crash observation helpers')
