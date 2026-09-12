# Core6b installed Android — 2026-09-12

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
