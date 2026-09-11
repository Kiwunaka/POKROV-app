from pathlib import Path
import json,subprocess,hashlib,datetime
out=Path('E:/r12-c05-utls-license-20260911');scan=json.loads((out/'core-scan.json').read_bytes());rows=[]
for item in scan['binary_scans']:
 p=Path(item['binary']['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==item['binary']['sha256']
 cmd=[scan['scanner']['path'],'-mode','extract',str(p)];r=subprocess.run(cmd,capture_output=True);assert r.returncode==0
 dest=out/(p.stem+'.extract.jsonl');assert not dest.exists();dest.write_bytes(r.stdout)
 s=r.stdout.decode();dec=json.JSONDecoder();objects=[]
 while s.strip():
  obj,i=dec.raw_decode(s.lstrip());objects.append(obj);s=s.lstrip()[i:]
 binary=objects[-1];rows.append({'binary':item['binary'],'command':cmd,'exit_code':0,'extracted_symbols':len(binary.get('pkgSymbols',[])),'report':dest.name,'sha256':hashlib.sha256(r.stdout).hexdigest(),'scanner_function_trace_records':item['symbol_findings']})
 print(p.name,rows[-1]['extracted_symbols'])
code=Path('C:/Users/kiwun/go/pkg/mod/golang.org/x/vuln@v1.7.0/internal/vulncheck/binary.go')
r={'status':'OBSERVED','observed_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scanner':scan['scanner'],'binaries':rows,'interpretation':'When extracted symbols are empty, govulncheck v1.7.0 binary.go uses allKnownVulnerableSymbols at module precision. Function trace records are not extracted symbols or a reachable call graph.','scanner_source':{'path':str(code),'sha256':hashlib.sha256(code.read_bytes()).hexdigest(),'lines':'107-113'}}
(out/'symbol-extraction.json').write_text(json.dumps(r,indent=2)+'\n');(out/'govulncheck-v1.7.0-binary.go.txt').write_bytes(code.read_bytes())
