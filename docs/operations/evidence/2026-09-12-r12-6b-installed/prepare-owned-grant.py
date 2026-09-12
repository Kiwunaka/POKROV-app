from pathlib import Path
p=Path(__file__).parent
s=Path('E:/r12-windows-resume-20260910/extend-owned-windows.py').read_text()
s=s.replace('readback-before.log','installed-after-launch.json').replace('identity-before.json','identity-before-network.json')
old="assert local['matched_files']==304 and local['missing']==0 and local['different']==0"
assert s.count(old)==1
s=s.replace(old,"assert local['matched_files']==304 and local['client_source']=='2aa57015783ceb3415e3be62bbf0a698729011c4'")
(p/'extend-owned-windows.py').write_text(s)
