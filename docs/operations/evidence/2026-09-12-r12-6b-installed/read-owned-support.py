import json,subprocess,shlex,hashlib
from pathlib import Path
out=Path(__file__).parent
remote=r'''
import json,logging,sys,hashlib,datetime as dt,os
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import User,SupportTicket,SupportBundleUpload
with SessionLocal() as s:
 t=s.get(SupportTicket,52);assert t
 u=s.query(User).filter(User.tg_id==t.user_tg_id).one()
 assert hashlib.sha256(str(u.app_install_id).encode()).hexdigest()=='fe746f1300ba28298736b684b3b272af2f0c3d02cf4934def66ee98f581475d0'
 assert u.is_app_user and u.account_id==t.account_id
 tickets=s.query(SupportTicket).filter(SupportTicket.user_tg_id==u.tg_id).order_by(SupportTicket.id.desc()).limit(5).all()
 rows=[]
 for t in tickets:
  bundles=s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id==t.id).all()
  rows.append({'case_number':t.id,'status':t.status,'created_at':t.created_at.isoformat(),'bundles':[{k:getattr(b,k) for k in ['status','diagnostic_profile','app_version','build_number','platform','architecture','last_phase','last_error_code','expected_size_bytes','received_size_bytes','expected_sha256']} for b in bundles]})
 print(json.dumps({'status':'PASS_OWNED_FIXTURE_READBACK','backend_source':os.environ.get('PORTAL_BUILD_COMMIT'),'tickets':rows,'utc':dt.datetime.now(dt.timezone.utc).isoformat(),'raw_identifiers_exported':False}))
'''
r=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(remote)],capture_output=True,text=True,timeout=40)
assert r.returncode==0,{'exit':r.returncode,'stderr_sha256':hashlib.sha256(r.stderr.encode()).hexdigest()}
value=json.loads(r.stdout)
name=sys.argv[1] if False else 'owned-support-before.json'
if (out/name).exists():name='owned-support-after.json'
(out/name).write_text(json.dumps(value,indent=2)+'\n');print(json.dumps(value))
