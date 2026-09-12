from pathlib import Path
import json,datetime,re
import ui,baseline as b,inject
out=Path(__file__).parent
native=json.loads((out/'native-input.json').read_bytes())
needles=sorted(set(native['marker_values_synthetic'].values())|set(re.findall(r'R12_ANDROID_[A-Z]+_2c_20260912',json.dumps(native['marker_values_synthetic']))))
inject.scan=lambda raw:{needle:raw.count(needle.encode()) for needle in needles}
pid=ui.run('shell','pidof',ui.pkg).decode().strip();assert int(pid)==native['app_pid']
sources={'native_journal':b.private+'/no_backup/observability/android-operational-v1.jsonl','operational_events':b.private+'/files/pokrov-observability/operational-events.v1.0.jsonl','previous_exit':b.private+'/files/pokrov-observability/previous-exit.v1.json'}
rows=[]
for label,path in sources.items():
    raw=b.read(path);counts=inject.scan(raw);assert not any(counts.values())
    rows.append({'sink':label,'bytes':len(raw),'sha256':b.sha(raw),'marker_counts':counts})
logs=ui.run('logcat','-d','--pid='+pid);assert not any(inject.scan(logs).values())
rows.append({'sink':'available_app_pid_logcat','bytes':len(logs),'sha256':b.sha(logs),'marker_counts':inject.scan(logs)})
tree=ui.texts(ui.tree());raw=json.dumps(tree,ensure_ascii=False).encode();assert not any(inject.scan(raw).values())
rows.append({'sink':'current_visible_ui','bytes':len(raw),'sha256':b.sha(raw),'marker_counts':inject.scan(raw)})
r={'status':'PASS_BOUNDED_CURRENT_SINKS','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'same_native_failure_process':True,'app_pid':int(pid),'sinks':rows,'raw_private_content_exported':False}
(out/'local-sinks-fragments.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':r['status'],'sinks':len(rows),'same_native_failure_process':True}))
