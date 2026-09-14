import os,socket,json,time,pathlib
assert os.getuid()==1000
started=time.time()
with socket.socket(socket.AF_UNIX) as s:
 s.settimeout(70);s.connect('/run/pokrov/pokrov-linuxd.sock');s.sendall((json.dumps({'protocol':'pokrov-linuxd-v1','request_id':'l03-auth8-inactive','action':'connect','payload':{}})+'\n').encode());v=json.loads(s.makefile('rb').readline(65537))
assert v.get('ok') is False and v.get('error_code')=='linux_authorization_denied'
out=pathlib.Path('/home/pokrovqa/acceptance-inputs/candidate8-auth-inactive-response.json');assert not out.exists();result={'uid':1000,'origin':'separate non-active SSH session under unchanged allow_any=no allow_inactive=no policy','started_epoch':started,'finished_epoch':time.time(),'response':v};out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
