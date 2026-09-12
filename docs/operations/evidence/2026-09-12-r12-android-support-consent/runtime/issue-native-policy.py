from pathlib import Path
import ast,hashlib,json,subprocess
out=Path(__file__).parent
parsed=ast.parse((out/'operator-preflight.py').read_text(encoding='utf-8-sig'))
old=next(ast.literal_eval(n.value) for n in parsed.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='code' for t in n.targets))
prefix=old[:old.index(" status,body=call('/auth/me',authenticated=False)")]
prefix=prefix.replace("'ttl_minutes':5", "'ttl_minutes':15")
prefix=prefix.replace("audit_action='session.r12_psm_preflight'", "audit_action='session.r12_psm_native'")
prefix=prefix.replace("try:\n with SessionLocal()", "private_state=pathlib.Path('/root/portal-r12-evidence/psm-runtime-20260910/android-policy-private-20260912.json');assert not private_state.exists()\ntry:\n with SessionLocal()")
body=r'''
 status,body=call('/auth/me');assert status==200
 assert set(body['data']['operator']['roles'])==set(roles) and 'support.write' in body['data']['operator']['permissions']
 status,body=call('/support/action-intents',command);assert status==200
 prepared=body['data'];intent_id=prepared['intent_id'];assert prepared['risk_level']=='L2'
 headers={'X-Admin-Idempotency-Key':str(uuid.uuid4()),'X-Admin-Confirmation-SHA256':hashlib.sha256(prepared['confirmation_challenge'].encode()).hexdigest()}
 status,body=call('/support/action-intents/'+intent_id+'/execute',command,headers)
 if status!=200:raise RuntimeError('issue_http_'+str(status)+'_'+str(body.get('error',{}).get('code','unknown')))
 data=body['data'];assert data['activation_code'].startswith('PSM1-')
 with private_state.open('x') as f:json.dump({'activation_code':data['activation_code'],'support_mode':data['support_mode'],'intent_id':intent_id},f)
 os.chmod(private_state,0o600)
 status,replay=call('/support/action-intents/'+intent_id+'/execute',command,headers)
 assert status==200 and replay['data']['activation_code']==data['activation_code']
 with SessionLocal() as s:
  policies=s.query(SupportModePolicy).filter_by(ticket_id=58).all();assert len(policies)==old_policy_count+1
  row=next(p for p in policies if p.policy_id==data['support_mode']['policy_id'])
  intent=s.get(AdminActionIntent,intent_id);assert intent.status=='completed'
  assert data['activation_code'] not in intent.result_summary_json
  assert s.query(AdminOperatorAudit).filter_by(session_id=issued.context.session_id,action='session.r12_psm_native').count()==1
  r.update({'status':'PASS_NATIVE_POLICY_ISSUED','ticket_id':58,'policy_id':row.policy_id,'policy_status':row.status,'expires_at':row.expires_at.isoformat()+'Z','current_roles':roles,'l2_confirmation':True,'idempotent_execution':True,'policy_count_delta':1,'activation_code_not_in_intent_storage':True,'fixture_session_audit_retained':True,'code_stored_root_0600_only':True,'audience':{'app_version':row.app_version,'build_number':row.build_number,'platform':row.platform},'categories':json.loads(row.allowed_categories_json),'maximum_bundles':row.maximum_bundles,'maximum_bundle_bytes':row.maximum_bundle_bytes,'maximum_total_bytes':row.maximum_total_bytes})
finally:
 if issued:
  with SessionLocal() as s:
   row=s.get(AdminOperatorSession,issued.context.session_id);row.revoked_at=dt.datetime.now(dt.timezone.utc).replace(tzinfo=None);row.revoke_reason='r12_psm_native_cleanup';s.commit()
   r['fixture_session_revoked']=True;r['preexisting_sessions_unchanged']=all((s.get(AdminOperatorSession,sid).revoked_at,s.get(AdminOperatorSession,sid).revoke_reason)==v for sid,v in before.items());assert r['preexisting_sessions_unchanged']
 r['utc']=dt.datetime.now(dt.timezone.utc).isoformat();print(json.dumps(r))
'''
code=prefix+body
p=subprocess.run(['ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -'],input=code.encode(),capture_output=True,timeout=70)
if p.returncode:
 errors=[line.strip() for line in p.stderr.decode(errors='replace').splitlines() if line.startswith('RuntimeError: issue_http_')]
 print(json.dumps({'status':'FAIL_POLICY_ISSUE','exit':p.returncode,'safe_errors':errors,'stderr_sha256':hashlib.sha256(p.stderr).hexdigest(),'public_partial_status':json.loads(p.stdout) if p.stdout else None}))
 raise SystemExit(1)
r=json.loads(p.stdout);(out/'native-policy-issued.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
