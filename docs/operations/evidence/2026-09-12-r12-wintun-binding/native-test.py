from pathlib import Path
import datetime, hashlib, json, os, shutil, subprocess, tarfile, time, re

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'wintun-fix-20260912'
assert Path(__file__).resolve().parent == work
assert shutil.disk_usage(base).free > 30 * 2**30
manifest = json.loads((work / 'overlay.json').read_text())
source = work / 'source'
shutil.copytree(base / 'offline-source-2662-20260912/payload/core', source, symlinks=True)
with tarfile.open(work / 'overlay.tar.gz') as t:
    assert sorted(x.name for x in t.getmembers()) == sorted(x['path'] for x in manifest['files'])
    for row in manifest['files']:
        item = t.getmember(row['path'])
        assert item.isfile() and not Path(row['path']).is_absolute() and '..' not in Path(row['path']).parts
        raw = t.extractfile(item).read()
        assert hashlib.sha256(raw).hexdigest() == row['sha256']
        target = source / row['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
for name in ['home', 'tmp']:
    (work / name).mkdir()
for current, dirs, files in os.walk(work):
    os.chown(current, 65534, 65534)
    for name in files:
        os.chown(Path(current) / name, 65534, 65534, follow_symlinks=False)
env = {'PATH': str(base / 'tools/go/bin') + ':' + str(base / 'tools/ripgrep-14.1.1-x86_64-unknown-linux-musl') + ':/usr/bin:/bin', 'HOME': str(work / 'home'), 'GOROOT': str(base / 'tools/go'), 'GOPATH': str(base / 'gopath'), 'GOMODCACHE': str(base / 'cache/mod'), 'GOCACHE': str(base / 'cache/build'), 'GOTMPDIR': str(work / 'tmp'), 'TMPDIR': str(work / 'tmp'), 'XDG_CACHE_HOME': str(base / 'xdg'), 'DOTNET_CLI_HOME': str(base / 'dotnet'), 'DOTNET_CLI_TELEMETRY_OPTOUT': '1', 'GOTELEMETRY': 'off', 'GOENV': 'off', 'GOTOOLCHAIN': 'local', 'GOWORK': 'off', 'GOFLAGS': '-buildvcs=false -mod=readonly -p=1', 'GOMAXPROCS': '1', 'CGO_ENABLED': '1', 'GOPROXY': 'off', 'GOSUMDB': 'off', 'LANG': 'C.UTF-8'}
args = [str(base / 'tools/powershell/pwsh'), '-NoProfile', '-File', 'scripts/test.ps1', '-GoExecutable', str(base / 'tools/go/bin/go')]
result = {'status': 'RUNNING', 'base_source': manifest['base_source'], 'overlay_sha256': hashlib.sha256((work / 'overlay.tar.gz').read_bytes()).hexdigest(), 'command': args, 'network_isolated': True, 'uid': 65534, 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
(work / 'progress.json').write_text(json.dumps(result, indent=2) + '\n')
start = time.monotonic()
p = subprocess.run(['unshare', '--net', '--', 'sh', '-c', 'ip link set lo up; exec "$@"', 'fixture', 'setpriv', '--reuid=65534', '--regid=65534', '--clear-groups', *args], cwd=source, env=env, capture_output=True, text=True, timeout=2400)
lines = []
for line in re.sub(r'\x1b\[[0-9;]*m', '', p.stdout + '\n' + p.stderr).splitlines():
    line = line.strip()
    if line.startswith(('ok ', '? ', 'PASS', 'FAIL', 'WARNING: DATA RACE', 'POKROV Core tests OK.')) or re.search(r'\.go:\d+:\d+:', line):
        lines.append(line[:300])
result.update(status='PASS' if p.returncode == 0 else 'FAILED', exit_code=p.returncode, elapsed_seconds=round(time.monotonic()-start, 3), stdout_sha256=hashlib.sha256(p.stdout.encode()).hexdigest(), stderr_sha256=hashlib.sha256(p.stderr.encode()).hexdigest(), safe_summary=lines, raw_output_saved=False)
for row in manifest['files']:
    assert hashlib.sha256((source / row['path']).read_bytes()).hexdigest() == row['sha256']
(work / 'progress.json').write_text(json.dumps(result, indent=2) + '\n')
raise SystemExit(p.returncode)
