from pathlib import Path
import datetime,json,shutil,subprocess,time

out=Path(__file__).parent;root=Path('E:/r12client')
source=subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip()
assert source == '2aa57015783ceb3415e3be62bbf0a698729011c4'
assert json.loads((out/'promotion/client-candidate-coordinated.json').read_bytes())['source']==source
assert json.loads((out/'old-aar-cache-retention.json').read_bytes())['status']=='PASS_EXACT_RETIRED_AAR_CACHE_ARCHIVE'
assert json.loads((out/'old-aar-cache-relocation.json').read_text(encoding='utf-8-sig'))['status']=='PASS_TEN_RETIRED_AAR_CACHES_RELOCATED'
floor=40*2**30
assert shutil.disk_usage('C:/').free>floor+256*2**20
assert shutil.disk_usage('E:/').free>floor+int(2.5*2**30)
assert json.loads((Path('C:/r12-c05-wintun-20260912/output-retention.json')).read_bytes())['status']=='PASS_ALL_PREVIOUS_OUTPUT_BYTES_RETAINED'
result={'status':'RUNNING','source':source,'core':'6b271decead88b708e2fc03984b703b0a4e63ebd','utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'floor_bytes':floor,'abort_margin':256*2**20,'estimated_incremental_android_budget_bytes':int(2.5*2**30),'output_directory_compression':'Mixed NTFS and WOF; allocation measured; newly generated file compression is not assumed','previous_attempt':'First Core6b build stopped above 40GiB; retired Core cache compression freed 1.36GB and ten old AAR caches were hash-verified and relocated to private DE; retry requires 2.5GiB free above reserve','prior_outputs_retained':True,'skipped_build_script_checks':'Focused current runtime81 Android8 seed/docs already passed; full CI and native CTest separate','samples':[]}
with (out/'android-driver-retained-cache-retry.log').open('wb') as log:
    process=subprocess.Popen(['pwsh','-NoLogo','-NoProfile','-File',str(out/'build-android-retained-cache-retry.ps1'),'-ExpectedSource',source],stdout=log,stderr=subprocess.STDOUT,creationflags=0x08000000|0x00004000)
    result['pid']=process.pid
    while True:
        row={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'free_c':shutil.disk_usage('C:/').free,'free_e':shutil.disk_usage('E:/').free};result['samples'].append(row)
        if min(row['free_c'],row['free_e'])<floor+256*2**20:
            subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            result['status']='STOPPED_STORAGE_GUARD';result['exit_code']=process.wait(timeout=30);break
        code=process.poll()
        if code is not None:
            result.update(status='PASS' if code==0 else 'FAILED',exit_code=code);break
        (out/'android-build-progress-retained-cache-retry.json').write_text(json.dumps(result,indent=2)+'\n')
        time.sleep(0.25)
(out/'android-build-progress-retained-cache-retry.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='samples'}))
assert result['status']=='PASS'
