from pathlib import Path
import datetime, hashlib, json, os, shutil, subprocess, time

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'probe-stage-final-0138d04-20260913'
assert Path(__file__).resolve().parent == work
old = base / 'offline-source-2662-20260912'
manifest = json.loads((work / 'final-source.json').read_text())
revision = '0138d04e5601a3ab1089cbbe5a73fe8e0aee4126'
assert manifest['source_commit'] == revision
assert json.loads((base / 'setup-privacy-final-6b271de-20260912/progress.json').read_text())['status'] == 'PASS_TWO_BUILDS_PER_PLATFORM'
assert shutil.disk_usage(base).free > 30 * 2**30
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
prefix = ['setpriv', '--reuid=65534', '--regid=65534', '--clear-groups']
os.chown(work, 65534, 65534)
source = work / 'source'
subprocess.run([*prefix, 'git', 'clone', '--quiet', '--no-checkout', '--no-hardlinks', str(base / 'lifecycle-fix/source'), str(source)], check=True)
git = [*prefix, 'git', '-C', str(source)]
subprocess.run([*git, 'config', 'core.autocrlf', 'false'], check=True)
subprocess.run([*git, 'fetch', '--quiet', str(work / 'final-source.bundle'), 'HEAD'], check=True)
subprocess.run([*git, 'checkout', '--quiet', '--detach', revision], check=True)
def check_source():
    assert subprocess.check_output([*git, 'status', '--porcelain']) == b''
    assert subprocess.check_output([*git, 'rev-parse', 'HEAD^{tree}'], text=True).strip() == manifest['source_tree']
    names = subprocess.check_output([*git, 'ls-files', '-z']).decode().rstrip('\0').split('\0')
    assert set(names) == {r['path'] for r in manifest['files']}
    for row in manifest['files']:
        raw = (source / row['path']).read_bytes()
        # The checked-out PS1 files follow their declared CRLF attributes.
        if hashlib.sha256(raw).hexdigest() != row['sha256']:
            assert row['path'].endswith('.ps1') and hashlib.sha256(raw.replace(b'\r\n', b'\n')).hexdigest() == row['sha256']
check_source()
for name in ['bin', 'out', 'home', 'tmp', 'sbom', 'xdg', 'dotnet']:
    (work / name).mkdir(); os.chown(work / name, 65534, 65534)
previous = json.loads((old / 'resume-progress.json').read_text())
for row in previous['rebuilt_tools']:
    assert sha(old / 'bin' / row['name']) == row['sha256']
    shutil.copy2(old / 'bin' / row['name'], work / 'bin' / row['name'])
wrapper = work / 'bin/go'
wrapper.write_text((old / 'bin/go').read_text().replace(str(old / 'tmp/android-build.lock'), str(work / 'tmp/android-build.lock')))
wrapper.chmod(0o755)
env = previous['build_environment'].copy()
for key in ['HOME', 'GOTMPDIR', 'TMPDIR', 'GOBIN', 'XDG_CACHE_HOME', 'DOTNET_CLI_HOME']:
    env[key] = env[key].replace(str(old), str(work))
env['PATH'] = env['PATH'].replace(str(old / 'bin'), str(work / 'bin'))
env['GOMODCACHE'] = str(base / 'cache/mod')
result = {'status': 'RUNNING', 'stage': 'verified_source', 'source_commit': revision, 'source_tree': manifest['source_tree'], 'source_files': len(manifest['files']), 'source_manifest_sha256': sha(work / 'final-source.json'), 'commands': [], 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'new_release_candidate': False, 'source_delta': 'Retain typed TLS/response stage at URL probe deadline; existing two daemon timeout boundaries consume the bounded URLTest result. One failing endpoint regression and affected package pass retained locally. No dependency or build-script changes.'}
def save():
    p = work / 'progress.tmp'; p.write_text(json.dumps(result, indent=2) + '\n'); p.replace(work / 'progress.json')
