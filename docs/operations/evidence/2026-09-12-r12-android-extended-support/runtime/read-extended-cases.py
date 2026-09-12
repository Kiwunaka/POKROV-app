from pathlib import Path
import json,subprocess,shlex,hashlib
out=Path('C:/r12-psm-consent-installed-20260912')
code=r'''
import json,logging,sys,hashlib,datetime as dt
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import User,SupportTicket,SupportBundleUpload,SupportModePolicy
rows=[]
with SessionLocal() as s:
 for case in [60,61,62]:
  t=s.get(SupportTicket,case);assert t and t.created_at>=dt.datetime(2026,9,12,7,6)
  u=s.query(User).filter(User.tg_id==t.user_tg_id).one();assert u.is_app_user and u.account_id==t.account_id and hashlib.sha256(str(u.app_install_id).encode()).hexdigest()=='a8e19d7739f511e191aba5d7bdef9162fc2f91c0709a5d34f516313a7ed8f557'
  bundles=s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id==case).all();assert len(bundles)==1
  b=bundles[0];assert b.platform=='android' and b.diagnostic_profile=='extended' and b.expected_size_bytes<100000
  rows.append({'case_number':case,'created_at':t.created_at.isoformat(),'case_status':t.status,'bundle':{k:getattr(b,k) for k in ['status','diagnostic_profile','app_version','build_number','platform','expected_size_bytes','received_size_bytes','expected_sha256','bundle_id']}})
 p=s.query(SupportModePolicy).filter_by(policy_id='spol-214c09cc7ac049ebb63c457c',ticket_id=58).one()
 policy={c.name:getattr(p,c.name) for c in p.__table__.columns if c.name in ['status','expires_at','consumed_bundle_count','consumed_total_bytes','maximum_bundles','maximum_total_bytes']}
 print(json.dumps({'status':'PASS_OWNED_EXTENDED_CASES_READBACK','cases':rows,'policy':policy,'utc':dt.datetime.now(dt.timezone.utc).isoformat()},default=str))
'''
p=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(code)],capture_output=True,timeout=45);assert p.returncode==0,{'exit':p.returncode,'stderr_sha256':hashlib.sha256(p.stderr).hexdigest()};r=json.loads(p.stdout);(out/'extended-cases-readback.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
