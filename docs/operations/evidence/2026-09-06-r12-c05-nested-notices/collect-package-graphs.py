from pathlib import Path
import concurrent.futures
import hashlib
import json
import os
import subprocess

ROOT = Path('E:/r12core-implementation')
OUT = Path('E:/r12-c05-utls-review')
GO = 'C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64/bin/go.exe'
INFO = Path('E:/r12-c05-artifacts')
FIELDS = 'ImportPath,Dir,Module,Standard,GoFiles,CgoFiles,SFiles,CFiles,CXXFiles,HFiles,SysoFiles,EmbedFiles,Error,DepsErrors'

def parse_stream(raw):
    decoder = json.JSONDecoder()
    position = 0
    rows = []
    while position < len(raw):
        while position < len(raw) and raw[position].isspace():
            position += 1
        if position == len(raw):
            break
        row, position = decoder.raw_decode(raw, position)
        rows.append(row)
    return rows

def collect(info):
    name = info.name.removeprefix('final-').removesuffix('.buildinfo.log')
    settings = {}
    for line in info.read_text().splitlines():
        fields = line.strip().split('\t')
        if fields[0] == 'build' and '=' in fields[1]:
            key, value = fields[1].split('=', 1)
            settings[key] = value
    assert settings['GOOS'] in ['windows', 'android']
    env = os.environ.copy()
    overrides = {k: settings[k] for k in ['GOOS', 'GOARCH', 'CGO_ENABLED', 'GOARM'] if k in settings}
    overrides.update({'GOTOOLCHAIN': 'local', 'GOFLAGS': '-buildvcs=false -mod=readonly'})
    env.update(overrides)
    roots = ['./platform/desktop'] if settings['GOOS'] == 'windows' else ['github.com/sagernet/sing-box/experimental/libbox', './platform/mobile']
    command = [GO, 'list', '-deps', '-json=' + FIELDS, '-tags=' + settings['-tags'], *roots]
    run = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, timeout=180)
    (OUT / (name + '.stderr.log')).write_text(run.stderr)
    rows = parse_stream(run.stdout)
    errors = [r for r in rows if r.get('Error') or r.get('DepsErrors')]
    result = {'name': name, 'command': command, 'cwd': str(ROOT), 'environment': overrides, 'build_info': str(info), 'build_info_sha256': hashlib.sha256(info.read_bytes()).hexdigest(), 'exit_code': run.returncode, 'package_count': len(rows), 'errors': errors, 'packages': rows}
    (OUT / (name + '.packages.json')).write_text(json.dumps(result, indent=2) + '\n')
    assert run.returncode == 0 and not errors, (name, run.returncode, run.stderr[:300], len(errors))
    return {'name': name, 'packages': len(rows), 'exit_code': run.returncode}

assert subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip() == '8dc57a830bd1487389dd1b7c9190f094c31e13bc'
inputs = sorted(INFO.glob('final-*.buildinfo.log'))
assert len(inputs) == 5
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results = list(pool.map(collect, inputs))
(OUT / 'package-graphs-summary.json').write_text(json.dumps(results, indent=2) + '\n')
print(json.dumps(results))
