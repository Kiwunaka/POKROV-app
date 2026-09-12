from pathlib import Path
import hashlib, json, subprocess

out = Path(__file__).parent
uploaded = json.loads((out / 'old-aar-cache-upload.json').read_text(encoding='utf8'))
original = (out / 'retain-old-aar-cache.py').read_text(encoding='utf8')
code = original.split("verify = '''", 1)[1].split("'''.replace", 1)[0]
# Replace only the two literal input values; preserve the status label.
code = code.replace("Path('ARCHIVE')", "Path('" + uploaded['archive'] + "')").replace("'DIGEST'", "'" + uploaded['archive_sha256'] + "'")
result = subprocess.run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', 'pokrov-de', 'python3 -'], input=code, text=True, capture_output=True, check=True, timeout=180)
receipt = json.loads(result.stdout)
assert receipt['status'] == 'PASS_EXACT_RETIRED_AAR_CACHE_ARCHIVE'
assert receipt['archive_sha256'] == uploaded['archive_sha256'] and receipt['files'] == uploaded['files']
(out / 'old-aar-cache-retention.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
(out / 'old-aar-cache-verifier-correction.json').write_text(json.dumps({'initial_outcome': 'Local status assertion failed after remote verification', 'reason': 'Global ARCHIVE replacement also changed the result status string', 'correction': 'Replace only quoted path and digest literals; repeat full archive and member hashing', 'initial_script_sha256': hashlib.sha256((out / 'retain-old-aar-cache.py').read_bytes()).hexdigest(), 'archive_uploaded_again': False, 'files_removed_before_corrected_verification': 0, 'status': 'PASS_CORRECTED_VERIFICATION'}, indent=2) + '\n', encoding='utf8')
print(json.dumps(receipt))
