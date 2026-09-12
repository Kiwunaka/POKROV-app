# Marker replacement: current packages and source promotion

Document class: EVIDENCE. [Receipt and captured hashes](receipt.json).
The [source fix](../2026-09-12-r12-marker-atomicity/README.md) removes the
pre-rename deletion of the previous crash marker. Two fault tests first
reproduced loss of the old file, then passed with the fix; all 31 package tests
and analysis pass. A native Windows sharing-violation fixture preserves the
old bytes on failure and replaces the existing target after the lock is released.
This proves the tested failure mode, not power-loss durability.

PR125 and main d6c7c3de have successful exact CI, verified signed tree equality
and unchanged branch protections. Active package source is 8067520c/Core6b;
the retained promotion binding distinguishes the compiled local commit from
its equivalent promoted active source. Conditional CI skips remain skips.

Four production-signed direct APKs and one store AAB pass version4053, intended
ABI, current compiled Dart revision, Core/Flutter identity and four source
notice checks. Current DEX bytes match previously parsed inputs. Windows setup
and all304 staged/extracted payload files match; only data/app.so changed from
the preceding package, with all303 other payload files unchanged. Nine Release
CTest cases pass. Authenticode remains SKIPPED_BY_OWNER. No store submission,
public artifact distribution occurred. No current package installation had
occurred at the packaging capture time; the later Android check is recorded below.

The first direct build stopped at its storage guard; its original logs and
measured minima remain under stopped-* names. Both drives stayed above40GiB.
Five prior Android packages were hash-verified on owned private DE storage.
Three old store intermediate groups were streamed to a private archive and
every member hash verified before17 exact retained local files were removed.
Native intermediate compression preserved file hashes. Four proven duplicate
new APK copies were removed with the verified primary APKs retained. The
subsequent direct and store build guards passed. Prior Windows setup and
manifest remain in local rollback storage with exact retained hashes.

The installer extractor used nobody with an empty network namespace in the
owned Ubuntu VM, never executed the installer, and shut down within budget.
Before this source fix, the Windows acceptance attempt could not capture the
VM window correctly. No installer was launched; the VM was returned off and
its snapshots retained. That record is in the platform work-order evidence.
The prior physical Huawei F711 run and earlier Windows installation remain
valid only for their exact prior bytes. New806 installed acceptance, full
privacy/license and release gates remain open.

## 2026-09-12 resumed Windows preflight

After local worktree cleanup, the same Windows11 guest booted with NIC none.
The [resumed preflight](windows-resume-resumed-preflight-result.json) confirms
all304 previous 2aa570/Core6b files, unchanged state/secure-store hashes and
the staged source806 installer hash. The guest remained at its lock screen;
no app input or installer execution occurred. The storage monitor paused it
when host C: free space approached40GiB, despite only17MiB of active VDI growth
on E:. The VM was then shut down through ACPI; all13 snapshot IDs remain.
C: free space later recovered. The temporary host storage change has no
identified writer; it is not attributed to the guest or another application.

[Retained file hashes](windows-resume-files.json) bind the two baseline
observations, monitor result/script and final powered-off receipt. This is
preflight and cleanup evidence; source806 installed acceptance remains open.

## 2026-09-12 installed806 Android x86_64

The [installed result](android-installed-result.json) binds production-signed
x86_64 APK `7ffacdfae3273d0b03d07a4d2157100606ad49fa8d81e466f3df437ca66184c0`
to source8067520c/Core6b. It updates the existing owned LDPlayer index3/API34
from F711; [UID and all six preference files](android-installed-update.json)
remain unchanged. No new package or VM was created.

With temporary lab root, ordinary connection creates TUN and passes three
HTTPS marker checks. An `am crash` of the verified own app PID3157 terminates
that process and removes TUN. The previous active marker stays byte-identical
and all30 current-source events remain persisted. Relaunch PID4212 starts a
new run and records exactly one `app.previous_exit.detected` / APP-BOOT-006
for that new run. Final source806 event count is72. This is unclean native
process-exit detection, not Dart CRASH-001/crash-index execution or Android ANR.
The transient ServiceRecord after process death is retained as record presence,
not evidence of a live VPN service.

The same released app creates [owned support case65](android-installed-case65.json).
The worker validates its exact2398-byte encrypted summary. The UI preview lists
build, network and redaction categories; neither events nor a crash bundle is
claimed. No plaintext/admin-access drill was repeated for this case. Earlier
case64 native canary and extended-access results retain their previous scope.

Rooted reconnect and final disconnected HTTPS controls each pass three requests.
Root=false is restored; a [fresh guest boot](android-installed-rootless.json)
confirms su exit127 and the same installed806 APK. Rootless connection and final
disconnection each pass another three HTTPS checks:15/15 in five named groups.
Each disconnect removes TUN and the service record. IPv4/DNS hashes match the
baseline; IPv6 matches within each boot after normalizing only the observed
expiry countdown. IPv6 equality across the two different boots is not asserted.
Host route/DNS hashes match, all local emulators end stopped, and other-instance
disk sizes remain unchanged. Monitor maxima are11MiB and7MiB; both drives remain
above40GiB throughout the sampled intervals. No guard-triggered quit occurs.

