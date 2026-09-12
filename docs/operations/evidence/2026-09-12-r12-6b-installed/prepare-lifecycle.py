from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent;prior=Path('C:/r12-c02-20260911');package=Path('C:/r12-c05-setup-privacy-20260912')
audit=json.loads((package/'windows-package-audit.json').read_bytes())
row=next(x for x in audit['bundle_inventory'] if x['relative_path']=='pokrov-core.dll')
dll=Path(row['path']);native=Path('C:/r12corec02/dist/windows/pokrov-core.dll')
assert hashlib.sha256(dll.read_bytes()).hexdigest()==row['sha256']=='40101389b7713b869a9472bd3afe3aa19000b1d98f79d50cb88b61a235be531e'
assert dll.read_bytes()==native.read_bytes()
text=(prior/'artifact-lifecycle-v2.py').read_text()
needle="dll = root / 'windows-a/pokrov-core.dll'\nassert dll.read_bytes() == (root / 'windows-b/pokrov-core.dll').read_bytes()"
assert needle in text
text=text.replace(needle,"dll = Path("+repr(dll.as_posix())+")\nassert hashlib.sha256(dll.read_bytes()).hexdigest() == '40101389b7713b869a9472bd3afe3aa19000b1d98f79d50cb88b61a235be531e'\nassert dll.read_bytes() == Path('C:/r12corec02/dist/windows/pokrov-core.dll').read_bytes()")
text=text.replace("fixture = root / 'artifact-loopback-fixture-v2'", "fixture = root / 'current-core-loopback-fixture'")
text=text.replace("'artifact-lifecycle-v2.json'", "'current-core-lifecycle.json'")
text=text.replace("import hashlib, json, socket, struct, threading, time, runpy", "import hashlib, json, socket, struct, threading, time, runpy, os\nassert not os.environ.get('GOMAXPROCS')")
(out/'current-core-lifecycle.py').write_text(text)
(out/'handle-types.py').write_bytes((prior/'handle-types.py').read_bytes())
print('Prepared existing 300-cycle loopback test against exact packaged Core6b DLL')
