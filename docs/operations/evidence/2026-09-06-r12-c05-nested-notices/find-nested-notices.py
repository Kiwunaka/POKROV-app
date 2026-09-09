from pathlib import Path
import hashlib
import json
import re

OUT = Path('E:/r12-c05-utls-review')
CORE = Path('E:/r12core-implementation').resolve()
GOROOT = Path('C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64').resolve()
OLD = json.loads(Path('E:/r12-c05-go-notices/assembly.json').read_text())
MODULES = json.loads(Path('E:/r12-c05-package-artifacts/linked-module-notices.json').read_text())['modules']
identity_by_dir = {str(Path(m['source_dir']).resolve()).lower(): m for m in MODULES}
old_refs = {f['source_ref'] for f in OLD['verbatim_files']}
pattern = re.compile(r'^(LICENSE|LICENCE|NOTICE|COPYING|COPYRIGHT|PATENTS)(?:$|[._ -])', re.I)
notices = {}
excluded_source_files = {}
unknown = {}
used_modules = set()

for graph in sorted(OUT.glob('*.packages.json')):
    doc = json.loads(graph.read_text())
    assert doc['exit_code'] == 0 and not doc['errors']
    for package in doc['packages']:
        if package['ImportPath'] in ['unsafe', 'builtin'] or not package.get('Dir'):
            continue
        directory = Path(package['Dir']).resolve()
        module = package.get('Module')
        if package.get('Standard'):
            boundary = GOROOT
            source = 'go1.26.8'
        elif module and module.get('Main'):
            boundary = CORE
            source = 'core@' + OLD['source_commit']
        elif module:
            actual = module.get('Replace') or module
            boundary = Path(actual['Dir']).resolve()
            entry = identity_by_dir.get(str(boundary).lower())
            if not entry:
                unknown[package['ImportPath']] = module
                continue
            used_modules.add(entry['identity']['module'])
            expected = entry['identity']['replacement'] or entry['identity']
            if boundary.is_relative_to(CORE):
                source = 'core@' + OLD['source_commit'] + '/' + boundary.relative_to(CORE).as_posix()
            else:
                assert actual['Path'] == expected['module'] and actual['Version'] == expected['version']
                source = actual['Path'] + '@' + actual['Version']
        else:
            unknown[package['ImportPath']] = {'directory': str(directory)}
            continue
        assert directory.is_relative_to(boundary), directory
        # Include ancestors of Go package dirs and explicitly embedded files.
        starts = {directory}
        for name in package.get('EmbedFiles', []):
            embedded = (directory / name).resolve()
            assert embedded.is_relative_to(boundary)
            starts.add(embedded.parent)
        for start in starts:
            current = start
            while True:
                for path in current.iterdir():
                    if path.is_file() and pattern.match(path.name):
                        reference = source + '/' + path.relative_to(boundary).as_posix()
                        if path.suffix.lower() in ['.go', '.py', '.c', '.h', '.cc', '.cpp', '.js']:
                            excluded_source_files[reference] = 'source code filename matched license-like prefix'
                            continue
                        if reference not in old_refs:
                            content = path.read_bytes()
                            entry = notices.setdefault(reference, {'source_ref': reference, 'path': str(path), 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest(), 'package_imports': [], 'targets': []})
                            if package['ImportPath'] not in entry['package_imports']:
                                entry['package_imports'].append(package['ImportPath'])
                            if doc['name'] not in entry['targets']:
                                entry['targets'].append(doc['name'])
                if current == boundary:
                    break
                current = current.parent

result = {'selection': 'New license-like files in ancestors of selected package directories and embedded files under exact module/Core/Go boundaries; native includes and file-header obligations are separate', 'new_notices': sorted(notices.values(), key=lambda n: n['source_ref']), 'excluded_source_files': excluded_source_files, 'unknown_packages': unknown, 'used_buildinfo_modules': sorted(used_modules), 'buildinfo_modules_not_found_in_source_graph': sorted(set(m['identity']['module'] for m in MODULES) - used_modules)}
(OUT / 'nested-notices.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'new_notices': len(notices), 'new_bytes': sum(r['bytes'] for r in notices.values()), 'unknown_packages': list(unknown), 'modules_not_in_graph': result['buildinfo_modules_not_found_in_source_graph']}))
for entry in result['new_notices']:
    print(entry['source_ref'], entry['bytes'])
