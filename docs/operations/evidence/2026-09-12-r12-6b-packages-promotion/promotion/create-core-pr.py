from pathlib import Path
import json, subprocess

out = Path(__file__).parent
repo = 'Kiwunaka/pokrov-core'
source = json.loads((out / 'core-source-promoted.json').read_bytes())
client = json.loads((out / 'client-merge-binding.json').read_bytes())
def gh(*args):
    return json.loads(subprocess.check_output(['gh', *args]))
assert client['status'] == 'PASS' and client['same_tree']
assert gh('api', 'repos/Kiwunaka/POKROV-app/branches/main')['commit']['sha'] == client['merge']
assert gh('api', 'repos/' + repo + '/branches/main')['commit']['sha'] == source['parent']
assert gh('api', 'repos/' + repo + '/git/ref/heads/' + source['branch'])['object']['sha'] == source['signed_commit']
assert gh('api', 'repos/' + repo + '/branches/main/protection') == json.loads((out / 'core-protection-before.json').read_bytes())
body = '''Core setup wrote caller directories and a listen address to diagnostics even with debug disabled. Replace those two messages with fixed setup status and the selected mode, covering stderr and the legacy log observer.

Validation: the new regression reproduces the leak on old source; both focused privacy tests and the full native Core script pass after the fix. Two native builds per platform are byte-identical, and exact new DLL checks pass 100 proxy cycles plus synthetic privacy markers in FFI/stdout/stderr and five generated files. Dependencies, native ABI and embedded Wintun are unchanged. Android/Windows binding is already on client main through PR120; source 6b271de and this signed promotion have identical trees. Installed TUN/privacy, full licensing/source delivery and public release remain separate gates.
'''
path = out / 'core-pr-body.md'
path.write_text(body, encoding='utf8')
url = subprocess.check_output(['gh', 'pr', 'create', '--repo', repo, '--base', 'main', '--head', source['branch'], '--draft', '--title', 'Omit caller paths and listen addresses from Core setup diagnostics', '--body-file', str(path)], text=True).strip()
source['pr'] = url
(out / 'core-source-promoted.json').write_text(json.dumps(source, indent=2) + '\n', encoding='utf8')
print(json.dumps({'pr': url, 'source': source['signed_commit'], 'tree': source['tree']}))
