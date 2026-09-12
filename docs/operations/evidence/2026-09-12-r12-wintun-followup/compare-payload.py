from pathlib import Path
import datetime, hashlib, json

base = Path('C:/r12-c05-wintun-20260912')
prior = Path('C:/r12-c05-wintun-20260912/windows-package-audit.json')
expected = json.loads(prior.read_bytes())
actual = json.loads((base / 'payload-inventory.json').read_bytes())
prefix = 'app/'
rows = {r['path'].removeprefix(prefix): r for r in actual}
assert len(rows) == len(actual), 'Duplicate extracted paths'
assert all(r['path'].startswith(prefix) for r in actual), 'Unexpected extraction path outside app'
expected_rows = {r['relative_path']: r for r in expected['bundle_inventory']}
missing = sorted(set(expected_rows) - set(rows))
extra = sorted(set(rows) - set(expected_rows))
mismatch = [p for p in sorted(set(rows) & set(expected_rows)) if rows[p]['sha256'] != expected_rows[p]['sha256'] or rows[p]['size'] != expected_rows[p]['size']]
result = {'schema': 'pokrov.r12.extracted-installer-identity/v1',
          'observed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'installer': expected['installer'],
          'prior_staged_inventory': {'path': str(prior), 'sha256': hashlib.sha256(prior.read_bytes()).hexdigest()},
          'extracted_inventory': {'path': str(base / 'payload-inventory.json'), 'sha256': hashlib.sha256((base / 'payload-inventory.json').read_bytes()).hexdigest()},
          'expected_files': len(expected_rows), 'extracted_files': len(rows), 'missing': missing, 'extra': extra, 'mismatch': mismatch,
          'status': 'PASS_EXACT_PAYLOAD' if not (missing or extra or mismatch) else 'FAIL',
          'scope': 'Installer archive payload compared to all staged bundle bytes; installer not executed, uninstaller generated during installation and SCM/TUN actions not tested.'}
(base / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n')
assert not (missing or extra or mismatch), 'Installer payload differs; inspect comparison.json'
print('PASS', len(rows), 'exact files; no missing, extra or mismatched payload entries')
