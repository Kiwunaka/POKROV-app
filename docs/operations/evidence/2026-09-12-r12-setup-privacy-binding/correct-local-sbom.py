from pathlib import Path
import hashlib, json, os, subprocess

base = Path('/tmp/pokrov-r12-core-validation-1c8b33f6a771409a')
work = base / 'setup-privacy-final-6b271de-20260912'
assert Path(__file__).resolve().parent == work
progress = json.loads((work / 'progress.json').read_text())
assert progress['status'] == 'PASS_TWO_BUILDS_PER_PLATFORM'
source = work / 'source'
revision = progress['source_commit']
local = {x['Path']: x for x in json.loads((work / 'local-modules.json').read_text())}
assert len(local) == 7
local['github.com/Kiwunaka/POKROV-core'] = {'Path': 'github.com/Kiwunaka/POKROV-core', 'Main': True, 'Replace': {'Dir': str(source)}}
dest = work / 'sbom/corrected'; dest.mkdir(); os.chown(dest, 65534, 65534)
report = {'status': 'RUNNING', 'source_commit': revision, 'reason': 'Raw generator assigns local fork commits to upstream module PURLs/VCS references. Corrected components identify retained POKROV source and preserve declared Go require versions separately.', 'files': []}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
for raw in sorted((work / 'sbom').glob('*.cdx.json')):
    data = json.loads(raw.read_text())
    components = [data['metadata']['component'], *data['components']]
    before_dependencies = data.get('dependencies', [])
    mapping = {}; changes = []
    for component in components:
        name = component.get('name')
        if name not in local:
            continue
        module = local[name]
        directory = Path(module['Replace']['Dir'])
        relative = directory.relative_to(source).as_posix()
        old_ref = component['bom-ref']; new_ref = 'urn:pokrov:go-module:' + name + ':' + revision
        mapping[old_ref] = new_ref
        old = {'bom-ref': old_ref, 'version': component.get('version'), 'purl': component.get('purl'), 'externalReferences': component.get('externalReferences', [])}
        component['bom-ref'] = new_ref
        component['version'] = revision
        component.pop('purl', None)
        component['externalReferences'] = [x for x in component.get('externalReferences', []) if x['type'] != 'vcs'] + [{'type': 'vcs', 'url': 'https://github.com/Kiwunaka/POKROV-core', 'comment': 'POKROV local source revision and repository-relative directory are recorded in properties; publication is a separate gate.'}]
        properties = component.setdefault('properties', [])
        properties.extend([{'name': 'pokrov:source:commit', 'value': revision}, {'name': 'pokrov:source:path', 'value': relative}, {'name': 'pokrov:source:kind', 'value': 'owned-core-module' if module.get('Main') else 'local-replacement'}])
        if module.get('Version'):
            properties.append({'name': 'pokrov:go:declared-require-version', 'value': module['Version']})
        license = directory / 'LICENSE'
        if license.is_file():
            properties.append({'name': 'pokrov:license:root-file-sha256', 'value': sha(license)})
        if name == 'github.com/sagernet/sing-tun':
            properties.append({'name': 'pokrov:source:verified-upstream-base', 'value': '635920688d0a7aa2171afa56be2a0760a69fecb9'})
        changes.append({'module': name, 'source_path': relative, 'previous': old, 'new_ref': new_ref})
    def refs(value):
        if isinstance(value, dict):
            return {k: refs(v) for k, v in value.items()}
        if isinstance(value, list):
            return [refs(v) for v in value]
        if isinstance(value, str):
            return mapping.get(value, value)
        return value
    data['dependencies'] = refs(before_dependencies)
    assert len(data['dependencies']) == len(before_dependencies)
    all_refs = {c['bom-ref'] for c in components}
    assert len(all_refs) == len(components)
    for row in data['dependencies']:
        assert row['ref'] in all_refs
        assert set(row.get('dependsOn', [])) <= all_refs
    output = dest / raw.name
    output.write_text(json.dumps(data, indent=2) + '\n')
    report['files'].append({'name': raw.name, 'raw_sha256': sha(raw), 'corrected_sha256': sha(output), 'corrected_components': changes, 'components': len(components), 'dependency_records_preserved': len(before_dependencies)})
report['status'] = 'PASS_LOCAL_SOURCE_IDENTITY_CORRECTION'
(work / 'sbom-local-source-correction.json').write_text(json.dumps(report, indent=2) + '\n')
env = {'PATH': str(base / 'tools/go/bin') + ':/usr/bin:/bin', 'GOTOOLCHAIN': 'local', 'GOWORK': 'off', 'GOMODCACHE': str(base / 'cache/mod'), 'GOCACHE': str(base / 'cache/build'), 'GOPROXY': 'off', 'GOENV': 'off', 'DOTNET_CLI_TELEMETRY_OPTOUT': '1', 'DOTNET_CLI_HOME': str(work / 'dotnet'), 'XDG_CACHE_HOME': str(work / 'xdg')}
q = lambda value: "'" + str(value).replace("'", "''") + "'"
for lane in ['windows', 'android']:
    command = '& ' + q(source / 'scripts/new-release-artifact-evidence.ps1') + ' -Lane ' + q(lane) + ' -FirstBuildRoot ' + q(work / 'out' / (lane+'-a')) + ' -SecondBuildRoot ' + q(work / 'out' / (lane+'-b')) + ' -Output ' + q(work / (lane+'-evidence-corrected.json')) + ' -Sbom ' + ','.join(q(dest / x) for x in ['core-source.cdx.json', 'engine-source.cdx.json']) + ' -RequireCleanSource'
    p = subprocess.run(['setpriv', '--reuid=65534', '--regid=65534', '--clear-groups', str(base / 'tools/powershell/pwsh'), '-NoProfile', '-Command', command], cwd=source, env=env, capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
print(json.dumps({'status': report['status'], 'corrected_components': {x['name']: len(x['corrected_components']) for x in report['files']}, 'binaries_rebuilt': False, 'raw_sboms_and_receipts_retained': True}))
