from pathlib import Path
import json, datetime
out = Path(__file__).parent
read = lambda n: json.loads((out/n).read_text(encoding='utf-8-sig'))
source = read('source-promoted.json')['signed_commit']
installed = read('wizard-readback.json')
final = read('installed-final.json')
events = read('timeline-offline.json')['events']
checks = {
 'installed_exact_304_files': installed['matched_files']==304 and not installed['missing'] and not installed['different'],
 'state_secure_store_preserved': installed['state_preserved'] and installed['secure_store_preserved'],
 'service_running': installed['service_state']=='Running' and final['service_state']=='Running',
 'final_exact_304_files': final['matched_files']==304 and final['missing']==0 and final['different']==0,
 'all_events_exact_revision': len(events)>0 and all(e['git_revision']==source for e in events),
 'all_events_exact_build_number': all(e['build_number']=='4053' for e in events),
 'ui_ready': any(e['name']=='app.bootstrap.ui_ready.finished' and e['outcome']=='succeeded' for e in events),
 'sequence_contiguous': [e['sequence'] for e in events]==list(range(len(events))),
 'offline_no_adapter': installed['adapter_count']==0,
}
assert all(checks.values()), checks
r={'status':'PASS_BOUNDED_BUILD_IDENTITY','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':source,'events':len(events),'checks':checks,'limits':['Offline bootstrap; no new connected-cycle or physical Android proof.','Prior 5a13ec7 zero-revision events remain failed historical evidence.','Previous-exit APP-BOOT-006 is observed, not independently classified here.','No full release acceptance or new public binary publication.']}
(out/'runtime-validation.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8')
print(json.dumps(r))
