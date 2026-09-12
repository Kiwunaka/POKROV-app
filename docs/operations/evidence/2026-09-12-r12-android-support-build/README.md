# Android support receipt and build identity defect — 2026-09-12

Installed client `2aa57015783ceb3415e3be62bbf0a698729011c4`, Core
`6b271decead88b708e2fc03984b703b0a4e63ebd`, x86_64 APK
`baa5202957c46e9ba92e3fff4c46418b60ff309311cfa015aef86da685ac0f52`.
Only owned LDPlayer14 index 3 was used. Device identity was matched to the indexed
console through the boot ID and the installed APK hash was checked before UI use.

## Observed result

PASS_BOUNDED: the real diagnostics screen previewed three files, 1465 plaintext
bytes and zero removed fields. Its explicit Create case with bundle button
created owned case 58 at 04:28 UTC. The server validated all 2445 ciphertext bytes,
SHA-256 `65136a5583657a3e2b9b77ab526e1b614cfcce0dae575ff06bb185265d76df3d`.
Normal admin HTTPS search found the case and diagnostic ID. Download without
step-up was denied; a controlled fixture step-up allowed one exact, no-store
ciphertext download; replay was denied and two audit rows were retained.
The fixture session was revoked and preexisting sessions were unchanged.
The existing worker mount decrypted the packet only in memory: exactly build,
network and redaction files; no extended/crash file or raw content exported.

No native-to-app planted-canary flow was executed in this run. Checking absence
of the prior Windows markers in this summary is only a bounded content scan.
This does not close V01 or Android extended/crash requirements. The expired
Android fixture was not granted access and VPN/TUN was not exercised.

## Confirmed defect and source fix

The accepted Android packet presents `build_number=pokrov-local-client` in admin.
The earlier current Windows case 57 has the same value. Shared diagnostics had
assigned `candidateLabel` to the manifest `build_id` even though it already has
the real numeric build number. The source now uses `buildNumber`, keeping the
wire schema and backend validator unchanged. The existing diagnostics test now
checks the serialized identity hash for build 30 and store channel: it failed
before the one-line fix and passed after it. Android's production builder also
sets direct/store explicitly; previously the store AAB defaulted to local and
therefore generated the direct support channel.

PASS: 24 diagnostics/delivery/support-mode tests, app-shell analysis, docs
contract. A rebuilt package and native numeric-build receipt remain pending.
This source fix changes support bundle metadata; it does not prove new installed
bytes, a release, or the rest of the full plan.

## Environment and retained failures

The first startup left ADB offline for about 223 seconds. Scoped reconnect did
not restore it; the instance was quit. A second launch booted normally, then UI
inspection and the real send completed. Both startup records are retained.
No APK reinstall, data clear, root setting change, VM snapshot or host VPN
operation occurred. Only index 3 ran; all instances are stopped. First/second
VDI growth was 10/6 MiB within the 512 MiB budget; sampled C/E free stayed above
40 GiB. Host route and DNS hashes equal the earlier baseline. The phone was not
used. Case 58 remains open for the next owned-fixture checks.
