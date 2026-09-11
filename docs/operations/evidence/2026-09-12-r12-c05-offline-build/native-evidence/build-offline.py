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
    temp = work / 'build-progress.tmp'
    temp.write_text(json.dumps(result, indent=2) + '\n')
    temp.replace(work / 'build-progress.json')

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
    save()
    assert archive.stat().st_size == 351472957 and sha(archive) == expected_archive
    assert shutil.disk_usage(work).free > 40 * 2**30
    payload = work / 'payload'
    payload.mkdir(mode=0o755)
    with zipfile.ZipFile(archive) as z:
        assert len(z.namelist()) == len(set(z.namelist())) == 3693
        manifest = json.loads(z.read('SOURCE-MANIFEST.json'))
        assert manifest['core_commit'] == revision and len(manifest['files']) == 3692
        rows = {x['path']: x for x in manifest['files']}
        for info in z.infolist():
            name = PurePosixPath(info.filename)
            assert not name.is_absolute() and '..' not in name.parts and '\\' not in info.filename
            raw = z.read(info.filename)
            if info.filename != 'SOURCE-MANIFEST.json':
                row = rows[info.filename]
                assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256']
            path = payload.joinpath(*name.parts)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
            path.chmod(0o755 if ((info.external_attr >> 16) & 0o111) else 0o644)
    result['archive'] = {'sha256': expected_archive, 'bytes': archive.stat().st_size, 'verified_entries': 3693}
    inputs = json.loads((work / 'tool-inputs/receipt.json').read_text())
    assert inputs['status'] == 'PASS_AUTHENTICATED_TOOL_BUILD_INPUTS'
    cache = payload / 'go-module-cache'
    added = []
    duplicates = []
    for row in inputs['files']:
        source = work / 'tool-inputs/cache' / row['path']
        assert source.stat().st_size == row['bytes'] and sha(source) == row['sha256']
        target = cache / row['path']
        if target.exists():
            assert sha(target) == row['sha256'], row['path']
            duplicates.append(row['path'])
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            added.append(row)
    result['tool_input_supplement'] = {'receipt_sha256': sha(work / 'tool-inputs/receipt.json'), 'new_cache_files': added, 'exact_duplicate_paths': duplicates, 'application_modules_changed': False}
    for name in ('bin', 'build-cache', 'gopath', 'home', 'tmp', 'out', 'xdg', 'dotnet'):
        (work / name).mkdir(mode=0o755)
    assert not any((work / 'build-cache').iterdir())
    result['initial_compiled_go_cache_empty'] = True
    actual_go = base / 'tools/go/bin/go'
    bin_dir = work / 'bin'
    wrapper = bin_dir / 'go'
    wrapper.write_text('#!/bin/sh\nset -eu\nif [ "${1-}" = build ] && [ "${GOOS-}" = android ]; then\n  exec /usr/bin/flock -x ' + str(work / 'tmp/android-build.lock') + ' ' + str(actual_go) + ' "$@"\nfi\nexec ' + str(actual_go) + ' "$@"\n')
    wrapper.chmod(0o755)
    result['android_serial_wrapper_sha256'] = sha(wrapper)
    toolchain = base / 'artifact-tools'
    jdk = list((toolchain / 'java').glob('*/bin/javac'))
    assert len(jdk) == 1
    java = jdk[0].parent.parent
    compiler = toolchain / 'mingw/usr/bin/x86_64-w64-mingw32-gcc-posix'
    ndk = toolchain / 'ndk/android-ndk-r29'
    powershell = base / 'tools/powershell/pwsh'
    cronet = base / 'libcronet.dll'
    assert sha(cronet) == '8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7'
    result['external_prerequisites'] = [{'name': name, 'path': str(path), 'sha256': sha(path)} for name, path in [('go', actual_go), ('pwsh', powershell), ('mingw_gcc', compiler), ('ndk_clang', ndk / 'toolchains/llvm/prebuilt/linux-x86_64/bin/clang'), ('ndk_source_properties', ndk / 'source.properties'), ('javac', jdk[0]), ('android_jar', toolchain / 'sdk/platforms/android-36/android.jar'), ('prebuilt_libcronet', cronet)]]
    result['prerequisite_boundary'] = 'Previously authenticated Go, PowerShell, JDK, NDK, SDK and MinGW installations are reused. Pinned Windows libcronet is a supplied prebuilt input. This does not rebuild Cronet, compilers, SDKs, or PGO profiles from source.'
    for current, dirs, files in os.walk(work):
        # This exact task workspace was created separately; no neighboring work is changed.
        os.chown(current, 65534, 65534)
        for name in files:
            os.chown(Path(current) / name, 65534, 65534, follow_symlinks=False)
    env = {'PATH': str(bin_dir) + ':' + str(java / 'bin') + ':' + str(base / 'tools/go/bin') + ':' + str(base / 'tools/ripgrep-14.1.1-x86_64-unknown-linux-musl') + ':/usr/bin:/bin', 'HOME': str(work / 'home'), 'JAVA_HOME': str(java), 'GOROOT': str(base / 'tools/go'), 'GOPATH': str(work / 'gopath'), 'GOMODCACHE': str(cache), 'GOCACHE': str(work / 'build-cache'), 'GOTMPDIR': str(work / 'tmp'), 'TMPDIR': str(work / 'tmp'), 'GOBIN': str(bin_dir), 'XDG_CACHE_HOME': str(work / 'xdg'), 'DOTNET_CLI_HOME': str(work / 'dotnet'), 'DOTNET_CLI_TELEMETRY_OPTOUT': '1', 'GOTELEMETRY': 'off', 'GOENV': 'off', 'GOTOOLCHAIN': 'local', 'GOWORK': 'off', 'GOFLAGS': '-buildvcs=false -mod=readonly -p=1', 'GOMAXPROCS': '1', 'CGO_ENABLED': '1', 'GOPROXY': 'off', 'GOSUMDB': 'off', 'LANG': 'C.UTF-8', 'COMPILER_PATH': str(compiler.parent)}
    result['build_environment'] = env
    source_root = payload / 'core'
    for name in ('gomobile', 'gobind'):
        run('build_tool_' + name, [str(actual_go), 'install', 'github.com/sagernet/gomobile/cmd/' + name + '@v0.1.11'], work, env, timeout=1800)
        info = subprocess.check_output([str(actual_go), 'version', '-m', str(bin_dir / name)], env=env, text=True)
        assert '\tmod\tgithub.com/sagernet/gomobile\tv0.1.11\t' in info
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
