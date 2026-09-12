from pathlib import Path
import hashlib,json
p=Path(__file__).parent
inventory=json.loads((p/'android-intermediate-inventory.json').read_bytes());root=Path(inventory['root'])
names=['merged_native_libs','stripped_native_libs','intermediary_bundle','module_bundle']
groups=[]
for name in names:
    files=[]
    for r in inventory['files']:
        if r['relative'].split('/')[0]!=name:continue
        f=root/r['relative']
        with f.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
        files.append({'path':r['relative'],'bytes':r['bytes'],'allocated':r['allocated'],'sha256':digest})
    groups.append({'path':name,'current_core':False,'kind':'completed_intermediate','files':files})
assert sum(len(g['files']) for g in groups)==42
(p/'selected-intermediate-inventory.json').write_text(json.dumps({'root':str(root),'groups':groups},indent=2)+'\n')
s=Path('C:/r12-c05-setup-privacy-20260912/retain-old-native-core-cache.py').read_text()
s=s.replace('core-cache-inventory.json','selected-intermediate-inventory.json').replace('E:/POKROV-workspace-cache/gradle-user-home/caches/8.11.1/transforms','E:/r12client/apps/android_shell/build/app/intermediates').replace("g['kind'] == 'extracted_core'","g['kind'] == 'completed_intermediate'").replace('assert len(groups) == 10','assert len(groups) == 4').replace('retained-old-native-core-cache-20260912','retained-completed-android-intermediates-6b-20260912').replace('old-native-core-cache','completed-intermediate').replace('ten previous extracted POKROV Core transform caches','42 large completed Android build intermediates').replace("'current_core_groups_excluded': 2","'current_core_cache_not_touched': True").replace('before reclaiming the measured Android build reserve','before reclaiming the measured VM acceptance reserve; all six finished packages are retained locally').replace('>8*2**30','>34*2**30').replace('PASS_EXACT_RETIRED_NATIVE_CORE_CACHE_ARCHIVE','PASS_EXACT_COMPLETED_ANDROID_INTERMEDIATE_ARCHIVE')
(p/'retain-completed-intermediates.py').write_text(s)
print(json.dumps({'files':42,'bytes':sum(r['bytes'] for g in groups for r in g['files']),'allocated':sum(r['allocated'] for g in groups for r in g['files'])}))
