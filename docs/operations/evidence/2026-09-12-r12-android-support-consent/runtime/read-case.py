from pathlib import Path
import json,subprocess,shlex,hashlib
out=Path(__file__).parent
remote=r'''
import json,logging,sys,hashlib,datetime as dt
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import User,SupportTicket,SupportBundleUpload
with SessionLocal() as s:
 t=s.get(SupportTicket,59);assert t and t.created_at>=dt.datetime(2026,9,12,6,40)
 u=s.query(User).filter(User.tg_id==t.user_tg_id).one();assert u.is_app_user and u.account_id==t.account_id
 bs=s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id==59).all();assert len(bs)==1
 b=bs[0];assert b.platform=='android' and b.diagnostic_profile=='summary' and b.expected_size_bytes<10000
 r={'status':'PASS_OWNED_ANDROID_CASE_READBACK','case_number':59,'case_status':t.status,'created_at':t.created_at.isoformat(),'install_sha256':hashlib.sha256(str(u.app_install_id).encode()).hexdigest(),'account_sha256':hashlib.sha256(str(u.account_id).encode()).hexdigest(),'is_active':u.is_active,'expiry_at':u.expiry_at.isoformat() if u.expiry_at else None,'bundle':{k:getattr(b,k) for k in ['status','diagnostic_profile','app_version','build_number','platform','architecture','last_phase','last_error_code','expected_size_bytes','received_size_bytes','expected_sha256']},'raw_identifiers_exported':False}
 print(json.dumps(r))
'''
r=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(remote)],capture_output=True,text=True,timeout=40)
assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':hashlib.sha256(r.stderr.encode()).hexdigest()}
v=json.loads(r.stdout);(out/'owned-case-readback.json').write_text(json.dumps(v,indent=2)+'\n');print(json.dumps(v))
