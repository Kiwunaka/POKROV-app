from pathlib import Path
import json,subprocess,hashlib,datetime,re,shlex,sys
import ui
out=Path(__file__).parent;fixture='/data/local/tmp/r126bnetwork20260912';sha=lambda b:hashlib.sha256(b).hexdigest()
def state(label):
 paths=ui.run('shell','pm','path',ui.pkg).decode().strip().removeprefix('package:');apk=ui.run('shell','sha256sum',paths).decode().split()[0];assert apk=='cd9b28f6f01e6d37aa8bb8436d6c8601f23da73eb23fddb5de923d82e74418f8'
 commands={'ipv4_routes':['ip','-4','route','show','table','all'],'ipv6_routes':['ip','-6','route','show','table','all'],'private_dns_mode':['settings','get','global','private_dns_mode'],'private_dns_host':['settings','get','global','private_dns_specifier'],'dns1':['getprop','net.dns1'],'dns2':['getprop','net.dns2']}
 values={k:ui.run('shell',*v) for k,v in commands.items()}
 ipv6=values['ipv6_routes'].decode();expiration_fields=re.findall(r'\bexpires \d+sec\b',ipv6);normalized_ipv6=re.sub(r'\bexpires \d+sec\b','expires <elapsed>sec',ipv6);
 links=ui.run('shell','ip','-o','link','show').decode();tuns=re.findall(r'^\d+: ((?:tun|ppp)[A-Za-z0-9_.-]*)(?:@\S+)?:',links,re.M)
 counters={n:{k:int(ui.run('shell','cat',f'/sys/class/net/{n}/statistics/{k}').decode()) for k in ['rx_bytes','tx_bytes']} for n in tuns}
 services=ui.run('shell','dumpsys','activity','services',ui.pkg)
 texts=[] # UI is captured independently; active animation may prevent uiautomator idle.
 r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'label':label,'installed_apk_sha256':apk,'network_state_hashes':{k:sha(v) for k,v in values.items()},'tun_interfaces':tuns,'counters':counters,'vpn_service_running':bool(re.search(rb'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',services)),'ui':texts,'raw_network_state_exported':False,'ipv6_semantic_sha256':sha(normalized_ipv6.encode()),'ipv6_expiration_fields_observed':len(expiration_fields),'ipv6_normalization':'only observed expires NUMBERsec countdown; raw hash retained'}
 (out/(label+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n',encoding='utf8');(out/(label+'.png')).write_bytes(ui.run('exec-out','screencap','-p'))
 print(json.dumps({k:r[k] for k in ['label','installed_apk_sha256','tun_interfaces','counters','vpn_service_running']}))
 return r
if __name__=='__main__':
 if sys.argv[1]=='prepare':
  ui.run('shell','mkdir',fixture);ui.run('push',str(out/'dex/classes.dex'),fixture+'/classes.dex');ui.run('shell','chmod','444',fixture+'/classes.dex')
  root=subprocess.run([ui.adb,'-s',ui.serial,'shell','su','-c','id'],capture_output=True,timeout=10)
  (out/'root-observation.json').write_text(json.dumps({'existing_su_exit':root.returncode,'existing_su_is_root':b'uid=0(root)' in root.stdout,'stdout_sha256':sha(root.stdout),'stderr_sha256':sha(root.stderr),'root_setting_changed':False},indent=2)+'\n')
  print('Prepared bounded owned HTTP fixture and recorded existing su state')
 elif sys.argv[1]=='probe':
  name=sys.argv[2];count=int(sys.argv[3]);assert 1<=count<=10
  r=subprocess.run([ui.adb,'-s',ui.serial,'shell','env','CLASSPATH='+fixture+'/classes.dex','app_process',fixture,'OwnedHttpsProbe',str(count)],capture_output=True,timeout=150)
  assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':sha(r.stderr)}
  value=json.loads(r.stdout);value['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();value['status']='PASS' if all(x['status']==204 and x['marker_valid'] for x in value['requests']) else 'FAIL';(out/(name+'.json')).write_text(json.dumps(value,indent=2)+'\n');print(json.dumps(value))
 else:state(sys.argv[1])
