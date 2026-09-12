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
captures in the [archive](android-installed-evidence.zip) and six direct files.
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