[Connected UI](android-installed-connected.png) and
[rootless final UI](android-installed-final.png) were visually inspected.
The [retention receipt](android-installed-files.json) binds55 exact text/script
captures in the [archive](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/marker-atomicity-20260912/android-installed-evidence.zip) and six direct files.
The original packaging and Windows receipts retain their timestamps and scope.
Released Dart-handler execution, crash-bundle delivery, physical ARM64,
Windows806, complete privacy/license and release acceptance remain open.

Validation: `pwsh -NoProfile -File test/docs-contract.ps1` and
`pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot C:/r12corec02
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start` PASS.
Platform docs tests33 and context audit PASS. The native result validator,
all55 archive-member hashes, seven direct/archive disk-and-index hashes,
263 local links, script syntax, bounded private-material patterns and83 unchanged
registry statuses PASS. Both staged diff checks and release-artifact isolation PASS.


## 2026-09-12 installed806 Dart asynchronous error handler

[Exact result](dart-handler-result.json) records one injected error response to
`flutter/platform` / `Clipboard.setData` in the existing source806 x86_64 APK.
Frida attaches only to the verified owned UID10111/PID2369. The fixture replaces
one method reply with a synthetic code/message; it does not modify the APK or
Dart handler and exports no original clipboard payload. The ordinary diagnostics
copy button triggers the real AOT Dart PlatformDispatcher error handler.
The active marker becomes CRASH-001 with nine breadcrumbs while PID2369 stays
alive. After force-stop/relaunch, new PID4433 records previous-exit CRASH-001
exactly once for its new run. This proves the asynchronous handler, not a fatal
native crash or the separate FlutterError framework handler.

Both synthetic needles are absent from all four available local sinks: PID
logcat (15683 bytes), empty PID crash logcat, marker and operational journal.
Raw private files/logs remain in memory; logcat is never cleared. This scan does
not prove delivery or redaction of a crash support bundle. No case is created.

Two earlier instrument attempts fail with TypeError before injection. Their
receipts remain NOT_INJECTED; casting the duplicated Java Buffer to ByteBuffer
fixes the instrument. The successful fixture resolves the obfuscated response
method by its unique parameter signature and calls the retained native cleanup.
The original failures are not recast as product failures or passing attempts.
The first boot also reaches the conservative384MiB quit threshold before attach.
Its terminal monitor and guard event are retained. Resume and rootless monitors
reuse the original disk baseline and512MiB total budget, with480MiB quit threshold;
maximum cumulative growth is423624704 bytes (404MiB), all sampled disk floors40GiB
pass, and other-instance disk sizes/configs stay unchanged.

The matching17.16.4 server download matches GitHub's asset digest. The test server
binds guest loopback only; the one ADB forward is removed, server PID is stopped
and its exact hash-verified fixture file is removed. A fresh rootless boot gives
su exit127, unchanged installed APK and3/3 HTTPS marker responses. No TUN/service
record remains; rootless per-boot IPv4/DNS and normalized IPv6 match. Host routes
and DNS match the preflight. All local emulators end stopped. No new VM, package
build, source change, source promotion, production configuration or deploy.

[Retention receipt](dart-handler-files.json) binds the result and
[exact captures/instruments](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/marker-atomicity-20260912/dart-handler-evidence.zip), including failed attempts,
three terminal monitors, source806 bindings and tool/package integrity receipts.
Tool binaries and third-party node_modules are excluded from repository evidence.
Physical ARM64, Windows806, framework-error handler, crash-bundle delivery,
complete C05/V01/privacy/license and release gates remain open.

The first validate-seed run in this slice fails repository hygiene because the
previous installed-evidence ZIP was tracked in the client lane. Both text-only
ZIP archives now live in the existing platform evidence family; every ZIP byte
and106 member hashes are preserved. Client receipts change only archive paths.
The original installed receipt and exact relocation hashes remain retained on
the platform. The binary boundary rule is unchanged. Earlier seed PASS was
before that archive was staged and did not cover its tracked placement.

Validation: `python C:/r12-marker-packages-20260912/dart-handler/verify.py`
PASS for the bounded native observations;106 member hashes, source bindings,
local links and unchanged83 registry statuses PASS. Client
`pwsh -NoProfile -File test/docs-contract.ps1` PASS. The first
`pwsh -NoProfile -File scripts/validate-seed.ps1 -CoreRoot C:/r12corec02
-PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start` fails on
prior ZIP placement; the same command passes after relocation and staging.
Platform `python -B -m pytest -p no:cacheprovider tests/test_agent_docs_contract.py
tests/test_agent_context_packet_audit.py -q` PASS33 and `python -B
scripts/agent_context_packet_audit.py --platform-context-root .` PASS.
Staged diff checks and release-artifact isolation PASS. These are local checks;
source, APK, privacy matrix and public-release boundaries remain as stated above.


