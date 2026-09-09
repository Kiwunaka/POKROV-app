from pathlib import Path
import gzip,hashlib,json,urllib.parse,zipfile
import yaml
OUT=Path('E:/r12-c05-flutter-native');ROOT=Path('E:/r12client');SDK=Path('C:/Users/kiwun/tools/flutter/git-3.38.5')
sha=lambda x:hashlib.sha256(x).hexdigest();sep='\n'+'-'*80+'\n'
packages=json.loads(Path('E:/r12-c05-header-review/package-verification.json').read_text())
embedded=[]
for item in packages['android']:
 p=Path(item['path']);assert sha(p.read_bytes())==item['sha256']
 with zipfile.ZipFile(p) as z:
  raw=z.read('assets/flutter_assets/NOTICES.Z');text=gzip.decompress(raw).decode()
  embedded.append({'path':str(p),'compressed_sha256':sha(raw),'text_sha256':sha(text.encode()),'text':text})
p=Path(packages['windows']['path'])/'data/flutter_assets/NOTICES.Z';raw=p.read_bytes();text=gzip.decompress(raw).decode()
embedded.append({'path':str(p),'compressed_sha256':sha(raw),'text_sha256':sha(text.encode()),'text':text})
assert len({e['text_sha256'] for e in embedded[:4]})==1
results=[]
for target in ['android_shell','windows_shell']:
 notice=embedded[0 if target=='android_shell' else -1]['text']
 (OUT/(target+'-packaged-NOTICES.txt')).write_bytes(notice.encode('utf8'))
 actual={}
 for entry in notice.split(sep):
  names,body=entry.split('\n\n',1)
  assert body not in actual
  actual[body]=set(names.split('\n'))
 config_path=ROOT/'apps'/target/'.dart_tool/package_config.json';config=json.loads(config_path.read_text());expected={};inventory=[];missing=[];additional=[]
 for pkg in config['packages']:
  uri=urllib.parse.urljoin(config_path.as_uri(),pkg['rootUri'])
  root=Path(urllib.parse.unquote(urllib.parse.urlsplit(uri).path).lstrip('/'))
  package_root=(root/pkg.get('packageUri','lib/')).resolve().parent
  license_path=package_root/'NOTICES'
  if not license_path.is_file():license_path=package_root/'LICENSE'
  pubspec=package_root/'pubspec.yaml'
  if pubspec.is_file():
   obj=yaml.safe_load(pubspec.read_text(encoding='utf8'));additional.extend({'package':pkg['name'],'file':str(root/f)} for f in (obj.get('flutter') or {}).get('licenses',[]))
  if not license_path.is_file():missing.append({'package':pkg['name'],'root':str(root)});continue
  raw=license_path.read_bytes();text=raw.decode('utf8');blocks=text.split(sep)
  entry={'package':pkg['name'],'path':str(license_path),'sha256':sha(raw),'blocks':[]}
  for block in blocks:
   if len(blocks)>1 and '\n\n' in block:names,body=block.split('\n\n',1);names=names.split('\n')
   else:names=[pkg['name']];body=block
   expected.setdefault(body,set()).update(names)
   entry['blocks'].append({'body_sha256':sha(body.encode()),'names':names,'body_in_packaged_notices':body in actual,'names_in_packaged_notices':set(names)<=actual.get(body,set())})
  inventory.append(entry)
 expected_text=sep.join(sorted('\n'.join(sorted(names))+'\n\n'+body for body,names in expected.items()))
 results.append({'target':target,'package_config_sha256':sha(config_path.read_bytes()),'package_count':len(config['packages']),'license_inputs':inventory,'missing_root_licenses':missing,'additional_licenses':additional,'reconstructed_matches':expected_text==notice,'reconstructed_sha256':sha(expected_text.encode()),'unique_blocks':len(expected),'mismatches':[x['package'] for x in inventory if not all(b['body_in_packaged_notices'] and b['names_in_packaged_notices'] for b in x['blocks'])]})
assert all(r['reconstructed_matches'] and not r['additional_licenses'] for r in results)
result={'schema':'pokrov.c05-flutter-notices/v1','scope':'Exact reconstruction of Flutter LicenseCollector output from current package configs; package names do not prove runtime reachability or complete native licensing.','packaged_notices':[{k:v for k,v in e.items() if k!='text'} for e in embedded],'targets':results,'collector_source':{'path':str(SDK/'packages/flutter_tools/lib/src/license_collector.dart'),'sha256':sha((SDK/'packages/flutter_tools/lib/src/license_collector.dart').read_bytes())},'engine_version':(SDK/'bin/internal/engine.version').read_text().strip()}
(OUT/'flutter-notices.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'packages':len(embedded),'unique_bodies':[r['unique_blocks'] for r in results],'reconstruction':[r['reconstructed_matches'] for r in results],'missing':[r['missing_root_licenses'] for r in results],'sky_engine_blocks':[[len(x['blocks']) for x in r['license_inputs'] if x['package']=='sky_engine'] for r in results]}))
