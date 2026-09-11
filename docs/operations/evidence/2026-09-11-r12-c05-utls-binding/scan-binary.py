from pathlib import Path
import datetime,hashlib,json,subprocess,sys

out=Path(__file__).parent/'binary-scans';out.mkdir(exist_ok=True)
binary=Path(sys.argv[1]);name=sys.argv[2]
assert binary.is_file() and name.replace('-','').replace('_','').isalnum()
scanner=Path('E:/r12-c05-artifacts/tools/govulncheck.exe')
sbomtool=Path('E:/POKROV-tools/go-tools/bin/cyclonedx-gomod.exe')
go=Path('C:/Users/kiwun/go/pkg/mod/golang.org/toolchain@v0.0.1-go1.26.8.windows-amd64/bin/go.exe')
def ref(p):
    with p.open('rb') as f:digest=hashlib.file_digest(f,'sha256').hexdigest()
    return {'path':str(p),'bytes':p.stat().st_size,'sha256':digest}
def stream(p):
    s=p.read_text(encoding='utf8');d=json.JSONDecoder();rows=[];i=0
    while i<len(s):
        while i<len(s) and s[i].isspace():i+=1
        if i==len(s):break
        row,i=d.raw_decode(s,i);rows.append(row)
    return rows
assert not (out/(name+'.scan.json')).exists()
for tool,module,version in [(scanner,'golang.org/x/vuln','v1.7.0'),(sbomtool,'github.com/CycloneDX/cyclonedx-gomod','v1.10.0')]:
    text=subprocess.check_output([str(go),'version','-m',str(tool)],text=True)
    assert '\tmod\t'+module+'\t'+version+'\t' in text
result={'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'binary':ref(binary),'source_commit':'2662f76a3303a0518bb07fbbdc449c066de2f95b','scanner':ref(scanner),'sbom_tool':ref(sbomtool)}
report=out/(name+'.govulncheck.jsonl');stderr=out/(name+'.govulncheck.stderr.log')
args=[str(scanner),'-mode','binary','-json',str(binary)]
with report.open('wb') as stdout,stderr.open('wb') as errors:
    run=subprocess.run(args,stdout=stdout,stderr=errors,timeout=180)
result.update(command=args,exit_code=run.returncode,report=ref(report),stderr=ref(stderr))
assert run.returncode==0,'Binary scanner failed'
rows=stream(report);findings=[r['finding'] for r in rows if 'finding' in r]
result['advisories']=sorted({r['osv'] for r in findings})
result['symbol_findings']=sum(bool(r.get('trace',[{}])[0].get('function')) for r in findings)
extract=out/(name+'.extract.jsonl');args=[str(scanner),'-mode','extract',str(binary)]
with extract.open('wb') as stdout:run=subprocess.run(args,stdout=stdout,stderr=subprocess.PIPE,timeout=90)
assert run.returncode==0
result['symbol_extraction']={'report':ref(extract),'extracted_symbols':len(stream(extract)[-1].get('pkgSymbols',[])),'interpretation':'Empty extracted symbols cause govulncheck v1.7.0 to report known vulnerable module symbols; function trace records alone do not prove reachability.'}
sbom=out/(name+'.binary.cdx.json');log=out/(name+'.binary-sbom.log')
args=[str(sbomtool),'bin','-std','-json','-notimestamp','-noserial','-output',str(sbom),str(binary)]
with log.open('wb') as output:run=subprocess.run(args,stdout=output,stderr=subprocess.STDOUT,timeout=90)
assert run.returncode==0
result['sbom']={'command':args,'exit_code':run.returncode,'artifact':ref(sbom),'log':ref(log),'components':len(json.loads(sbom.read_bytes()).get('components',[]))}
assert ref(binary)==result['binary']
result['status']='PASS_SCAN_EXECUTION_ONLY_REACHABILITY_TRIAGE_SEPARATE'
result['limits']=['Go binary modules only; stripped symbol absence is not proof of unreachable code.','Native libraries and complete licensing require separate assessment.']
(out/(name+'.scan.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'name':name,'status':result['status'],'advisories':result['advisories'],'symbol_findings':result['symbol_findings'],'sbom_components':result['sbom']['components']}))
