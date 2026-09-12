from pathlib import Path
import datetime,json,time,hashlib,subprocess
import ui
out=Path(__file__).parent
policy=json.loads((out/'native-policy-issued.json').read_bytes())
expiry=datetime.datetime.fromisoformat(policy['expires_at'].replace('Z','+00:00')).timestamp()
started=time.monotonic();samples=[];seen_active=False
while time.monotonic()-started<420:
    nodes=ui.texts(ui.tree());texts=[n['text'] for n in nodes]
    active=any(t.startswith('Включен до ') for t in texts)
    off=any(t.startswith('Выключен\n') for t in texts)
    summary=any('Файлов: 3 · 1430 байт' in t for t in texts)
    guest_epoch=int(ui.run('shell','date','+%s').strip())
    sample={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'seconds':round(time.monotonic()-started,2),'guest_epoch':guest_epoch,'policy_expiry_epoch':expiry,'active':active,'off':off,'summary':summary,'ui':nodes}
    samples.append(sample);seen_active=seen_active or active
    r={'status':'MONITORING','policy_id':policy['policy_id'],'expires_at':policy['expires_at'],'mutating_ui_actions_after_activation':0,'samples':samples}
    (out/'expiry-observations.json').write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
    if seen_active and off and summary:
        assert guest_epoch>=expiry
        r.update(status='PASS_AUTOMATIC_EXPIRY',disabled_by_user=False,clock_changed=False,observed_after_expiry_seconds=guest_epoch-expiry)
        (out/'autoexpiry-result.json').write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
        print(json.dumps({k:v for k,v in r.items() if k!='samples'}));break
    time.sleep(10)
else:raise RuntimeError('expiry not observed in bounded interval')
