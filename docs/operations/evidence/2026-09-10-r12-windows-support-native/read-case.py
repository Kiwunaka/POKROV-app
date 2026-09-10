import json,subprocess,shlex,hashlib
from pathlib import Path
out=Path(__file__).parent
remote=r'''
import json,logging,sys,hashlib,datetime as dt,pathlib,os
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import User,SupportTicket,SupportBundleUpload
with SessionLocal() as s:
 t=s.get(SupportTicket,51);assert t and t.created_at>=dt.datetime(2026,9,10,12,19)
 u=s.query(User).filter(User.tg_id==t.user_tg_id).one()
 assert hashlib.sha256(str(u.app_install_id).encode()).hexdigest()=='fe746f1300ba28298736b684b3b272af2f0c3d02cf4934def66ee98f581475d0'
 assert u.is_app_user and u.account_id==t.account_id
 rows=s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id==t.id).all();assert len(rows)==1
 b=rows[0];r={k:getattr(b,k) for k in ['status','diagnostic_profile','app_version','build_number','platform','architecture','last_phase','last_error_code','proof_outcome','observed_attempts','failure_code','expected_size_bytes','received_size_bytes','expected_sha256']}
 r.update(utc=dt.datetime.now(dt.timezone.utc).isoformat(),origin='brain-origin',case_number=t.id,owned_install_guard=True,raw_identifiers_exported=False,backend_source=os.environ.get('PORTAL_BUILD_COMMIT'))
 print(json.dumps(r))
'''
p=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(remote)],capture_output=True,text=True,timeout=40)
assert p.returncode==0,{'exit':p.returncode,'stderr_sha256':hashlib.sha256(p.stderr.encode()).hexdigest()}
r=json.loads(p.stdout);(out/'native-case-readback.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
