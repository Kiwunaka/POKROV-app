import pathlib,json,subprocess,hashlib,os,platform,time
assert os.getuid()==0 and platform.node()=='pokrov-r12-l04-clean'
r=pathlib.Path('/home/pokrovqa/acceptance-inputs');out=r/'candidate8-upgrade.json';assert not out.exists()
assert subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True)=='1.2.0~beta.30-7'
assert not pathlib.Path('/sys/class/net/pokrov0').exists() and not pathlib.Path('/var/lib/pokrov/network-recovery.json').exists()
profile=pathlib.Path('/var/lib/pokrov/profiles/active-profile.json');before=hashlib.sha256(profile.read_bytes()).hexdigest()
deb=r/'pokrov_1.2.0~beta.30-8_amd64.deb';sha=hashlib.sha256(deb.read_bytes()).hexdigest();assert sha=='b71c3190ad56e534bcd0057b68de4f818e775bc89cf1d5470814468ad7ada933'
p=subprocess.run(['gpgv','--status-fd','1','--keyring',str(r/'linux-packages-public.gpg'),str(deb)+'.asc',str(deb)],capture_output=True,text=True);assert p.returncode==0 and 'VALIDSIG 29636EDAF204D6F6101CB083B2281E647B0EDDA0 ' in p.stdout
with (r/'candidate8-upgrade.log').open('w') as log:
 p=subprocess.run(['apt-get','-y','install',str(deb)],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive','NEEDRESTART_MODE':'l'},stdout=log,stderr=subprocess.STDOUT)
result={'operation':'upgrade_package7_to8_for_installed_UI_proof','clean_install_claim':False,'sha256':sha,'signature_verified':True,'apt_exit_code':p.returncode,'retained_profile_unchanged':hashlib.sha256(profile.read_bytes()).hexdigest()==before,'installed_version':subprocess.check_output(['dpkg-query','-W','-f=${Version}','pokrov'],text=True),'finished_epoch':time.time()};out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));assert p.returncode==0 and result['retained_profile_unchanged']
