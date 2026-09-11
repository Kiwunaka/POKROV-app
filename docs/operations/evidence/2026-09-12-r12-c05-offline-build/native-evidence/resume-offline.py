from pathlib import Path, PurePosixPath
import datetime, hashlib, json, os, shutil, subprocess, time, zipfile

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'offline-source-2662-20260912'
assert Path(__file__).resolve().parent == work
archive = work / 'source-review.zip'
expected_archive = '988573fde7433cc20c40f40a4696d0fa5b54aea1c936feec39cc7dab3715b25d'
revision = '2662f76a3303a0518bb07fbbdc449c066de2f95b'
result = {'status': 'RUNNING', 'stage': 'archive-verification', 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'core_source': revision, 'commands': [], 'resource_limit': {'cpu_quota_percent': 100, 'memory_max_bytes': 4 * 2**30, 'nice': 19}, 'network': 'Every tool compilation and library build runs in a fresh network namespace with only loopback, after dropping to uid/gid 65534.', 'candidate_created': False}

def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()

def save():
    temp = work / 'resume-progress.tmp'
    temp.write_text(json.dumps(result, indent=2) + '\n')
    temp.replace(work / 'resume-progress.json')

def run(label, args, directory, environment, timeout=3600):
    assert shutil.disk_usage(work).free > 30 * 2**30
    result['stage'] = label
    save()
    command = ['unshare', '--net', '--', 'sh', '-c', 'ip link set lo up; exec "$@"', 'fixture', 'setpriv', '--reuid=65534', '--regid=65534', '--clear-groups', *args]
    start = time.monotonic()
    # Only task-owned source/toolchain inputs and a sanitized environment reach these commands.
    with (work / (label + '.log')).open('wb') as log:
        process = subprocess.run(command, cwd=directory, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    row = {'stage': label, 'argv': args, 'cwd': str(directory), 'exit_code': process.returncode, 'elapsed_seconds': round(time.monotonic() - start, 3), 'log': label + '.log', 'log_sha256': sha(work / (label + '.log')), 'network_isolated': True, 'uid': 65534}
    result['commands'].append(row)
    save()
    assert process.returncode == 0, label + ' failed'

try:
    previous = json.loads((work / 'build-progress.json').read_text())
    assert previous['status'] == 'FAILED' and previous['stage'] == 'build_tool_gomobile'
    result = dict(previous)
    result.update(status='RUNNING', commands=[], stage='resume-pinned-tool-source', started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    result.pop('error', None)
    result.pop('error_class', None)
    result['previous_failed_receipt_sha256'] = sha(work / 'build-progress.json')
    env = previous['build_environment']
    payload = work / 'payload'
    cache = payload / 'go-module-cache'
    bin_dir = work / 'bin'
    actual_go = base / 'tools/go/bin/go'
    wrapper = bin_dir / 'go'
    toolchain = base / 'artifact-tools'
    compiler = toolchain / 'mingw/usr/bin/x86_64-w64-mingw32-gcc-posix'
    powershell = base / 'tools/powershell/pwsh'
    ndk = toolchain / 'ndk/android-ndk-r29'
    cronet = base / 'libcronet.dll'
    manifest = json.loads((payload / 'SOURCE-MANIFEST.json').read_text())
    module = cache / 'github.com/sagernet/gomobile@v0.1.11'
    assert module.is_dir()
    result['tool_source_origin'] = 'Authenticated pinned module github.com/sagernet/gomobile v0.1.11, installed from extracted source directory; local module build info reports devel.'
    source_root = payload / 'core'
    for name in ('gomobile', 'gobind'):
        run('resume_build_tool_' + name, [str(actual_go), 'install', './cmd/' + name], module, env, timeout=1800)
        info = subprocess.check_output([str(actual_go), 'version', '-m', str(bin_dir / name)], env=env, text=True)
        assert '\tmod\tgithub.com/sagernet/gomobile\t(devel)' in info
        result.setdefault('rebuilt_tools', []).append({'name': name, 'sha256': sha(bin_dir / name), 'build_info': info})
    for lane in ('windows', 'android'):
        args = [str(powershell), '-NoProfile', '-File', 'scripts/build-' + lane + '.ps1', '-GoExecutable', str(wrapper), '-OutputDirectory', str(work / 'out' / lane)]
        if lane == 'windows':
            args += ['-CCompiler', str(compiler), '-CronetLibrary', str(cronet)]
        else:
            args += ['-AndroidSdk', str(toolchain / 'sdk'), '-AndroidNdk', str(ndk), '-GomobileBinDirectory', str(bin_dir)]
        run('build_' + lane, args, source_root, env, timeout=5400)
    expected = {'windows/libcronet.dll': (8596992, '8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7'), 'windows/pokrov-core.dll': (55012864, 'e77cc0ab979becc635ec578b8b44248b1146dd96ba34cd4de72e62130089ce2c'), 'windows/pokrov-core.h': (4175, '8272978b8a28e6ae4c48c6c3ea230170e0d972ac3af6b54fb836fe1dd4c7331f'), 'android/pokrov-core-sources.jar': (55186, '183c6981053df278234fed9a7e9c93c9cb3859da6c1e0fe04415ff93c4361f65'), 'android/pokrov-core.aar': (106843791, 'feb452f5f06b865e3ae0655ef4168ffe065c08b759f64e9cfa084cde9d5a5941')}
    outputs = []
    for name, (size, checksum) in expected.items():
        path = work / 'out' / name
        actual = {'path': name, 'bytes': path.stat().st_size, 'sha256': sha(path)}
        actual['matches_current_package_library'] = actual['bytes'] == size and actual['sha256'] == checksum
        outputs.append(actual)
    result['outputs'] = outputs
    assert all(x['matches_current_package_library'] for x in outputs)
    checked = 0
    for row in manifest['files']:
        if row['path'].startswith('core/'):
            path = payload / row['path']
            assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256']
            checked += 1
    assert checked == 3172
    result['core_source_files_unchanged'] = checked
    result['status'] = 'PASS_OFFLINE_CORE_AND_TOOL_REBUILD'
except BaseException as error:
    result['status'] = 'FAILED'
    result['error_class'] = type(error).__name__
    result['error'] = str(error)
    raise
finally:
    result['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    result['free_bytes_after'] = shutil.disk_usage(work).free
    save()