## 2026-09-12 released806 Dart crash bundle delivery

[Exact result](dart-crash-bundle-result.json) follows one synthetic platform
method error through the existing source806 x86_64 APK into
[owned case66](dart-crash-bundle-case66.json). Same UID10111/PID2508 remains alive
from the active-marker baseline through injection, ordinary consent, upload and
admin access. Nine synthetic categories/18 full values and fragments enter the
single Clipboard.setData error reply. The real asynchronous AOT handler records
CRASH-001/thirteen breadcrumbs; the marker stays byte-identical through delivery.
This is the Flutter platform-message boundary, not a new Core parser-failure test.

A normal L2-confirmed policy for owned case65 allows build/crashes/network/redaction,
Android4053, one packet,1MiB and15minutes. [Consent](dart-crash-bundle-consent.png)
and [preview](dart-crash-bundle-preview.png) precede ordinary Create. Case66 receives
validated2825-byte ciphertext. [Audited access and in-memory worker-key scan](dart-crash-bundle-admin-scan.json)
verify1750-byte plaintext with exactly four files: build identity, crash/index.jsonl,
network summary and redaction report. The102-byte crash index has exactly one
record with only error_code, occurred_at and signature. CRASH-001/c1c1… match the
injected event; its timestamp follows the same-guest marker by1.462ms. Guest and
Brain clocks are not asserted synchronized. No raw exception text, stack, profile,
key, activation code or decrypted payload is exported.

All18 needles are absent from four available local sinks, current captured UI,
admin search/detail and every decrypted file. The redaction report's two removed
items are excluded optional categories, not two detected secret values. Metadata
architecture/last_phase/last_error_code remain null, proof unknown; the crash is
available inside the access-controlled index. No causal attempt or Core-path
coverage is inferred from those missing summary fields. Local encrypted outbox
contents, external OIDC, the separate framework-error handler and physical ARM64
were not rescanned in this slice.

Case-number and diagnostic-ID search find the case. Download requires step-up;
one-use grant, no-store response, replay denial and two new access-audit rows pass.
Both temporary operator sessions are revoked without changing preexisting sessions.
One new owned case is preserved open. Local Disable returns to summary/three files.
The server retains the policy's historical redeemed status; local disable is not
server revocation. The1/1 and1750-byte consumption readings belong to the client's
signed-policy ledger; no server consumption-counter columns are claimed.

The first guest boot cannot expose ADB and has zero display width before APK input;
its failure and terminal monitor remain retained. A normal restart of the same
instance succeeds. Fixture path/timestamp/column corrections are recorded without
changing product code or recreating policy/case. The test server is hash-verified,
loopback-only, then stopped/removed with its ADB forward. Empty input XML is removed.
Root=false and a fresh guest su127 prove restoration. Six HTTPS controls pass;
per-boot IPv4/DNS and normalized IPv6 match, host routes/DNS match, other instance
disks/configs remain unchanged, and all local emulators stop. Three boot monitors
share this slice's original baseline: maximum18MiB of512MiB, sampled40GiB floors
pass. The preceding handler slice's404MiB measurement remains separate and retained.

[File receipt](dart-crash-bundle-files.json) binds exact public captures and
[execution instruments](C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start/docs/developer/work-orders/2026-09-05--consolidated-release-and-post12/evidence/marker-atomicity-20260912/android-dart-crash-bundle-evidence.zip) in the existing platform evidence family.
No new VM, package build, code change, source promotion, production configuration,
push, merge or deploy occurred. The authorized QA policy/case/access records are
real runtime mutations. C05/V01/V04/Q01 and full privacy/license/release gates
remain open; earlier native/Windows/device evidence retains its original scope.

Validation: `python C:/r12-marker-packages-20260912/dart-crash-bundle/verify.py`
PASS for exact native observations. Archive66 member hashes, five direct files,
six disk/index hashes,281 local links, script syntax/private-material patterns
and83 unchanged registry statuses PASS. Client `pwsh -NoProfile -File
test/docs-contract.ps1` and staged-tree `pwsh -NoProfile -File
scripts/validate-seed.ps1 -CoreRoot C:/r12corec02 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start` PASS. Platform
`python -B -m pytest -p no:cacheprovider tests/test_agent_docs_contract.py
tests/test_agent_context_packet_audit.py -q` PASS33; `python -B
scripts/agent_context_packet_audit.py --platform-context-root .` PASS.
Both staged diff checks and release-artifact isolation PASS. No additional
product builds or broad runtime regressions were run for this evidence-only change.
