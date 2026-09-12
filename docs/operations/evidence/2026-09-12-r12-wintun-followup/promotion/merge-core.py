from pathlib import Path
import json, subprocess

out = Path(__file__).parent
root = Path('C:/r12corec02')
repo = 'Kiwunaka/pokrov-core'
source = json.loads((out / 'core-source-promoted.json').read_bytes())
ci = json.loads((out / 'core-ci-pr.json').read_bytes())
assert ci['status'] == 'PASS' and ci['source'] == source['signed_commit']
assert not (out / 'core-merge-binding.json').exists()

def gh(*args):
    return json.loads(subprocess.check_output(['gh', *args], cwd=root))

pr = gh('pr', 'view', '14', '--repo', repo, '--json', 'headRefOid,baseRefName,state,isDraft')
assert pr['headRefOid'] == source['signed_commit'] and pr['baseRefName'] == 'main' and pr['state'] == 'OPEN'
assert gh('api', f'repos/{repo}/branches/main')['commit']['sha'] == source['parent']
if pr['isDraft']:
    subprocess.run(['gh', 'pr', 'ready', '14', '--repo', repo], cwd=root, check=True)
subprocess.run(['gh', 'pr', 'merge', '14', '--repo', repo, '--squash', '--match-head-commit', source['signed_commit']], cwd=root, check=True)
pr = gh('pr', 'view', '14', '--repo', repo, '--json', 'state,mergedAt,mergeCommit,headRefOid,url')
assert pr['state'] == 'MERGED' and pr['headRefOid'] == source['signed_commit']
merge = pr['mergeCommit']['oid']
subprocess.run(['git', 'fetch', 'origin', 'main'], cwd=root, check=True)
tree = subprocess.check_output(['git', 'rev-parse', merge + '^{tree}'], cwd=root, text=True).strip()
assert tree == source['tree']
commit = gh('api', f'repos/{repo}/commits/{merge}')
assert commit['commit']['verification']['verified']
receipt = {'status': 'PASS', 'merge': merge, 'source': source['signed_commit'],
           'tree': tree, 'same_tree': True, 'merge_signature_verified': True,
           'merged_at': pr['mergedAt'], 'pr': pr['url']}
(out / 'core-merge-binding.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
print(json.dumps(receipt))
