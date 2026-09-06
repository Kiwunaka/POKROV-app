from pathlib import Path
import json,re
root=Path('E:/r12-c05-header-review')
candidates=json.loads((root/'header-candidates.json').read_text())
asset=Path('E:/r12client/packages/app_shell/assets/licenses/native-go-NOTICES.txt').read_text()
def body(text):
    text=text.replace('/*','').replace('*/','')
    for _ in range(3): text=re.sub(r'(?m)^[ \t]*(?://|\*|#)[ \t]?', '',text)
    start=re.search(r'Copyright',text,re.I)
    if start: text=text[start.start():]
    return re.sub(r'\s+',' ',text).strip()
asset_norm=body(asset)
groups={}
for b in candidates['blocks']:
    key=body(b['text'])
    if key in asset_norm: disposition='already_present_body'
    else: disposition='missing_body'
    groups.setdefault(key,{'body':key,'disposition':disposition,'blocks':[]})['blocks'].append(b['sha256_normalized'])
result={'groups':list(groups.values())}
(root/'body-review.json').write_text(json.dumps(result,indent=2)+'\n')
for i,g in enumerate(result['groups']): print(i,g['disposition'],len(g['blocks']),g['body'][:145].encode('ascii','backslashreplace').decode())
