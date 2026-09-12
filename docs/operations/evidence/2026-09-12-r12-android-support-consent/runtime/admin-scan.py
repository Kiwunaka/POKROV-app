import hashlib, json, shlex, subprocess
from pathlib import Path
out = Path(__file__).parent
remote = (out / 'admin-scan-remote.py').read_text(encoding='utf8')
compile(remote, 'admin-scan-remote.py', 'exec')
p = subprocess.run(['ssh.exe', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes', 'pokrov-brain', '/root/portal_bot/venv/bin/python -c ' + shlex.quote(remote)], capture_output=True, text=True, timeout=70)
assert p.stdout.strip(), {'exit': p.returncode, 'stderr_sha256': hashlib.sha256(p.stderr.encode()).hexdigest()}
r = json.loads(p.stdout)
target = out / 'native-admin-payload-scan.json'; assert not target.exists()
target.write_text(json.dumps(r, indent=2) + '\n', encoding='utf8')
print(json.dumps(r))
assert p.returncode == 0 and r['status'] == 'PASS_ANDROID_SUMMARY_ACCESS_SCAN'
