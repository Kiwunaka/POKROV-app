# Windows shell regressions — 2026-09-07

Local portable UI evidence; R12-W04 remains partial. [Receipt](evidence.json).
The immutable candidate.33 and its blocked release decision are unchanged.

Repeated `--startup` previously revealed the hidden existing window. Commit
`0f115d0` leaves its visibility unchanged; ordinary launch and acquisition link
still activate the single instance. The same VM probe reproduces the hidden
startup failure on the before bundle and passes on the after bundle.

The native UI also crashed when its message loop ended: the unpatched executable
returns `-1073740771` (`0xC000041D`), with Application Error events in
`flutter_windows.dll`. Commit `98c39d6` calls the existing idempotent `OnDestroy`
from the derived destructor, clearing the Flutter controller before base-window
teardown can dispatch messages into it. The same probe on the fixed executable
returns 0. The event check finds two errors for the red PID and none for the
green PID. This is an observed regression/fix pair, not an inferred pass from
process disappearance.

The final 305-file local bundle includes the existing three CRT DLLs, Core
`8dc57a8`, Flutter/plugins/assets and loopback unavailable API configuration.
Its executable SHA-256 is
`04fa96b7c82a091b2afad8bbbddbc7bd2faa69ac527e2c054ec9f7258f0eeca5`.
The clone has NIC1 none and no installed POKROV service. No production profile
or account was introduced. Six assertions pass: hidden first startup, hidden
repeat startup, ordinary focus, preservation of a visible window on startup,
close-to-tray and acquisition-link activation. The final WM_QUIT cleanup exits 0.

The actual visible tray `Выход` item was then selected using the hypervisor's
absolute mouse input. Its original PID 6404 exits 0, with zero matching crash
events. Guest-injected mouse and keyboard attempts had not activated the item;
their timeout receipts remain rejected input/collector evidence. Two temporary
limited-token interactive tasks were exported then removed. Final readback has
zero UI/service processes, zero up adapters and no POKROV Run key. The clone is
left running offline for subsequent authorized lab work; the original VM is
unchanged. Earlier UI autostart toggles have exact Run-key on/off readbacks;
they do not prove an actual login boot. The failed UIA preference collector is
retained separately.

Validation: Windows `flutter test --reporter expanded` 24 PASS; `flutter analyze`
PASS; native activation CTest 1/1 PASS (startup slice); affected release build
PASS; `pwsh -File scripts/validate-seed.ps1 -PlatformRoot <platform-worktree>
-CoreRoot <Core-worktree>` PASS. PowerShell 5.1 failed on unsupported HashData;
that environmental failure was retained and Core validation rerun under pwsh.

Final packaged install, actual login startup, SCM, connected teardown/proxy
restoration, Windows 10, network/sleep/installer matrices and release channel
remain open. No push, merge, release candidate, publication or production deploy.

Final documentation checks: client seed/docs PASS; platform docs 33 PASS;
context audit PASS; package 13 imports / 83 R12 IDs / 378 legacy IDs / 275 links
PASS; scoped diff check PASS. Final Windows bundle retains the same 305 files
as the startup-fix bundle; only `pokrov_windows.exe` differs. OS readback is
Windows `10.0.26200`, 64-bit.
