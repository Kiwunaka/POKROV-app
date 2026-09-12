from pathlib import Path
import datetime, hashlib, json, os, subprocess

out = Path(__file__).parent
client = Path('E:/r12client')
flutter = 'C:/Users/kiwun/tools/flutter/git-3.38.5/bin/flutter.bat'
env = os.environ.copy()
env['PATH'] = str(Path(flutter).parent) + ';' + env['PATH']
checks = [
    ('runtime-analyze', client / 'packages/runtime_engine', [flutter, 'analyze', '--no-pub']),
    ('runtime-tests', client / 'packages/runtime_engine', [flutter, 'test', '--no-pub', '--reporter', 'expanded']),
    ('android-analyze', client / 'apps/android_shell', [flutter, 'analyze', '--no-pub']),
    ('android-tests', client / 'apps/android_shell', [flutter, 'test', '--no-pub', '--reporter', 'expanded']),
    ('validate-seed', client, ['pwsh', '-NoProfile', '-File', 'scripts/validate-seed.ps1', '-PlatformRoot', 'C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start', '-CoreRoot', 'C:/r12corec02']),
    ('docs-contract', client, ['pwsh', '-NoProfile', '-File', 'test/docs-contract.ps1']),
    ('diff-check', client, ['git', 'diff', '--check']),
    ('release-artifacts-unchanged', client, ['git', 'diff', '--exit-code', '--', 'artifacts/releases']),
]
report = {'status': 'RUNNING', 'core_source': '6b271decead88b708e2fc03984b703b0a4e63ebd', 'checks': []}
for name, cwd, command in checks:
    print('RUN ' + name, flush=True)
    path = out / (name + '.log')
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    with path.open('wb') as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT)
    report['checks'].append({'name': name, 'cwd': str(cwd), 'command': command, 'started': started, 'exit_code': result.returncode, 'log': path.name, 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (out / 'consumer-checks.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
    print(('PASS ' if result.returncode == 0 else 'FAIL ') + name, flush=True)
    if result.returncode:
        report['status'] = 'FAIL'
        break
else:
    report['status'] = 'PASS'
(out / 'consumer-checks.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf8')
raise SystemExit(0 if report['status'] == 'PASS' else 1)
