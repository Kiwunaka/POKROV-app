import pathlib,socket,json,time
r=pathlib.Path('/tmp/pokrov-r12-l04-clean-20260911')
pid=int((r/'qemu.pid').read_text())
args=pathlib.Path('/proc/'+str(pid)+'/cmdline').read_bytes().split(b'\0')
assert pid==1891755 and args[0].endswith(b'/qemu-system-x86_64')
assert ('file='+str(r/'guest.qcow2')+',if=virtio,format=qcow2').encode() in args
with socket.socket(socket.AF_UNIX) as c:
 c.settimeout(8);c.connect(str(r/'qmp.sock'));f=c.makefile('rb');assert 'QMP' in json.loads(f.readline())
 def call(command):
  c.sendall((json.dumps({'execute':command})+'\n').encode())
  while True:
   result=json.loads(f.readline())
   if 'event' in result:continue
   assert 'return' in result,result
   return result['return']
 call('qmp_capabilities')
 states=[]
 for _ in range(45):
  status=call('query-status');states.append(status['status'])
  if status['status']=='suspended':break
  time.sleep(1)
 assert states[-1]=='suspended','guest did not enter actual suspend'
 wake=call('system_wakeup');after=call('query-status')
 print(json.dumps({'pid':pid,'observed_states':states,'wakeup':wake,'after':after}))
