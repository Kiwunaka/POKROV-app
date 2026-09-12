from pathlib import Path
import hashlib,json,subprocess
out=Path(__file__).parent
code=r'''
import datetime as dt,hashlib,json,logging,os,pathlib,sys,urllib.error,urllib.request,uuid
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import AdminOperator,AdminOperatorAudit,AdminOperatorSession,AdminActionIntent,SupportModePolicy,SupportTicket,User
from admin_v2.security import ADMIN_SESSION_COOKIE,OperatorSessionConfig,_active_roles,_issue_session_for_operator
state=json.loads(pathlib.Path('/root/portal-r12-evidence/support-enable-20260910/runtime-case-state-v2.json').read_bytes())
cfg=OperatorSessionConfig.from_env();cfg.validate();issued=None;before={};intent_id=None
r={'status':'UNCONFIRMED','origin':'brain-origin real HTTPS','backend_source':os.environ['PORTAL_BUILD_COMMIT'],'external_oidc_tested':False,'fixture_authentication_used':True,'credentials_exported':False}
def call(path,body=None,headers=None,authenticated=True):
 h={'Origin':'https://admin.pokrov.space'}
 if authenticated:h['Cookie']=ADMIN_SESSION_COOKIE+'='+issued.token
 if body is not None:h['Content-Type']='application/json';h['X-Pokrov-Admin-CSRF']=issued.context.csrf_token
 h.update(headers or {})
 req=urllib.request.Request('https://api.pokrov.space/api/admin/v2'+path,data=None if body is None else json.dumps(body).encode(),headers=h)
 try:
  with urllib.request.urlopen(req,timeout=15) as response:return response.status,json.load(response)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
try:
 with SessionLocal() as s:
  ticket=s.get(SupportTicket,58);assert ticket and ticket.created_at>=dt.datetime(2026,9,12,4,23)
  user=s.query(User).filter(User.tg_id==ticket.user_tg_id).one()
  assert user.is_app_user and user.account_id==ticket.account_id and hashlib.sha256(str(user.app_install_id).encode()).hexdigest()=='a8e19d7739f511e191aba5d7bdef9162fc2f91c0709a5d34f516313a7ed8f557'
  old_policy_count=s.query(SupportModePolicy).filter_by(ticket_id=58).count()
  op=s.query(AdminOperator).filter(AdminOperator.legacy_actor_tg_id==state['owner_tg_id'],AdminOperator.status=='active').one()
  roles=_active_roles(s,operator_id=op.id,environment=cfg.environment);assert roles
  before={row.id:(row.revoked_at,row.revoke_reason) for row in s.query(AdminOperatorSession).filter_by(operator_id=op.id).filter(AdminOperatorSession.revoked_at.is_(None)).all()};assert len(before)<cfg.max_active_sessions
  issued=_issue_session_for_operator(s,config=cfg,operator=op,roles=roles,trace_id=None,audit_action='session.r12_psm_preflight',audit_reason='owned_support_mode_acceptance');s.commit()
  version=max(1,int(ticket.version or 1))
 command={'action':'support.mode.issue','target':{'type':'ticket','id':'58'},'payload':{'expected_version':version,'allowed_categories':['build','events','network','redaction','system'],'allowed_collectors':['build_summary','operational_events','network_summary','redaction_report','system_summary'],'app_version':'1.2.0','build_number':'4053','maximum_bundle_bytes':1048576,'maximum_total_bytes':2097152,'maximum_bundles':2,'platform':'android','ttl_minutes':5}}
 status,body=call('/auth/me',authenticated=False);assert status==401 and body['error']['code']=='operator_session_missing'
 r['no_session_denied']=True
 status,body=call('/auth/me');assert status==200
 operator=body['data']['operator'];assert set(operator['roles'])==set(roles) and 'support.write' in operator['permissions']
 r['current_roles']=operator['roles'];r['support_write_authorized']=True
 status,body=call('/support/action-intents',command,{'X-Pokrov-Admin-CSRF':'invalid-fixture'})
 assert status==403;r['invalid_csrf_denied']=True
 status,body=call('/support/action-intents',command);assert status==200
 intent_id=body['data']['intent_id'];assert body['data']['risk_level']=='L2'
 status,body=call('/support/action-intents/'+intent_id+'/execute',command,{'X-Admin-Idempotency-Key':str(uuid.uuid4()),'X-Admin-Confirmation-SHA256':'0'*64})
 assert status==409 and body['error']['code']=='confirmation_mismatch'
 r['l2_confirmation_enforced']=True
 with SessionLocal() as s:
  assert s.query(SupportModePolicy).filter_by(ticket_id=58).count()==old_policy_count
  audit=s.query(AdminOperatorAudit).filter_by(session_id=issued.context.session_id,action='session.r12_psm_preflight').count();assert audit==1
  intent=s.get(AdminActionIntent,intent_id);assert intent and intent.status=='prepared'
  r['prepared_not_executed']=True;r['new_policy_count']=0;r['fixture_session_audit_retained']=True
 r['status']='PASS_RUNTIME_OPERATOR_PREFLIGHT'
finally:
 if issued:
  with SessionLocal() as s:
   row=s.get(AdminOperatorSession,issued.context.session_id);row.revoked_at=dt.datetime.now(dt.timezone.utc).replace(tzinfo=None);row.revoke_reason='r12_psm_preflight_cleanup';s.commit()
   r['fixture_session_revoked']=True;r['preexisting_sessions_unchanged']=all((s.get(AdminOperatorSession,sid).revoked_at,s.get(AdminOperatorSession,sid).revoke_reason)==v for sid,v in before.items());assert r['preexisting_sessions_unchanged']
 r['utc']=dt.datetime.now(dt.timezone.utc).isoformat();print(json.dumps(r))
'''
p=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -'],input=code.encode(),capture_output=True,timeout=50)
assert p.returncode==0,{'exit':p.returncode,'stderr_sha256':hashlib.sha256(p.stderr).hexdigest(),'public_partial_status':p.stdout.decode(errors='replace')[:2000]}
r=json.loads(p.stdout);(out/'operator-preflight.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8');print(json.dumps(r))
