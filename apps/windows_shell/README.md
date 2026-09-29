# Windows Shell

ATS-006 source adds service command 21 / capability bit 15 for expected Core,
profile and original boot-relative deadline. The service validates the pinned
module and staged request identity before startup, retains the exact cancellation
owner after response and serializes expiry cleanup. The C++ IPC client negotiates
the command and checks its returned identities. Runner/Dart now dispatch the exact
tuple and retain the cancellation control after ACK until fresh service state
shows restoration. Bound startup requires the optional Core interruptible-start
export and sends cancellation into its context while the DLL call is in flight.
The callback joins before return; Stop and restoration remain serial. Arbitrary
blocked OS calls are not forcibly terminated. Selector/proof/lease handoff
remains open. This is
NOT_VERIFIED source; no Windows build, service call or clock/hash execution ran.

Current responsibility:

- Windows-specific Flutter host entry point for the shared `POKROV` shell
- authenticated `pokrov_service.exe` runtime integration through
  `pokrov_runtime_engine`
- service-owned POKROV Core lifecycle, managed profile, TUN and authenticated
  egress proof
- service-owned Core event ABI 1 callback registration with strict correlation,
  closed-code validation and bounded protected journaling
- versioned service recovery journal and bounded snapshot/restore of the exact
  service-owned `POKROV` TUN interface
- separate protected, bounded and asynchronous privileged lifecycle journal
  for SCM/power, IPC, Wintun/network and rollback breadcrumbs
- one native `POKROV_WINDOWS_CRASH_V1` stack-only profile for both UI and
  service processes; it retains at most 32 allowlisted module-relative frames
  in separate protected current/previous files and never enables a full dump
- local host-runtime sync at `windows/runner/resources/runtime`
- stable POKROV runner metadata
- local release-build verification and unsigned machine-wide installer
  packaging through `..\\..\\scripts\\build-windows-release.ps1`

Current local truth:

Catalog routing preserves selected/excluded EXE data scope before domain rules.
Selected mode rejects unknown process ownership; excluded mode routes matching
EXEs directly. Shared Windows DNS goes through VPN, while an app's own DoH follows
its data route. EXE names do not establish publisher/path identity, and recovery
temporarily applies the existing whole-device guard. Native owner/DNS/recovery
acceptance is required before enabling excluded-app controls or releasing this change.

Candidate selection uses up to four isolated Core probes through authenticated
service IPC, bound to the physical uplink and fenced by its network context.
Cancellation waits for the probe instance to close. Ordinary profile replacement
keeps a persistent, service-owned WFP transition guard until the exact replacement
passes the existing authenticated egress check; failure or service exit retains
the guard. Explicit disconnect, or the elevated `pokrov_service.exe
--clear-transition-guard` repair/uninstall command, removes only its owned rules.
Network and captive-portal observations come from local adapter/NCSI metadata;
unavailable observations remain unknown.
Windows materialization pins the TUN name to `POKROV` before profile identity
binding, so its own route/interface changes do not invalidate the physical
network context during a protected replacement.
The service resolves the egress probe through its owned TUN DNS socket and keeps
the original HTTPS hostname for TLS verification, without a system DNS exception
in the transition guard.
While an ordinary connection is healthy, the existing service watcher repeats
that authenticated check every five seconds, with a five-second check budget.
A failed check clears cached egress readiness while retaining the TUN for the
manager's protected recovery. Disconnect, replacement and service shutdown cancel
and join any pending check; DNS and HTTP waits observe cancellation every 50 ms.
This resolution override requires Windows 10 21H1 or newer, as documented in the
[WinHTTP option compatibility table](https://learn.microsoft.com/en-us/windows/win32/winhttp/option-flags#winhttp_option_resolution_hostname).

- `flutter build windows --release` bundles `pokrov_windows.exe`,
  `pokrov_service.exe`, POKROV Core `pokrov-core.dll`, and pinned
  `libcronet.dll`
- the shared shell keeps local runtime controls out of the first layer and uses one-tap connect from `Protection` on Windows
- the ordinary UI has no `runas` continuation or system-proxy fallback; old
  `systemProxy` preference state migrates to the service/TUN lane
- UI and service install the fail-open native crash filter after their private
  storage roots exist; Dart/Flutter crash markers remain a separate managed
  observability input
- the packaged output stays under `build/release_bundle` and is not a public
  release artifact

Deferred responsibility:

- SCM install/upgrade/uninstall proof and clean-VM full-tunnel, DNS, live
  crash/reboot recovery, route/DNS restoration, selected-apps and sleep/resume
  verification for an exact candidate
- trusted code signing, `MSIX` publication, and updater wiring
- public download hosting, Microsoft Store submission, and product cutover
