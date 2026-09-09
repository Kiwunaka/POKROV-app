from device import *
import time
receipt={'status':'RUNNING','apk_sha256':'d030288a672b654a70db593f512416113fd2e8ad12025237b94a422c9613f510','source':'c05b58b268bbd789aa96fb662cb46c9768558ef0','scope':'120 seconds forced deep Doze; USB powered; physical Huawei; no battery consumption claim','samples':[]}
def sample(label):
 svc=run('shell','dumpsys','activity','services',PACKAGE);idle=run('shell','dumpsys','deviceidle');rules=run('shell','ip','rule','show');routes=run('shell','ip','route','show','table','all')
 return {'label':label,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'pid':run('shell','pidof',PACKAGE),'service':bool(re.search(r'ServiceRecord\{[^\n]*\.PokrovRuntimeVpnService',svc)),'foreground':'isForeground=true' in svc,'tun':sorted(x for x in run('shell','ls','/sys/class/net').split() if re.fullmatch(r'tun\d+',x)),'idle':{k:re.search(r'\b'+k+r'=(\S+)',idle).group(1) for k in ('mForceIdle','mScreenOn','mCharging','mState','mLightState')},'rules_hashes':sorted(hashlib.sha256(x.encode()).hexdigest() for x in rules.splitlines()),'routes_sha256':hashlib.sha256(routes.encode()).hexdigest()}
def save(): (ROOT/'doze.json').write_text(json.dumps(receipt,indent=2)+'\n')
before=sample('before');receipt['samples'].append(before);assert before['service'] and before['foreground'] and before['idle']['mForceIdle']=='false';save()
run('shell','input','keyevent','KEYCODE_HOME')
try:
 receipt['force_command']=run('shell','dumpsys','deviceidle','force-idle','deep');save()
 started=time.monotonic()
 for i in range(5):
  if i:time.sleep(max(0,started+i*30-time.monotonic()))
  s=sample('forced-'+str(i*30));receipt['samples'].append(s);save()
  assert s['idle']['mState']=='IDLE' and s['idle']['mForceIdle']=='true'
  assert s['pid']==before['pid'] and s['service'] and s['foreground'] and s['tun']==before['tun']
  print(json.dumps({'seconds':i*30,'state':s['idle']['mState'],'same_pid':True,'foreground_service':True}),flush=True)
 receipt['elapsed_seconds']=round(time.monotonic()-started,2);receipt['status']='PASS_FORCED_DOZE_SERVICE_CONTINUITY'
finally:
 receipt['unforce_command']=run('shell','dumpsys','deviceidle','unforce')
 run('shell','am','start','-n',PACKAGE+'/.MainActivity')
 receipt['after']=sample('restored');save();assert receipt['after']['idle']['mForceIdle']=='false';print(json.dumps({'status':receipt['status'],'force_idle_restored':True}),flush=True)
