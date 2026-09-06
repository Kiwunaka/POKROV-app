from pathlib import Path
import hashlib,json,re
root=Path('E:/r12-c05-header-review')
inputs=Path('E:/r12-c05-triage/source-file-inventory.json')
inventory=json.loads(inputs.read_text())
asset=Path('E:/r12client/packages/app_shell/assets/licenses/native-go-NOTICES.txt')
def normalize(text):
    return re.sub(r'\s+', ' ', re.sub(r'(?m)^[ \t]*(?://|\*)[ \t]?', '', text.replace('/*','').replace('*/',''))).strip()
notice=normalize(asset.read_text())
blocks={}; mismatches=[]
for item in inventory:
    path=Path(item['path']); data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=item['sha256']: mismatches.append(item['path']); continue
    text='\n'.join(data.decode('utf-8',errors='replace').splitlines()[:160])
    for match in re.finditer(r'/\*.*?\*/|(?m:^[ \t]*//[^\n]*(?:\n[ \t]*//[^\n]*)*)',text,re.S):
        block=match.group(); normalized=normalize(block)
        if not re.search(r'permission is hereby granted|redistribution and use',normalized,re.I): continue
        if len(normalized)>12000: continue
        key=hashlib.sha256(normalized.encode()).hexdigest()
        entry=blocks.setdefault(key,{'sha256_normalized':key,'text':block,'normalized':normalized,'present_in_notice':normalized in notice,'sources':[]})
        entry['sources'].append({'path':item['path'],'line':text[:match.start()].count('\n')+1,'targets':item['targets']})
result={'scope':'Candidate license-bearing comment blocks in first 160 lines of selected source files. Text presence is normalized substring matching, not a legal completeness verdict. Excludes native transitive includes and full-file obligations.','inventory_sha256':hashlib.sha256(inputs.read_bytes()).hexdigest(),'notice_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'files_checked':len(inventory),'source_hash_mismatches':mismatches,'blocks':sorted(blocks.values(),key=lambda b:b['sha256_normalized'])}
assert not mismatches,mismatches
(root/'header-candidates.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'files':len(inventory),'blocks':len(blocks),'absent':sum(not b['present_in_notice'] for b in blocks.values())}))
for b in blocks.values():
    if not b['present_in_notice']: print(b['sha256_normalized'][:12],len(b['sources']),b['sources'][0]['path'])
