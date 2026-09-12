import ctypes,datetime,hashlib,json,os,pathlib,subprocess
r=pathlib.Path(__file__).parent;binary=pathlib.Path('C:/r12corec02/dist/windows/pokrov-core.dll');core=pathlib.Path('C:/r12corec02');client=pathlib.Path('E:/r12client')
download=json.loads((r/'download.json').read_text());expected=next(x for x in download['files'] if x['path']=='windows-a/pokrov-core.dll')
assert hashlib.sha256(binary.read_bytes()).hexdigest()==expected['sha256']
cookie=os.add_dll_directory(str(binary.parent));dll=ctypes.CDLL(str(binary))
contract=json.loads((core/'config/abi-contract.json').read_text())
exports=contract['desktop_abi']['exports'];assert all(getattr(dll,x) for x in exports)
dll.pokrovCoreAbiVersion.argtypes=[];dll.pokrovCoreAbiVersion.restype=ctypes.c_int
dll.pokrovCoreCapabilities.argtypes=[];dll.pokrovCoreCapabilities.restype=ctypes.c_void_p
dll.freeString.argtypes=[ctypes.c_void_p];dll.freeString.restype=None
abi=dll.pokrovCoreAbiVersion();pointer=dll.pokrovCoreCapabilities();assert pointer
try:descriptor=json.loads(ctypes.string_at(pointer))
finally:dll.freeString(pointer)
log=(r/'proxy-100-cycles.log').read_text(encoding='utf8');assert '+1: All tests passed!' in log and 'PASS: exact Windows Core completed 100' in log
assert abi==2 and descriptor['event_abi']==1
result={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_commit':'6b271decead88b708e2fc03984b703b0a4e63ebd','client_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=client,text=True).strip(),'artifact':expected,'status':'PASS_CURRENT_WINDOWS_ABI_AND_100_PROXY_CYCLES','desktop_abi':abi,'descriptor':descriptor,'exports_found':exports,'cycle_count':100,'test_log_sha256':hashlib.sha256((r/'proxy-100-cycles.log').read_bytes()).hexdigest(),'origin':'current-origin native Windows host','system_route_mutation':False,'physical_vpn_acceptance':False,'windows_imports':['KERNEL32.dll','msvcrt.dll']}
(r/'windows-abi-proxy.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
