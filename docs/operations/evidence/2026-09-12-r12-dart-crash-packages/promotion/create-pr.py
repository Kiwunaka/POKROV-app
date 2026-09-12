from pathlib import Path
import base64, datetime, hashlib, json, subprocess

out = Path(__file__).parent
def gh(*args):
    return json.loads(subprocess.check_output(['gh', *args]))
def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])
def signed(label, repo, root, candidate, branch, title):
    assert gh('api', 'repos/' + repo + '/branches/main')['commit']['sha'] == candidate['parent']
    assert gh('api', 'repos/' + repo + '/branches/main/protection') == json.loads((out / (label + '-protection-before.json')).read_bytes())
    assert not git(root, 'ls-remote', '--heads', 'origin', 'refs/heads/' + branch).strip()
    additions = []
    for row in candidate['files']:
        raw = git(root, 'cat-file', 'blob', row['blob']) if 'blob' in row else git(root, 'show', candidate['source'] + ':' + row['path'])
        assert len(raw) == row['bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256']
        additions.append({'path': row['path'], 'contents': base64.b64encode(raw).decode()})
    request = {'query': 'mutation($input:CreateCommitOnBranchInput!){createCommitOnBranch(input:$input){commit{oid tree{oid} signature{isValid state}}}}', 'variables': {'input': {'branch': {'repositoryNameWithOwner': repo, 'branchName': branch}, 'expectedHeadOid': candidate['parent'], 'message': {'headline': title}, 'fileChanges': {'additions': additions}}}}
    path = out / (label + '-signed-request.json')
    assert not path.exists()
    path.write_text(json.dumps(request) + '\n', encoding='utf8')
    created = gh('api', '--method', 'POST', 'repos/' + repo + '/git/refs', '-f', 'ref=refs/heads/' + branch, '-f', 'sha=' + candidate['parent'])
    (out / (label + '-branch-created.json')).write_text(json.dumps(created, indent=2) + '\n', encoding='utf8')
    result = gh('api', 'graphql', '--input', str(path))
    (out / (label + '-signed-response.json')).write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
    assert not result.get('errors')
    commit = result['data']['createCommitOnBranch']['commit']
    assert commit['signature']['isValid'] and commit['signature']['state'] == 'VALID' and commit['tree']['oid'] == candidate['tree']
    receipt = {'status': 'PASS_SIGNED_EXACT_TREE', 'source': candidate['source'], 'parent': candidate['parent'], 'signed_commit': commit['oid'], 'tree': commit['tree']['oid'], 'signature_valid': True, 'branch': branch, 'file_count': len(additions), 'utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    (out / (label + '-source-promoted.json')).write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf8')
    return receipt

candidate=json.loads((out/'client-candidate.json').read_bytes())
title='Keep raw Dart crash details out of diagnostic console logs'
client=signed('client','Kiwunaka/POKROV-app',Path('E:/r12client'),candidate,'codex/dart-crash-privacy-signed-20260912',title)
url=subprocess.check_output(['gh','pr','create','--repo','Kiwunaka/POKROV-app','--base','main','--head',client['branch'],'--draft','--title',title,'--body-file',str(out/'client-pr-body.md')],text=True).strip()
client['pr']=url;(out/'client-source-promoted.json').write_text(json.dumps(client,indent=2)+'\n');print(json.dumps(client))
