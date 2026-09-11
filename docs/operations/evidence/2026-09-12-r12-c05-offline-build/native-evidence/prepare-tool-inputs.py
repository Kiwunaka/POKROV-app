from pathlib import Path
import datetime, hashlib, json, os, shutil, subprocess

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'offline-source-2662-20260912'
assert Path(__file__).resolve().parent == work
target = work / 'tool-inputs'
target.mkdir(mode=0o755)
for name in ('source', 'cache', 'home'):
    (target / name).mkdir(mode=0o755)
source = base / 'cache/mod/github.com/sagernet/gomobile@v0.1.11'
for name in ('go.mod', 'go.sum'):
    shutil.copyfile(source / name, target / 'source' / name)
for current, dirs, files in os.walk(target):
    os.chown(current, 65534, 65534)
    for name in files:
        os.chown(Path(current) / name, 65534, 65534)
environment = {'PATH': str(base / 'tools/go/bin') + ':/usr/bin:/bin', 'HOME': str(target / 'home'), 'GOROOT': str(base / 'tools/go'), 'GOMODCACHE': str(target / 'cache'), 'GOPATH': str(target / 'home/go'), 'GOCACHE': str(target / 'home/build'), 'GOPROXY': 'https://proxy.golang.org', 'GOSUMDB': 'sum.golang.org', 'GOTOOLCHAIN': 'local', 'GOENV': 'off', 'GOWORK': 'off', 'GOTELEMETRY': 'off', 'GOMAXPROCS': '1', 'LANG': 'C.UTF-8'}
results = []
commands = []
for args in (['mod', 'download', '-json', 'github.com/sagernet/gomobile@v0.1.11'], ['mod', 'download', '-json', 'all']):
    command = ['setpriv', '--reuid=65534', '--regid=65534', '--clear-groups', str(base / 'tools/go/bin/go'), *args]
    process = subprocess.run(command, cwd=target / 'source', env=environment, capture_output=True, text=True, timeout=240)
    text = process.stdout.strip()
    records = []
    decoder = json.JSONDecoder()
    while text:
        record, end = decoder.raw_decode(text)
        records.append(record)
        text = text[end:].lstrip()
    commands.append({'args': args, 'exit_code': process.returncode, 'stderr': process.stderr, 'records': records})
    (target / 'download-progress.json').write_text(json.dumps(commands, indent=2) + '\n')
    assert process.returncode == 0 and all('Error' not in x for x in records)
    results.extend(records)
expected = {'github.com/sagernet/gomobile': ('v0.1.11', 'h1:niMQAspvuThup5eRZQpsGcbM76zAvnsGr7RUIpnQMDQ='), 'golang.org/x/mod': ('v0.27.0', 'h1:kb+q2PyFnEADO2IEF935ehFUXlWiNjJWtRNgBLSfbxQ='), 'golang.org/x/sync': ('v0.16.0', 'h1:ycBJEhp9p4vXvUZNszeOq0kGTPghopOL8q0fq3vstxw='), 'golang.org/x/tools': ('v0.36.0', 'h1:kWS0uv/zsvHEle1LbV5LE8QujrxB3wfQyxHfhOk0Qkg=')}
for module, (version, checksum) in expected.items():
    rows = [x for x in results if x['Path'] == module and x['Version'] == version]
    assert rows and all(x['Sum'] == checksum for x in rows)
files = []
for path in sorted((target / 'cache/cache/download').rglob('*')):
    if path.is_file() and path.suffix in ('.info', '.mod', '.zip', '.ziphash'):
        raw = path.read_bytes()
        files.append({'path': path.relative_to(target / 'cache').as_posix(), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
receipt = {'status': 'PASS_AUTHENTICATED_TOOL_BUILD_INPUTS', 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'purpose': 'Offline rebuild of pinned gomobile and gobind; application dependency versions unchanged', 'go_toolchain': 'go1.26.8', 'gomobile_version': 'v0.1.11', 'source_go_mod_sha256': hashlib.sha256((source / 'go.mod').read_bytes()).hexdigest(), 'proxy': environment['GOPROXY'], 'sumdb': environment['GOSUMDB'], 'commands': commands, 'files': files, 'module_count': len({(x['Path'], x['Version']) for x in results}), 'bytes': sum(x['bytes'] for x in files)}
(target / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'status': receipt['status'], 'module_count': receipt['module_count'], 'files': len(files), 'bytes': receipt['bytes']}))
