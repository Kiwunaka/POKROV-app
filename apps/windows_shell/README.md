# Windows Shell

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
