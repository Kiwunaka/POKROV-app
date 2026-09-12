import argparse,hashlib,json,subprocess,sys,shlex
from pathlib import Path
out=Path(__file__).resolve().parent
sys.path.insert(0,'C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/scripts')
import remote_bind_owned_awg_lab_device as binding
head=binding._REMOTE_HELPER.split('now = datetime.now(timezone.utc).replace(tzinfo=None)',1)[0]
api=binding._REMOTE_HELPER.split('params = {',1)[1].split('def require_isolated_lab_scope(',1)[0]
remote=head+r'''
now = datetime.now(timezone.utc).replace(tzinfo=None)
with SessionLocal() as session:
    users=session.query(User).filter(User.app_platform=='windows').all()
    selected=[u for u in users if hashlib.sha256(str(u.app_install_id or '').encode()).hexdigest()==confirm_target_install_sha256]
    assert len(selected)==1,'owned install selection'
    user=selected[0];install_id=user.app_install_id;tg_id=int(user.tg_id)
    devices=session.query(AccountDevice).filter(AccountDevice.install_id==install_id).all()
    assert len(devices)==1 and devices[0].account_id==user.account_id and user.account_id,'device ownership'
    assert tg_id!=int(admin_id) and bool(user.is_app_user),'isolated app install required'
    assert user.expiry_at is not None and user.expiry_at<now,'already active or no expired grant'
    before={'is_active':bool(user.is_active),'expiry_at':user.expiry_at.isoformat(),'sub_type':user.sub_type,'current_plan_code':user.current_plan_code}
    before_digest=hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest()
    if not payload['apply']:
        print(json.dumps({'utc':now.isoformat(),'status':'PLAN','target_install_sha256':confirm_target_install_sha256,'before':before,'before_digest':before_digest,'delta_days':1,'raw_identifiers_returned':False}))
        raise SystemExit(0)
    assert before_digest==payload['before_digest'],'owned grant changed since plan'
'''+'params = {'+api+r'''
body={'days':1,'delta_days':1,'allow_deactivate':False}
result=guarded('user.extend','user',tg_id,'POST',f'/api/admin/users/{tg_id}/manual/extend',body)
with SessionLocal() as session:
    user=session.query(User).filter(User.tg_id==tg_id).one()
    after={'is_active':bool(user.is_active),'expiry_at':user.expiry_at.isoformat(),'sub_type':user.sub_type,'current_plan_code':user.current_plan_code}
    elapsed=(user.expiry_at-now).total_seconds()
    assert user.is_active and 86400<=elapsed<86700,'one-day grant readback'
print(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'status':'PASS','target_install_sha256':confirm_target_install_sha256,'before':before,'after':after,'delta_days':1,'action':'user.extend','action_intent_used':True,'payment_or_refund':False,'raw_identifiers_returned':False}))
'''
def main():
 p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');args=p.parse_args()
 local=json.loads((out/'installed-after-launch.json').read_text(encoding='utf-8-sig'))
 baseline=json.loads((out/'identity-before-network.json').read_text(encoding='utf-8-sig'))
 assert local['matched_files']==304 and local['client_source']=='2aa57015783ceb3415e3be62bbf0a698729011c4'
 assert baseline['account_present'] and baseline['secure_file_present'] and not baseline['plaintext_session_present']
 assert baseline['install_sha256']=='fe746f1300ba28298736b684b3b272af2f0c3d02cf4934def66ee98f581475d0'
 payload={'device_label_fragment':'','candidate_rank':1,'profile':'default','apply':args.apply,'confirm_target_install_sha256':baseline['install_sha256']}
 if args.apply:payload['before_digest']=json.loads((out/'windows-one-day-plan.json').read_bytes())['before_digest']
 target=out/('windows-one-day-applied.json' if args.apply else 'windows-one-day-plan.json');assert not target.exists()
 result=subprocess.run(['C:/Windows/System32/OpenSSH/ssh.exe','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-brain','/root/portal_bot/venv/bin/python -c '+shlex.quote(remote)],input=json.dumps(payload),capture_output=True,text=True,timeout=120)
 if result.returncode:
  print(json.dumps({'exit':result.returncode,'stderr_sha256':hashlib.sha256(result.stderr.encode()).hexdigest(),'outcome':'UNKNOWN' if args.apply else 'PLAN_FAILED'}));raise SystemExit(1)
 report=json.loads(result.stdout);target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
if __name__=='__main__':main()
