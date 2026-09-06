from pathlib import Path
import base64,datetime,hashlib,json,uuid
import pefile,jsonschema
from referencing import Registry,Resource
out=Path('E:/r12-c05-flutter-native');p=json.loads((out/'package-verification.json').read_text());engine=json.loads((out/'engine-binary-binding.json').read_text());wintun=json.loads((out/'wintun-binding.json').read_text());plugins=json.loads((out/'windows-plugin-source-auth.json').read_text());downloads=json.loads((out/'official-downloads-verified.json').read_text());notice=json.loads((out/'flutter-notices.json').read_text());bundle=Path(p['windows']['path'])
sha=lambda raw:hashlib.sha256(raw).hexdigest();revision=engine['engine_version'];base='https://storage.googleapis.com/flutter_infra_release/flutter/'+revision+'/';components=[];dependencies=[]
def component(ref,name,version,digest,properties=None,licenses=None,distribution=None):
 value={'type':'library','bom-ref':ref,'name':name,'version':version,'hashes':[{'alg':'SHA-256','content':digest}]}
 if properties:value['properties']=[{'name':k,'value':str(v)} for k,v in properties.items()]
 if licenses:value['licenses']=licenses
 if distribution:value['externalReferences']=[{'type':'distribution','url':distribution}]
 components.append(value);return value
engine_license=[{'license':{'name':'Flutter sky_engine aggregated upstream licenses','url':base+'sky_engine.zip'}}]
license_sha=next(c['sha256'] for c in engine['components'] if c['component']=='sky_engine notices')
for e in engine['components']:
 if e['component']=='windows Flutter DLL':
  digest=sha((bundle/'flutter_windows.dll').read_bytes());assert digest==e['sha256']
  component('flutter-windows-amd64','Flutter engine for Windows amd64',revision,digest,{'pokrov:license-file-sha256':license_sha,'pokrov:binding':'exact official archive DLL'},engine_license,base+'windows-x64-release/windows-x64-flutter.zip')
 if e['component'].startswith('android Flutter '):
  abi=e['component'].split()[-1];entry='lib/'+abi+'/libflutter.so';digests={apk['flutter_engine_entries'][entry] for apk in p['android'] if entry in apk['flutter_engine_entries']};assert digests=={e['packaged_sha256']}
  archive_name=Path(e['official_archive']).name;url=next(d['url'] for d in downloads if d['name']==archive_name)
  component('flutter-android-'+abi,'Flutter engine for Android '+abi,revision,e['packaged_sha256'],{'pokrov:license-file-sha256':license_sha,'pokrov:binding':'exact official artifact after recorded NDK strip operation'},engine_license,url)
core_raw=(bundle/'pokrov-core.dll').read_bytes();assert sha(core_raw)==wintun['parent_sha256']
component('pokrov-core-windows-amd64','POKROV Core for Windows amd64','8dc57a830bd1487389dd1b7c9190f094c31e13bc',sha(core_raw),{'pokrov:scope':'parent artifact for embedded native component; full Go dependency/license SBOM remains separate'})
license_raw=(out/'wintun-binary-LICENSE.txt').read_bytes()
assert sha(license_raw)==wintun['license_sha256']
component('wintun-windows-amd64','Wintun prebuilt API library for Windows amd64','0.14.1',wintun['native_sha256'],{'pokrov:embedded-in-sha256':wintun['parent_sha256'],'pokrov:embedded-offset':wintun['exact_embedded_offset'],'pokrov:license-file-sha256':wintun['license_sha256'],'pokrov:license-review':'API-use and redistribution compatibility remain open'},[{'license':{'name':'Wintun Prebuilt Binaries License','url':'https://www.wintun.net/builds/wintun-0.14.1.zip','text':{'contentType':'text/plain','encoding':'base64','content':base64.b64encode(license_raw).decode()}}}],wintun['download_url'])
dependencies.append({'ref':'pokrov-core-windows-amd64','dependsOn':['wintun-windows-amd64']})
plugin_binding=[];license_inputs=next(t for t in notice['targets'] if t['target']=='windows_shell')['license_inputs']
for plugin in plugins:
 name=plugin['name'];dll=bundle/(name+'_plugin.dll');raw=dll.read_bytes();license_path=Path(plugin['cache_root'])/'LICENSE';license_raw=license_path.read_bytes();input_license=next(x for x in license_inputs if x['package']==name)
 assert sha(license_raw)==input_license['sha256'];assert all(x['body_in_packaged_notices'] and x['names_in_packaged_notices'] for x in input_license['blocks'])
 pe=pefile.PE(data=raw,fast_load=True);pe.parse_data_directories(directories=[pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_IMPORT']]);imports=sorted(x.dll.decode().lower() for x in pe.DIRECTORY_ENTRY_IMPORT);assert 'flutter_windows.dll' in imports
 ref='plugin-'+name
 component(ref,name,plugin['version'],sha(raw),{'pokrov:package-archive-sha256':plugin['archive_sha256'],'pokrov:license-file-sha256':sha(license_raw),'pokrov:license-in-packaged-flutter-notices':'true','pokrov:source-auth':'all recorded Windows package files and root LICENSE match locked pub.dev archive; native source-to-binary reproducibility not claimed'},[{'license':{'name':name+' root LICENSE','text':{'contentType':'text/plain','encoding':'base64','content':base64.b64encode(license_raw).decode()}}}],plugin['archive_url'])
 components[-1]['purl']='pkg:pub/'+name+'@'+plugin['version'];dependencies.append({'ref':ref,'dependsOn':['flutter-windows-amd64']});plugin_binding.append({'component':name,'dll':str(dll),'sha256':sha(raw),'imports':imports,'package_license_sha256':sha(license_raw),'package_license_verified_in_notices':True})
assert len(components)==12
bom={'$schema':'http://cyclonedx.org/schema/bom-1.6.schema.json','bomFormat':'CycloneDX','specVersion':'1.6','serialNumber':'urn:uuid:'+str(uuid.uuid4()),'version':1,'metadata':{'timestamp':datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),'properties':[{'name':'pokrov:scope','value':'Native supplement: exact Flutter engine artifacts, six Windows plugin DLLs, embedded Wintun and its Windows Core parent. Not a complete application SBOM or license/release clearance. Dependency edges are limited to verified imports and embedding.'},{'name':'pokrov:package-evidence','value':'E:/r12-c05-flutter-native/package-verification.json'},{'name':'pokrov:release-status','value':'Internal local packages; production signing, installed privacy, final candidate and overall C05 remain open.'}]},'components':components,'dependencies':dependencies}
registry=Registry();schemas={}
for f in (out/'schemas').glob('*.json'):
 schema=json.loads(f.read_text());schemas[f.name]=schema;registry=registry.with_resource(schema['$id'],Resource.from_contents(schema))
schema=schemas['bom-1.6.schema.json'];validator=jsonschema.validators.validator_for(schema)(schema,registry=registry);validator.validate(bom)
(out/'native-supplement.cdx.json').write_text(json.dumps(bom,indent=2)+'\n');(out/'windows-plugin-binary-binding.json').write_text(json.dumps(plugin_binding,indent=2)+'\n')
print(json.dumps({'status':'PASS_CYCLONEDX_1_6_SCHEMA','native_components':len(components),'dependency_edges':len(dependencies),'scope':'native supplement only'}))
