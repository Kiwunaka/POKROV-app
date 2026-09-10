# C02 lifecycle ownership — 2026-09-11

Core 904e440 closes the discarded service owner and its five observers, keeps
command-server stop/reload restartable, and synchronizes monitoring shutdown.
The original 12-cycle source regression grew from 37 to 95 goroutines. The
fixed Windows race run retained 199 handles and 38 to 40 goroutines. This
test uses GOMAXPROCS=2 to isolate service ownership from runtime thread pools.

[Binding](binding.json), [Android](android-evidence.json),
[Windows](windows-evidence.json) and [previous pin](previous-runtime-binding.json)
retain exact identities. All five files in two builds match. Dependency graphs
and their [existing SBOMs](../2026-09-10-r12-core-privacy-binding/README.md) are
unchanged. No dependency or license-clearance claim was added.

The exact DLL's first [100-cycle sample](artifact-lifecycle.json) failed the
strict final-window handle assertion: 343 to 427 handles, 419..427 in the last
20 cycles. All 200 loopback sessions still closed. The diagnostic
[300-cycle sample](artifact-lifecycle-v2.json) retained handle types: all 600
sessions closed, file handles stayed at 22, growth was in threads/events and
timers, and the final 20 cycles plus one-second settle stayed at 438 handles.
This is PASS_BOUNDED for that finite run with default Go scheduling, not an
unbounded stability or physical VPN claim. Original failed logs are retained.

The full Core suite and supported Windows/mobile-bridge race tests pass.
Exact Linux race/fuzz/backpressure CI, consumer checks and coordinated
promotion will be appended after completion. Source/build scripts and full
original logs remain in C:/r12-c02-20260911. No device, tag or public release.

Consumer checks: 81 ordinary runtime tests and 8 Android Flutter tests PASS.
The existing isolated helper passed 100 cycles of the exact DLL through Dart.
Seed with explicit platform/Core roots and docs contract PASS. An initial
combined opt-in run used stale shared TEMP and was stopped on database retries;
its local log remains separate. Core initial test, Android/Windows two-build
and Apple build jobs passed; release-contract still requires the new client
pin. [Consumer receipt](consumer-checks.json) retains commands/results limits.

Final source convergence: client PR110 merged `c772160d772fea1450a1c3e94f0df6bb3584fb18`
and Core PR11 merged `edc607c3da66c5d23767a7fe3ca796b5483d68e8`. Both merge trees equal the
reviewed signed sources; all four exact PR/merge CI workflows PASS. The initial
Core release-contract failure remains retained; only that failed job was retried
after client/main bound the matching source. Client merge CI passed after the coordinated Core source became available; no client merge retry was needed.
Linux source race retained 22 to
24 goroutines and 14 to 12 descriptors; config fuzz completed 77,733 inputs.
No installer/APK, device session, public release or production deploy occurred.

Executed commands (Core checkout `C:/r12corec02`, Go 1.26.8; Windows CGO used
`x86_64-w64-mingw32-gcc` from llvm-mingw-20260616):

```powershell
./scripts/test.ps1
go test -race -count=1 ./internal/observability ./v2/config ./v2/hcore ./v2/hutils ./ray2sing/ray2sing
go test -race -count=1 -tags with_clash_api -run '^TestStartStopReleasesServiceObservers$' -v ./v2/hcore
# cwd: C:/r12corec02/engine/sing-box
go test -race -count=1 ./daemon ./experimental/libbox
# cwd: C:/r12corec02; repeated for output suffixes a and b
./scripts/build-android.ps1 -AndroidSdk C:/Users/kiwun/AppData/Local/Android/Sdk -OutputDirectory C:/r12-c02-20260911/android-a
./scripts/build-windows.ps1 -CronetLibrary C:/r12-v01-core-20260910/windows-a/libcronet.dll -OutputDirectory C:/r12-c02-20260911/windows-a
./scripts/new-release-artifact-evidence.ps1 -Lane android -FirstBuildRoot C:/r12-c02-20260911/android-a -SecondBuildRoot C:/r12-c02-20260911/android-b -Output C:/r12-c02-20260911/android-evidence.json -Sbom C:/r12-v01-core-20260910/pokrov-core.cdx.json,C:/r12-v01-core-20260910/sing-box.cdx.json -RequireCleanSource
# Same evidence command with Lane/windows paths for Windows.
python C:/r12-c02-20260911/artifact-lifecycle-v2.py
# cwd: E:/r12client/packages/runtime_engine, then apps/android_shell
flutter test --no-pub
# cwd: E:/r12client
./scripts/test-windows-core-proxy-only.ps1 -CoreRoot C:/r12-c02-20260911/windows-a
./scripts/validate-seed.ps1 -PlatformRoot C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot C:/r12corec02
./test/docs-contract.ps1
./test/release-v2-ci-contract.ps1
```

Final documentation checks: 33 platform tests, context audit, explicit-root
client seed/docs, 714 work-order links plus 26 new/owner links and both diff
checks PASS. No artifacts/releases delta. Final evidence/docs commits remain
local; product source and library binding were merged through PR11/110.
