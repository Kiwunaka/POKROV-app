from pathlib import Path
import ui,json,sys,datetime
out=Path(__file__).parent;name=sys.argv[1];r={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'ui':ui.texts(ui.tree())};(out/(name+'.json')).write_text(json.dumps(r,indent=2,ensure_ascii=False)+'\n',encoding='utf8');print(json.dumps({'captured':name,'nodes':len(r['ui'])}))