def run(label, args, environment=env, isolated=True):
    assert shutil.disk_usage(work).free > 30 * 2**30
    result['stage'] = label; save(); start = time.monotonic()
    command = [*prefix, *args]
    if isolated:
        command = ['unshare', '--net', '--', 'sh', '-c', 'ip link set lo up; exec "$@"', 'fixture', *command]
    with (work / (label + '.log')).open('wb') as log:
        p = subprocess.run(command, cwd=source, env=environment, stdout=log, stderr=subprocess.STDOUT, timeout=5400)
    result['commands'].append({'stage': label, 'argv': args, 'exit_code': p.returncode, 'elapsed_seconds': round(time.monotonic()-start, 3), 'log_sha256': sha(work / (label+'.log')), 'network_isolated': isolated}); save()
    assert p.returncode == 0, label
try:
    save()
    run('required_core_gate', [str(base / 'tools/powershell/pwsh'), '-NoProfile', '-File', 'scripts/test.ps1', '-GoExecutable', str(base / 'tools/go/bin/go')])
    sboms = []
    for label, directory in [('core-source', source), ('engine-source', source / 'engine/sing-box')]:
        output = work / 'sbom' / (label + '.cdx.json'); sboms.append(output)
        sbom_env = env.copy(); sbom_env.update(GOPROXY='https://proxy.golang.org', GOSUMDB='sum.golang.org')
        run('sbom_' + label, [str(base / 'artifact-build/bin/cyclonedx-gomod'), 'mod', '-licenses', '-std', '-json', '-notimestamp', '-noserial', '-output', str(output), str(directory)], sbom_env, isolated=False)
    pwsh = str(base / 'tools/powershell/pwsh')
    for lane in ['windows', 'android']:
        for attempt in ['a', 'b']:
            args = [pwsh, '-NoProfile', '-File', 'scripts/build-' + lane + '.ps1', '-GoExecutable', str(wrapper), '-OutputDirectory', str(work / 'out' / (lane+'-'+attempt))]
            if lane == 'windows':
                args += ['-CCompiler', str(base / 'artifact-tools/mingw/usr/bin/x86_64-w64-mingw32-gcc-posix'), '-CronetLibrary', str(base / 'libcronet.dll')]
            else:
                args += ['-AndroidSdk', str(base / 'artifact-tools/sdk'), '-AndroidNdk', str(base / 'artifact-tools/ndk/android-ndk-r29'), '-GomobileBinDirectory', str(work / 'bin')]
            run('build_'+lane+'_'+attempt, args)
        a, b = work / 'out' / (lane+'-a'), work / 'out' / (lane+'-b')
        first = {p.name: sha(p) for p in a.iterdir() if p.is_file()}
        assert first == {p.name: sha(p) for p in b.iterdir() if p.is_file()}, lane
        q = lambda x: "'" + str(x).replace("'", "''") + "'"
        command = '& ' + q(source / 'scripts/new-release-artifact-evidence.ps1') + ' -Lane ' + q(lane) + ' -FirstBuildRoot ' + q(a) + ' -SecondBuildRoot ' + q(b) + ' -Output ' + q(work / (lane+'-evidence.json')) + ' -Sbom ' + ','.join(q(x) for x in sboms) + ' -RequireCleanSource'
        run('evidence_'+lane, [pwsh, '-NoProfile', '-Command', command])
    check_source()
    result['outputs'] = [{'path': p.relative_to(work / 'out').as_posix(), 'bytes': p.stat().st_size, 'sha256': sha(p)} for p in sorted((work / 'out').rglob('*')) if p.is_file()]
    result['sboms'] = [{'path': p.relative_to(work).as_posix(), 'sha256': sha(p)} for p in sboms]
    result['status'] = 'PASS_TWO_BUILDS_PER_PLATFORM'
except BaseException as error:
    result['status'] = 'FAILED'; result['error_class'] = type(error).__name__
    raise
finally:
    result['finished_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat(); save()
