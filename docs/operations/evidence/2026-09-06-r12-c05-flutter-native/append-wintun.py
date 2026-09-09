from pathlib import Path
import hashlib,json,subprocess,zipfile
root=Path('E:/r12client');out=Path('E:/r12-c05-flutter-native');prior=json.loads(Path('E:/r12-c05-header-review/assembly.json').read_text());binding=json.loads((out/'wintun-binding.json').read_text())
commit=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip();assert commit=='7bef147c14beea9b8a45a48fedbc22f5205f7f53'
asset=root/prior['notice_asset']['file'];original=asset.read_bytes();assert hashlib.sha256(original).hexdigest()==prior['notice_asset']['sha256']
with zipfile.ZipFile(out/'official/wintun-0.14.1.zip') as z:license=z.read('wintun/LICENSE.txt')
assert hashlib.sha256(license).hexdigest()==binding['license_sha256']
data=bytearray(original)
data.extend(b'\n'+b'='*78+b'\nWintun 0.14.1 prebuilt binary terms (Windows amd64)\n'
 b'Source: https://www.wintun.net/builds/wintun-0.14.1.zip!wintun/LICENSE.txt\n'
 b'This binary is embedded by the Windows Core through sing-tun. These terms\n'
 b'are separate from the Wintun source license and the Go wrapper license.\n'+b'='*78+b'\n\n')
offset=len(data);data.extend(license);data.extend(b'\n')
files=prior['verbatim_files']+[{'source_ref':'https://www.wintun.net/builds/wintun-0.14.1.zip!wintun/LICENSE.txt','body_offset':offset,'bytes':len(license),'sha256':hashlib.sha256(license).hexdigest(),'platform':'windows-amd64','native_component_sha256':binding['native_sha256']}]
assert data[:len(original)]==original
for item in files:assert hashlib.sha256(data[item['body_offset']:item['body_offset']+item['bytes']]).hexdigest()==item['sha256']
r=dict(prior);r.update({'schema':'pokrov.native-go-notices/v4','client_before':commit,'previous_notice':prior['notice_asset'],'notice_asset':{'file':prior['notice_asset']['file'],'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()},'verbatim_files':files,'added_notice_count':1,'native_prebuilt_supplement':binding,'complete_license_clearance':False})
(out/'previous-native-go-NOTICES.txt').write_bytes(original);asset.write_bytes(data)
manifest_path=root/'config/runtime-artifacts.seed.json';manifest=json.loads(manifest_path.read_text());manifest['core']['native_go_notices']['sha256']=r['notice_asset']['sha256'];manifest['core']['native_go_notices']['scope']='Verbatim root, source-package, bounded full file-header and identified embedded-native license notices for recorded Android/Windows Go inputs; complete licensing and corresponding-source clearance remains separate';manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
(out/'assembly.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'asset':r['notice_asset'],'texts':len(files),'added':1,'preserved_previous_bytes':len(original)}))
