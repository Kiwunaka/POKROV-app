# Dart crash privacy: current packages and Android exit evidence

Document class: EVIDENCE. [Receipt and captured hashes](receipt.json).
The [source fix](../2026-09-12-r12-dart-crash-privacy/README.md) stops forwarding
raw Flutter/isolate exceptions and stacks to console handlers. Source f7115c50,
Core6b271dec. PR124 and merge268b7556 have successful exact CI, verified signed
tree equality and unchanged branch protections. This is source promotion.

Four production-signed direct APKs and one store AAB have exact4053 version,
three intended ABI coverage, current compiled Dart revision, Core/Flutter hashes
and four source notice files. All current DEX bytes match previously parsed
inputs. Windows setup and all304 staged/extracted payload files match; nine
Release CTest cases pass. The first CTest invocation lacked the build's temporary
P: mapping and could not create its log; the corrected mapping run passes and
restores the original mappings. Authenticode remains SKIPPED_BY_OWNER. No store
submission, public artifact distribution or new Windows installation occurred.

Prior seven package files were hash-verified on owned private DE storage before
overwriting build outputs. Four exact duplicate APK copies were removed only
after verifying their retained originals. Intermediate compression preserves
every file hash. Build guards retain their measured disk minima above40GiB.
The installer extractor ran unprivileged with an empty network namespace in the
owned Ubuntu VM, never executed the installer, and shut down within its budget.

The current x86_64 APK updates owned LDPlayer14 index3 with the same UID and all
six private preference files unchanged. In a temporary rooted boot, an ordinary
VPN connection precedes `am crash` of the verified app PID. The PID dies and TUN
disappears. Its active marker remains byte-exact and all30 persisted operational
events survive. Relaunch creates a new run and records APP-BOOT-006, accurately
classifying the previous native process exit as unclean. This does not exercise
the Dart CRASH-001 callback or establish a crash-index/support-bundle record.
The retained service record alone is not a live process; the PID is absent.

Ordinary reconnect and three HTTPS probes pass. SIGSTOP holds the same app
process for15.27 seconds: the HTTP observer exceeds its15-second harness timeout.
The finally block resumes that PID; three following HTTPS requests pass, the
active marker is unchanged, and ordinary disconnect removes TUN/service and
restores IPv4/DNS plus IPv6 after only its observed expiry countdown is normalized.
This is a bounded whole-process freeze, not Android ANR classification or a full
leak/hang matrix. Initial observer snapshots incorrectly skipped journal files
because of su argument quoting; corrected snapshots prove the event retention.
Original limited captures remain identified in android-exit/result.json.

Root is restored to false and the next boot confirms su exit127. A normal
rootless connection passes three HTTPS probes. After Disconnect, one request
times out, then two pass: the original failure is retained, not called3/3.
TUN/service are absent and network hashes restore. Both Android boots finish
stopped, all other emulator disks are unchanged, and host route/DNS hashes match.
Phone/Hiddify are untouched. Full privacy, licensing and release gates stay open.
