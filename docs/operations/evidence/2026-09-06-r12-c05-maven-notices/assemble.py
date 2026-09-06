from pathlib import Path
import json,hashlib,zipfile,xml.etree.ElementTree as ET
from bs4 import BeautifulSoup
out=Path('E:/r12-c05-maven-notices');root=Path('E:/r12client');sha=lambda b:hashlib.sha256(b).hexdigest();src=json.loads((out/'source-headers.json').read_text());downloads=json.loads((out/'official-downloads.json').read_text());artifacts=json.loads((out/'artifact-inspection.json').read_text())
# Four matches describe media metadata / bit fields rather than source licensing.
excluded={'94c951c3dc48','4329aad0a8c5','57562bb2fd3d','5f5c079d13c5'}
selected=[r for r in src['bodies'] if r['sha256'][:12] not in excluded];assert len(selected)==159
cc=BeautifulSoup((out/'supplement-inputs/CC-BY-2.5.html').read_bytes(),'html.parser').find(id='legal-code-body');assert cc is not None
cc_text=cc.get_text('\n',strip=True).encode();assert b'4. Restrictions' in cc_text and b'8. Miscellaneous' in cc_text
(out/'supplement-inputs/CC-BY-2.5-extracted.txt').write_bytes(cc_text)
inputs=[]
for name,label in [('Apache-2.0.txt','Apache License 2.0 — declared by the selected Maven POMs'),('kotlin-boost_LICENSE.txt','Boost Software License 1.0 — Kotlin MathJVM derived functions'),('protobuf-LICENSE','Protocol Buffers — shaded dependency within Tink Android'),('CC-BY-2.5-extracted.txt','CC BY 2.5 — Brian Goetz JSR-305 concurrency annotations')]:
 p=out/'supplement-inputs'/name;inputs.append((label,p,p.read_bytes(),{'source':str(p)}))
for r in selected:
 p=out/'headers'/(r['sha256']+'.txt');b=p.read_bytes();assert sha(b)==r['sha256'];refs=sorted(set(x['component'] for x in r['sources']));inputs.append(('Source attribution: '+', '.join(refs),p,b,{'source_headers_sha256':r['sha256'],'source_reference_count':len(r['sources']),'example_source':r['sources'][0]}))
# Retain the binary-packaged AndroidX license in addition to the common Apache text.
p=next((out/'artifact-notices').rglob('LICENSE.txt'));inputs.append(('AndroidX Annotation — license retained in the selected JAR',p,p.read_bytes(),{'source':str(p)}))
text=bytearray(b'POKROV Android third-party Maven notices\n\n')
text.extend(b'Components and versions below identify the selected Android runtime dependency\ninputs. Source attributions include conservative coverage of those artifacts;\nnot every class or source file necessarily survives release shrinking.\n\n')
for row in downloads:text.extend((row['component']+'\n').encode())
text.extend(b'\nTink embeds shaded Protocol Buffers; release-source metadata declares\nprotobuf-javalite 4.33.0. Kotlin MathJVM includes Boost-derived functions.\nJSR-305 concurrency annotations: Brian Goetz, http://www.jcip.net;\nlicense: https://creativecommons.org/licenses/by/2.5/\n\n')
entries=[]
for label,p,b,meta in inputs:
 text.extend(('\n'+'='*78+'\n'+label+'\n'+'='*78+'\n\n').encode());offset=len(text);text.extend(b);text.extend(b'\n');entries.append({'label':label,'source_file':str(p),'body_offset':offset,'bytes':len(b),'sha256':sha(b),**meta})
asset=root/'apps/android_shell/assets/licenses/maven-NOTICES.txt';assert not asset.exists();asset.parent.mkdir(parents=True,exist_ok=True);asset.write_bytes(text)
result={'schema':'pokrov.android-maven-notices/v1','client_before':'509190b19fb08543c9a7fcf9e750c14b6c8429c9','asset':{'path':asset.relative_to(root).as_posix(),'bytes':len(text),'sha256':sha(text)},'bodies':entries,'source_files_scanned':sum(src['file_counts'].values()),'excluded_non_license_comment_prefixes':sorted(excluded),'full_license_clearance':False,'cc_text_transformation':'BeautifulSoup legal-code-body get_text(newline, strip=True); source HTML retained. Other bodies copied byte-for-byte.'}
(out/'assembly.json').write_text(json.dumps(result,indent=2)+'\n');print('asset',len(text),'bodies',len(entries),'sha256',sha(text))
# Component SBOM supplements the Core/Pub/native inventories; it describes build inputs.
ns={'m':'http://maven.apache.org/POM/4.0.0'};components=[];by_key={a['component']:a for a in artifacts['artifacts'] if a['component'] and not a['component'].startswith(('io.flutter',':'))}
for r in downloads:
 key=r['component'];pom=next(f for f in r['files'] if f['url'].endswith('.pom'));lic=pom['declared_licenses']
 if not lic:
  par=pom['parent'];p=out/'supplement-inputs'/f"guava-parent-{par['version']}.pom";tree=ET.fromstring(p.read_bytes());lic=[{x.tag.split('}')[-1]:x.text for x in n} for n in tree.findall('m:licenses/m:license',ns)]
 assert lic and all('Apache' in l['name'] for l in lic),(key,lic)
 if key not in by_key:continue
 a=by_key[key];g,n,v=key.split(':');ref='pkg:maven/'+g+'/'+n+'@'+v
 comp={'type':'library','group':g,'name':n,'version':v,'bom-ref':ref,'purl':ref,'hashes':[{'alg':'SHA-256','content':a['sha256']}],'licenses':[{'license':{'id':'Apache-2.0'}}],'externalReferences':[{'type':'distribution','url':next(f['url'] for f in r['files'] if f.get('matches_selected'))}],'properties':[{'name':'pokrov:evidence-scope','value':'Exact selected runtime artifact; POM license. File-level exceptions are retained in maven-NOTICES.txt; no blanket license clearance or DEX reachability claim.'}]}
 if g=='org.jetbrains.kotlin' and n=='kotlin-stdlib':comp['licenses'].append({'license':{'id':'BSL-1.0'}})
 if g=='com.google.code.findbugs':comp['licenses'].append({'license':{'id':'CC-BY-2.5'}})
 components.append(comp)
ref='pkg:maven/com.google.protobuf/protobuf-javalite@4.33.0';components.append({'type':'library','group':'com.google.protobuf','name':'protobuf-javalite','version':'4.33.0','bom-ref':ref,'purl':ref,'licenses':[{'license':{'id':'BSD-3-Clause'}}],'properties':[{'name':'pokrov:version-evidence','value':'Tink v1.21.0 source declaration; 539 upstream class names plus 3 extra anonymous WireFormat classes in shaded input. Exact binary reproduction unproven.'}]})
bom={'bomFormat':'CycloneDX','specVersion':'1.6','version':1,'metadata':{'component':{'type':'application','name':'POKROV Android Maven dependency-input supplement','version':'1.2.0+4053','bom-ref':'pokrov-android-maven-inputs'}},'components':components,'dependencies':[{'ref':'pokrov-android-maven-inputs','dependsOn':[c['bom-ref'] for c in components[:-1]]},{'ref':'pkg:maven/com.google.crypto.tink/tink-android@1.21.0','dependsOn':[ref]}]}
(out/'maven-supplement.cdx.json').write_text(json.dumps(bom,indent=2)+'\n');print('SBOM components',len(components))
