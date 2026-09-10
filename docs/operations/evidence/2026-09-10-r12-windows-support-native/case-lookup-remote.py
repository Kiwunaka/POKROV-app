import datetime as dt,json,logging,os,pathlib,sys,urllib.parse,urllib.request
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env');sys.path.insert(0,'/root/portal_bot')
from db import SessionLocal
from models import AdminOperator,AdminOperatorSession,SupportBundleUpload,SupportTicket,User
import hashlib
from admin_v2.security import ADMIN_SESSION_COOKIE,OperatorSessionConfig,_issue_session_for_operator
state=json.loads(pathlib.Path('/root/portal-r12-evidence/support-enable-20260910/runtime-case-state-v2.json').read_bytes())
state['ticket_id']=51
with SessionLocal() as guard:
 ticket=guard.get(SupportTicket,51);assert ticket.created_at>=dt.datetime(2026,9,10,12,19)
 user=guard.query(User).filter(User.tg_id==ticket.user_tg_id).one()
 assert hashlib.sha256(str(user.app_install_id).encode()).hexdigest()=='fe746f1300ba28298736b684b3b272af2f0c3d02cf4934def66ee98f581475d0'
 assert user.is_app_user and user.account_id==ticket.account_id
cfg=OperatorSessionConfig.from_env();cfg.validate();issued=None;before={}
report={'status':'UNCONFIRMED','origin':'brain-origin real HTTPS','source_revision':os.environ['PORTAL_BUILD_COMMIT'],'lookup_identity_or_credentials_exported':False,'external_OIDC_tested':False}
def read(path):
 request=urllib.request.Request('https://api.pokrov.space/api/admin/v2'+path,headers={'Cookie':ADMIN_SESSION_COOKIE+'='+issued.token,'Origin':'https://admin.pokrov.space'})
 with urllib.request.urlopen(request,timeout=15) as response:assert response.status==200;return json.load(response)['data']
try:
 with SessionLocal() as s:
  op=s.query(AdminOperator).filter(AdminOperator.legacy_actor_tg_id==state['owner_tg_id'],AdminOperator.status=='active').one()
  before={r.id:(r.revoked_at,r.revoke_reason) for r in s.query(AdminOperatorSession).filter(AdminOperatorSession.operator_id==op.id,AdminOperatorSession.revoked_at.is_(None)).all()};assert len(before)<cfg.max_active_sessions
  held=s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id==state['ticket_id']).one();diagnostic_code=held.bundle_id;error_code=held.last_error_code
  issued=_issue_session_for_operator(s,config=cfg,operator=op,roles=('superadmin',),trace_id=None,audit_action='session.r12_case_lookup_fixture',audit_reason='owned_safe_case_lookup');s.commit()
 for name,query in [('case_number','#'+str(state['ticket_id'])),('diagnostic_code',diagnostic_code)]:
  result=read('/support/search?'+urllib.parse.urlencode({'q':query}))['results']
  own=[r for r in result if r['href'].split('&')[0]=='/tickets?selected='+str(state['ticket_id'])]
  assert own, 'owned case lookup missing'
  report[name]={'status':'PASS','own_result_count':len(own),'no_raw_upload_reference':all('upload_id' not in r and 'object_name' not in r for r in own)}
 detail=read('/support/tickets/'+str(state['ticket_id']));bundles=detail['support_bundles'];assert len(bundles)==1
 bundle=bundles[0];assert bundle['status']=='validated' and bundle['diagnostic_profile']=='summary'
 report['native_case_fields']={k:bundle.get(k) for k in ['diagnostic_profile','app_version','build_number','platform','architecture','last_phase','last_error_code','proof_outcome','attempt_link_source']}
 if error_code:
  known=read('/support/known-issues?'+urllib.parse.urlencode({'error_code':error_code}));report['known_issue_lookup']={'status':'PASS_HTTP','record_count':len(known.get('items',[]))}
 else:report['known_issue_lookup']={'status':'NOT_APPLICABLE_NO_OBSERVED_ERROR_CODE'}
 report['status']='PASS_OWN_CASE_AND_DIAGNOSTIC_CODE_LOOKUP'
finally:
 if issued:
  with SessionLocal() as s:
   row=s.get(AdminOperatorSession,issued.context.session_id);row.revoked_at=dt.datetime.now(dt.timezone.utc).replace(tzinfo=None);row.revoke_reason='r12_case_lookup_cleanup';s.commit()
   report['cleanup']={'fixture_session_revoked':True,'preexisting_sessions_unchanged':all((s.get(AdminOperatorSession,sid).revoked_at,s.get(AdminOperatorSession,sid).revoke_reason)==v for sid,v in before.items())}
   assert all(report['cleanup'].values())
 report['utc']=dt.datetime.now(dt.timezone.utc).isoformat();print(json.dumps(report))
