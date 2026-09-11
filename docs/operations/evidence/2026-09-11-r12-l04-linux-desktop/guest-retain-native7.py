import pathlib,subprocess,json,hashlib,platform,os
r=pathlib.Path('/home/pokrovqa/acceptance-inputs')
fields=['POKROV_SCHEMA','POKROV_EVENT','POKROV_OUTCOME','POKROV_AUTHORIZATION_BACKEND','POKROV_ERROR_CODE','POKROV_NETWORK_STAGE','POKROV_NETWORK_SUBSYSTEM','POKROV_GENERATION']
p=subprocess.run(['journalctl','-u','pokrov-linuxd.service','--no-pager','-o','json'],capture_output=True,text=True);assert p.returncode==0
events=[]
for line in p.stdout.splitlines():
 try:v=json.loads(line)
 except ValueError:continue
 if v.get('POKROV_SCHEMA')=='pokrov-linux-operational-v1':events.append({k:v[k] for k in fields if k in v})
out=r/'candidate7-daemon-events.json';assert not out.exists();out.write_text(json.dumps(events,indent=2)+'\n')
versions={}
for name in ['systemd','network-manager','systemd-resolved','nftables','xfce4-session','lightdm','policykit-1-gnome']:
 q=subprocess.run(['dpkg-query','-W','-f=${Version}',name],capture_output=True,text=True);assert q.returncode==0;versions[name]=q.stdout
receipt={'distribution':platform.freedesktop_os_release()['PRETTY_NAME'],'architecture':platform.machine(),'kernel':platform.release(),'desktop':'Xfce X11 via LightDM','guest_origin':'pokrov-mini isolated QEMU guest; not RU-origin','ui_uid':1000,'package_versions':versions,'base_image_sha256':'d0fe84bb5f80853425fa6be28e2c106f30104c3cfe8611933f2e65c9b63f0e30','product_absent_before_clean_install':json.loads((r/'clean-install.json').read_text())['package_absent_before'],'polkit_dbus_pass_count':sum(e.get('POKROV_EVENT')=='authorization' and e.get('POKROV_AUTHORIZATION_BACKEND')=='polkit_dbus' and e.get('POKROV_OUTCOME')=='pass' for e in events),'authorization_timeout_count':sum(e.get('POKROV_ERROR_CODE')=='linux_authorization_timeout' for e in events),'timeout_note':'Some operator-observed prompts expired while the automation inspected other evidence; no grant bypass installed.'}
out=r/'candidate7-desktop-environment.json';assert not out.exists();out.write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
