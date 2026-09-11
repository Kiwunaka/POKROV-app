from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent
root=Path('C:/r12-current-windows-source-20260911')
old=Path('E:/r12-n05-windows-source-20260911/apps/windows_shell/build/release_bundle/pokrov-windows-x64-1.2.0+4053')
new=root/'apps/windows_shell/build/release_bundle/pokrov-windows-x64-1.2.0+4053'
def inventory(p):return {f.relative_to(p).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in p.rglob('*') if f.is_file()}
a=inventory(old);b=inventory(new)
assert set(a)==set(b)
changed=[{'path':p,'old_sha256':a[p],'new_sha256':b[p]} for p in a if a[p]!=b[p]]
source_diff=subprocess.check_output(['git','-C',str(root),'diff','--name-only','7ed18c97c43ba39ce18701220d487af1b0c5a446','HEAD','--','packages','apps','config','scripts','.github'],text=True).splitlines()
assert source_diff==['packages/app_shell/lib/src/shell/navigation_shell.dart','packages/app_shell/test/pokrov_seed_app_test.dart']
subprocess.run(['git','-C',str(root),'diff','--exit-code','HEAD','--'],check=True,capture_output=True)
status=subprocess.check_output(['git','-C',str(root),'status','--porcelain'],text=True)
ci=json.loads((out/'client-ci-main.json').read_text(encoding='utf-8-sig'))
assert len(ci)==1 and ci[0]['headSha']=='d9763e8cd7aba9b215015e07c0576f667c1dec09' and ci[0]['conclusion']=='success'
result={'client_revision':'d9763e8cd7aba9b215015e07c0576f667c1dec09','previous_installed_source':'7ed18c97c43ba39ce18701220d487af1b0c5a446','product_source_differences':source_diff,'bundle_files':len(a),'unchanged_bundle_hashes':len(a)-len(changed),'changed_bundle_files':changed,'no_product_source_diff_after_build':True,'status_after_normalization':status,'main_ci':ci,'installed_current_package':False}
assert not (out/'source-and-package-comparison.json').exists()
(out/'source-and-package-comparison.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
print(json.dumps(result,indent=2))
