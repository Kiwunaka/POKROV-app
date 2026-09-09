"""Read candidate.33 in place and bind retained CI files to its old provenance."""
import datetime
import hashlib
import json
import pathlib
import subprocess

output = pathlib.Path(__file__).parent
candidate = pathlib.Path('E:/POKROV-tools/release-candidates/pokrov-1.2.0-candidate.33')
platform = pathlib.Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start')
client = pathlib.Path('E:/r12client')
core = pathlib.Path('E:/r12core-implementation')
prefix = 'pokrov-1.2.0-candidate.33'
freeze_path = platform / 'docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/preservation.json'
freeze = json.loads(freeze_path.read_text(encoding='utf-8'))
seed = json.loads((client / 'config/cutover-readiness.seed.json').read_text(encoding='utf-8'))['exact_replacement_candidate']
provenance = json.loads((candidate / f'{prefix}.provenance.json').read_text(encoding='utf-8'))
signing = json.loads((candidate / 'candidate33-signing-evidence.json').read_text(encoding='utf-8'))
expected = {row['name']: row['expected_sha256'] for row in freeze['files']}
expected.update({f'{prefix}.cdx.json': seed['signed_contract']['sbom_sha256'],
                 f'{prefix}.provenance.json': seed['signed_contract']['provenance_sha256'],
                 f'{prefix}.supply-validation.json': seed['signed_contract']['supply_validation_sha256'],
                 f'{prefix}.handoff-input.json': seed['private_creation_manifest_sha256']})
for entry in provenance['predicate']['runDetails']['byproducts']:
    expected[entry['name']] = entry['digest']['sha256']

rows = []
for path in sorted(candidate.iterdir()):
    assert path.is_file(), 'Unexpected candidate directory'
    with path.open('rb') as stream:
        actual = hashlib.file_digest(stream, 'sha256').hexdigest()
    pinned = expected.get(path.name)
    rows.append({'name': path.name, 'bytes': path.stat().st_size, 'sha256': actual,
                 'expected_sha256': pinned,
                 'result': ('PINNED_BYTES_MATCH' if actual == pinned else 'MISMATCH')
                           if pinned else 'OBSERVED_AUXILIARY_FILE_NO_PRIOR_DIGEST'})
missing = sorted(set(expected) - {row['name'] for row in rows})
assert not missing, missing
assert not any(row['result'] == 'MISMATCH' for row in rows), 'Candidate bytes changed'

remote_matches = []
for remote_name, local_suffix in [('release-index.json', 'release-index.json'),
                                  ('release-index.json.sig', 'release-index.json.sig'),
                                  ('signing-receipt.json', 'signing-receipt.json')]:
    remote = output / '9928470408' / remote_name
    local = candidate / f'{prefix}.{local_suffix}'
    assert remote.read_bytes() == local.read_bytes(), remote_name
    remote_matches.append({'name': remote_name, 'result': 'REMOTE_LOCAL_BYTE_IDENTICAL'})

dependencies = []
for dep in provenance['predicate']['buildDefinition']['resolvedDependencies']:
    uri, digest = dep['uri'], dep['digest']
    if uri.startswith('ci:'):
        path = output / '9729751245' / uri.rsplit('/', 1)[1]
        data = path.read_bytes()
        binding = {'uri': uri, 'path': str(path), 'sha256': hashlib.sha256(data).hexdigest()}
        assert binding['sha256'] == digest['sha256'], uri
        binding['result'] = 'BOUND_CI_SOURCE_SBOM_MATCH'
        dependencies.append(binding)
    elif uri.startswith('file:'):
        relative = uri[5:]
        if relative.startswith('POKROV-core/'):
            repo, revision, relative = core, seed['sources']['core'], relative.removeprefix('POKROV-core/')
        else:
            repo, revision = client, seed['sources']['client']
        data = subprocess.check_output(['git', '-C', str(repo), 'show', revision + ':' + relative])
        actual = hashlib.sha256(data).hexdigest()
        # Preserve the distinction when original Windows checkout bytes used CRLF.
        crlf = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        result = 'EXACT_GIT_BLOB_MATCH' if actual == digest['sha256'] else (
            'GIT_BLOB_WITH_ORIGINAL_CRLF_MATCH' if hashlib.sha256(crlf).hexdigest() == digest['sha256'] else 'MISMATCH')
        dependencies.append({'uri': uri, 'revision': revision, 'expected_sha256': digest['sha256'],
                             'git_blob_sha256': actual, 'result': result})
        assert result != 'MISMATCH', uri

report = {'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'candidate_id': prefix, 'candidate_root': str(candidate),
          'source_revisions': seed['sources'], 'files': rows, 'missing_expected_files': missing,
          'signed_remote_matches': remote_matches, 'provenance_dependencies': dependencies,
          'binary_copies_created': 0, 'candidate_files_modified': 0,
          'scope': 'Retention and byte identity, not runtime, release approval or signing-key custody'}
(output / 'local-preservation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(f'PASS: {len(expected)} pinned files, {len(rows)} total files retained in place; '
      f'{len(remote_matches)} signed remote matches; {len(dependencies)} dependency bindings')
