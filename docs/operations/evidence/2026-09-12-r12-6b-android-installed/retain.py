from pathlib import Path
import hashlib,json,re,subprocess,zipfile
out=Path(__file__).parent;client=Path('E:/r12client');platform=Path('C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start');family=client/'docs/operations/evidence/2026-09-12-r12-6b-android-installed'
sha=lambda b:hashlib.sha256(b).hexdigest()
read=lambda n:json.loads((out/n).read_text(encoding='utf-8-sig'))
install=read('install.json');jni=read('jni-privacy.json');startup=read('startup-privacy.json');rest=read('restoration.json')
assert install['status']=='PASS_EXACT_SAME_SIGNER_ANDROID_UPGRADE'
assert jni['status']=='PASS_BOUNDED_ANDROID_JNI_LOG_PRIVACY' and all(jni['child']['exception_contains_markers'])
assert startup['main_ui_visible'] and startup['stored_location_preserved'] and startup['stored_routing_preserved'] and not startup['vpn_service_running']
assert not any(startup['pattern_counts'].values()) and not startup['fatal_exception_seen'] and not startup['anr_seen']
assert rest['status']=='PASS_LDPLAYER_STOPPED' and rest['floor_sampled_pass'] and rest['growth_budget_pass'] and rest['other_disk_sizes_unchanged']
host=Path('C:/r12-6b-installed-20260912/host-network-android-final-after.json');r=json.loads(host.read_text(encoding='utf-8-sig'));assert r['routes_match_before'] and r['dns_match_before']
(out/'host-network-after.json').write_bytes(host.read_bytes())
assert not family.exists();family.mkdir()
rows=[]
for p in sorted(x for x in out.iterdir() if x.is_file() and x.suffix in ['.json','.py','.java','.log','.png']):
    raw=p.read_bytes();assert not re.search(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',raw)
    (family/p.name).write_bytes(raw);rows.append({'path':p.name,'bytes':len(raw),'sha256':sha(raw)})
(family/'capture-manifest.json').write_text(json.dumps(rows,indent=2)+'\n')
(family/'.gitattributes').write_text('* -text whitespace=cr-at-eol\n*.log -whitespace\n')
(family/'README.md').write_text('''# Core6b installed Android — 2026-09-12

Document class: EVIDENCE. [Capture hashes](capture-manifest.json).
Client `2aa57015783ceb3415e3be62bbf0a698729011c4`; Core `6b271decead88b708e2fc03984b703b0a4e63ebd`.
Exact x86_64 APK `baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52`
upgraded the sole authorized LDPlayer index 3 with `adb install -r`.
Prior APK `9ffe8e83cfab393ef765acc0631579d236a9363525f3c71bd5e5d54660666fee`
is retained locally for rollback; app data was not cleared.

Main UI, prior location and routing selection are preserved. Startup log scan
found zero matches in six sensitive-data regex classes and no fatal/ANR marker.
The actual production APK was loaded by a separate Android shell app_process;
debug=false setup and malformed checkConfig used six synthetic categories.
The caller receives all six markers in the JNI exception. None appears in
stdout, stderr or child logcat. Raw streams/exception details were not exported.
This is bounded JNI log privacy, not sanitization of the internal return value
and not proof across app support bundles or all Android sinks.

The owned account is expired; no VPN connection or subscription bypass ran.
The phone was not accessed. Only LDPlayer index 3 ran, then stopped; the other
three instance disks are unchanged. Maximum measured growth 10MiB, sampled C/E
free space above 40GiB; host routes/DNS and Hiddify are unchanged. No root or
network setting was changed. Complete Android TUN, extended/crash diagnostics,
physical-device, source/license and release acceptance remain open.
''',encoding='utf8')
p=client/'docs/operations/android-release-audit.md'
with p.open('a',encoding='utf8') as f:f.write('''
## 2026-09-12 Core6b installed x86_64 acceptance

[Exact current APK on owned LDPlayer index 3](evidence/2026-09-12-r12-6b-android-installed/README.md)
passes same-signer upgrade, preserved UI selections and bounded startup/JNI
log privacy. Six synthetic markers stay in the internal returned JNI exception
but are absent from stdout/stderr/child logcat. The account is expired, so TUN
and entitlement-dependent flows were not exercised. Emulator is off; phone,
host routes/DNS and Hiddify are untouched. Full C05/V01 and release remain open.
''')
print(json.dumps({'status':'PASS_PREPARED_ANDROID_EVIDENCE','captures':len(rows),'bytes':sum(r['bytes'] for r in rows)}))
