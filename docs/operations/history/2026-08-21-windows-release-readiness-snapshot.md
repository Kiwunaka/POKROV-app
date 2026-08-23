# Retained Windows release readiness snapshot

Document class: `EVIDENCE`
Snapshot date: 2026-08-21

This file preserves the exact readiness/backlog text that existed before
`WO-003G` separated current execution state from candidate-specific history.
Every status below is evidence for its named date or candidate. It is not the
current release decision and cannot authorize a new candidate or promotion.

---

# Windows Release Readiness

Last updated: 2026-08-21

This document is the concrete Windows readiness note for the `POKROV-app` lane.

Historical mapping note:

- older notes may still reference `external/pokrov-next-client/` or `app-next/`
- the initial local snapshot for this repo was bootstrapped from `C:/Users/kiwun/Documents/ai/VPN/app-next/`
- this document now tracks the Windows readiness of the canonical `POKROV-app` repo lane

## Current 1.2.0 Source Truth

- Windows production factory traffic uses `RuntimeLane.windowsService`; the
  ordinary Flutter process neither loads Core nor elevates itself.
- `pokrov_service.exe` is a separate LocalSystem SCM service with an
  owner/Admin/System named-pipe ACL, caller impersonation, owner-SID check,
  server PID/token/binary authentication, protocol/capability negotiation,
  deadlines, session tokens and replay rejection.
- The service owns the sibling `pokrov-core.dll`, fixed protected ProgramData
  runtime directories, atomic managed-profile replacement and Core
  setup/start/stop. It stays alive if the UI exits.
- Connect is green only after a proxy-bypassed WinHTTP request receives exact
  HTTP `204` and `X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1`.
  Failure stops Core and returns sanitized `core_egress_probe_failed` with no
  running/DNS-ready/egress-ready signal.
- The ordinary UI has no process-token elevation check, `runas`, `--connect`
  continuation or system-proxy fallback. A saved legacy `systemProxy` value is
  migrated to the service/TUN lane.
- The Windows bundle now requires `pokrov_service.exe`; portable ZIP is
  unsupported. Inno source installs machine-wide, captures the original user
  SID, writes protected service configuration and creates/updates/starts the
  fixed SCM service. Per-user protocol and autostart registration stay in the
  ordinary UI.
- Local evidence is `PASS` for source contracts, Debug native build, CTest 6/6,
  Flutter tests/analyze, seed/cross-repo validation and unsigned Inno
  syntax/package generation.
- Current source implements `POKROV_RECOVERY_V1` plus a bounded
  `POKROV_NETWORK_V1` snapshot for the exact service-owned `POKROV` TUN
  interface. It captures its prior IPv4/IPv6 interface values, addresses,
  routes and DNS before Core start; rollback stops Core before restoring that
  interface. Any incomplete rollback enters `recovery_required`, reports no
  green state and can be retried idempotently.
- Local fault tests cover every persisted connect stage, repeated disconnect,
  Core-stop, network-restore and journal-completion failures, service-object
  restart, partial journal and future journal. They do not mutate this host's
  live network.
- Privileged lifecycle evidence is separate from the user-space runtime log.
  The service uses a protected, versioned, two-file 256 KiB journal with a
  bounded asynchronous queue and no free-form payload fields. Closed events
  cover SCM and power/boot lifecycle, IPC request/response correlation,
  Wintun/adapter/routes/DNS, egress, commit and rollback. Native tests prove
  format, rotation, forbidden-field absence and runtime emission; they do not
  prove a real sleep, reboot, crash or SCM lifecycle.
- This is not SCM install, a real crash/reboot or uninstall-while-connected
  drill, live route/DNS restoration, clean-VM traffic/DNS, trusted signing or
  exact 1.2.0 candidate proof.

## Retained Pre-Service And 1.1.x Evidence

The bullets and hashes below describe earlier lanes and are retained for audit
history. They do not override the current 1.2.0 service-first truth above.

- The canonical privilege target is
  `docs/architecture/platform-privilege-runtime-contract.md`. Current 1.2.0
  source adds a per-session UI singleton, versioned bounded activation frames
  for ordinary and acquisition launches, and exact `--startup` tray-only login
  behavior. Interactive second-launch focus and login-startup behavior remain
  `MANUAL_OWNER_TEST` until exercised on the exact candidate.
- The privileged Windows service, authenticated service IPC and recovery
  transaction are not release-ready. Current source now builds a separate SCM
  service bootstrap and locally proves its owner-only named-pipe ACL,
  caller-SID check, protocol/capability negotiation, random session token,
  deadlines and duplicate-nonce rejection. It is deliberately not installed
  or bundled, the UI has no service client, and Core/network still run in the
  legacy process. The retained full-process `runas` connect continuation below
  describes the current/1.1.6 lane, not the target; it cannot satisfy 1.2.0
  privilege readiness and will be removed only with a proved service
  replacement.
- the Windows shell is not a blank stub; it boots the shared app shell and drives the desktop FFI `runtime_engine` lane
- the active runtime is POKROV Core `v1.0.3` desktop ABI 2; its exact release commit, DLL hash, and `libcronet.dll` hash are pinned in `config/runtime-artifacts.seed.json`
- `flutter build windows --release` copies `pokrov-core.dll` and `libcronet.dll` next to the Flutter runner
- `scripts/sync-pokrov-core-runtime.ps1` accepts only the exact locally built core commit and artifacts before syncing them into the host
- `scripts/build-windows-release.ps1` runs the local Windows verification lane: seed validation, tests, `flutter analyze`, `flutter build windows --release`, bundle verification, unsigned portable ZIP staging, and a per-user Inno Setup 6 wizard. The wizard exposes the install directory plus optional desktop shortcut and autostart choices and registers the bounded `pokrov://` continuation protocol with uninstall cleanup
- the seed validation inside that helper now aligns with the current product canon: `Android + Windows` public scope, `iOS + macOS` readiness-only hosts
- exact `1.1.6+29` is the current public stable-direct Windows candidate at
  `Kiwunaka/pokrov` tag `v1.1.6`. Setup SHA-256 is
  `DBAA664CF9046205F969204DF79F9366B8A944F7D2A6B8D8BBD371522A3B8AE8`,
  portable ZIP SHA-256 is
  `9ECF90BCDEC496F6820BB6D3A9658A72009C38664C9947C8D7D07B0EF2CBF27A`,
  and manifest SHA-256 is
  `2E4383B901629AEB1998B7774E7E308A333A77C5233335A4200CF5677803886D`.
  GitHub size/digest comparison and anonymous range GET pass for all eight
  Android and Windows release assets. Production serves the exact `1.1.6`
  URL, size, hash and Russian notes; authenticated and anonymous runtime
  catalog checks plus the post-deploy readiness check pass. This release fixes the
  verified-connection UI state, installed tray icon and Russian Inno Setup
  encoding, and blocks only a real competing Windows TUN default route rather
  than the presence of another VPN process. Clean-host TUN/DNS proof remains
  `MANUAL_OWNER_TEST`
- stable direct executables present the public product name `POKROV` and no longer carry the Windows `VS_FF_PRERELEASE` metadata flag; debug builds retain only `VS_FF_DEBUG`
- app-first session secrets must not remain in plaintext JSON state; the current source implements legacy `session_token` migration into platform secure storage, atomically replaces the JSON state, and writes only a `session_token_storage=secure` marker after a durable write; a marker whose platform secret is missing enters recovery instead of minting another trial, while exact-artifact restart proof remains a release gate
- local runtime/control surfaces must stay loopback-only: mixed/system-proxy ports bind to `127.0.0.1`, Clash/control APIs stay disabled unless explicitly protected by a per-install random secret, and no unauthenticated LAN listener is release-acceptable
- loopback helper ports are availability-checked for TCP and UDP during staging. Busy ports are replaced with OS-selected loopback ports so an already-running local proxy such as Hiddify does not make POKROV Core fail before TUN start
- public download copy must match the actual handoff URL and signing state
- support macros must explain SmartScreen or unknown-publisher behavior for gated beta testers
- the shell opens centered at 1280x720 and permits resize down to 700x640 so
  the canonical compact drawer remains reachable. Profile settings expose
  per-user autostart and whether the close button hides to tray (default) or
  exits; tray `Выход` disposes tray state before requesting native teardown
- the regular process remains unelevated. A non-running TUN connect checks the
  Windows token and explains the administrator boundary before requesting
  `runas`. The recommended action continues with the bounded `--connect`
  argument; the explicit no-admin action persists the loopback system-proxy
  compatibility mode before staging. Denial or unavailable native integration
  returns to that choice instead of allowing a proxy-only false TUN success
- source and widget tests prove lifecycle ordering, but connected exact-artifact
  tray exit still requires runtime/TUN teardown and any compatibility
  system-proxy restoration proof
- the local `1.1.2+25` QA build remapped Hiddify's occupied `127.0.0.1:12334` to `127.0.0.1:54303`. Its live TUN attempt affected the active Codex route and was operator-terminated before a final connected event, so this is collision-fix evidence, not clean egress/DNS or teardown PASS
- owner testing of the public `1.1.3+26` build on `2026-08-18` exposed a real Windows failure: Core and the mixed proxy came up, the shell showed a green connected state, but normal browser traffic and DNS through the system TUN stalled. This invalidates `1.1.3` as evidence for working Windows TUN traffic even though its published hashes and install/update handoff remain exact
- current source fixes that false-positive boundary. Windows materialization now matches the known-working local Hiddify/Core shape (`system` by default, strict routing, typed TCP/UDP DNS, explicit port-53 DNS hijack and sniff before LAN/direct or user rules, no legacy `dns-out`), and connect requires both mixed-proxy egress and an ordinary Windows TUN/DNS request before it reports running. The final preference pass now reasserts this order; the earlier `5074138` local candidate still failed because it moved the LAN direct rule back above DNS after the base profile was built. Advanced settings expose Core-supported `mixed`/`gvisor` TUN stacks and a loopback Core-owned system-proxy compatibility mode without changing the default. The owner authorized the exact unsigned `1.1.6` stable-direct publication with the explicit warning; a clean Hiddify-off run remains `MANUAL_OWNER_TEST` before any stronger Windows TUN/DNS claim
- the non-public `1.1.4+27` working-tree candidate was built and installed locally on 2026-08-19. The setup SHA-256 is `5EBFD638B0DCB2E7E70B6A9257C8A73D48D75B181C80B1C437ABB5837B1EA757`; the installed `data/app.so` exactly matched the build at `C5D30FBE718310166202ABAFB8B7F170D31CF5DF6D750C23AA0A9CEBA4541900`. Per owner instruction the newly installed app was left closed, so this is install-integrity evidence only and not Windows TUN/DNS or system-proxy runtime `PASS`
- each desktop start now appends a bounded, secret-free lifecycle journal under the POKROV application-support runtime directory. Support can distinguish initialization, staging, Core start, mixed-proxy verification, each Windows TUN verification attempt, connect, and teardown without retaining browsing history or raw connection material
- the TUN preflight checks an active competing default route rather than a process name. A running Hiddify process therefore does not block POKROV's compatibility system-proxy mode, while a real active `tun*` default route still blocks a second system tunnel before Core start
- a desktop snapshot now marks host, DNS and uplink healthy only after the
  mixed-proxy and required Windows TUN probe pass; the shell therefore leaves
  `Проверяем…` after a proven connection instead of waiting for Android-only
  host callbacks. Disconnect or restaging clears that proof
- Windows preflight recognizes an active competing `tun*` default route and
  blocks before Core start with an actionable close-the-other-tunnel message.
  A merely running Hiddify process is not sufficient evidence of a conflict,
  and compatibility system-proxy mode intentionally skips this TUN-only gate;
  POKROV never terminates the other process itself
- the tray icon is a dedicated transparent POKROV mark bundled beside the EXE,
  and the shell resolves that installed path instead of a source-tree-relative
  path. Inno Setup input is emitted as UTF-8 with BOM plus code page `65001`, so
  Russian shortcut/autostart task labels remain readable

## Retained 2026-08-13 Candidate Evidence

- The historical outside-store Windows beta was `v1.0.4-beta.1`. The exact
  `1.0.4-beta.1+13` candidate was rebuilt from the current tree with pinned
  POKROV Core `v1.0.3`, passed Windows analyze and the full workspace
  Flutter/Android test lane, and was visually checked from the exact EXE at
  `1600x900`. The DPI-aware retained capture shows the complete window; close
  correctly hides the window while the tray process remains responsive.
- The local `1.0.4-beta.1+13` setup SHA-256 is
  `AD93F7F307552210BE4A8E6263382D4D221E993D8D743CEB6809D774DA007095`;
  its portable ZIP SHA-256 is
  `E25A3E7CAF900D8B8DFE14A4AE58DCDB40B3EBC61B2C631916E7F3BD42B28ADD`;
  and its manifest SHA-256 is
  `C08AECB5D88DA0F54D63F1F518AB3BBC6E77A134E3FD910AD517A5AD447FBC55`.
  These hashes describe the public prerelease assets. Setup, portable ZIP,
  and manifest completed anonymous full-size SHA-256 verification, and the
  production synthetic signed `/api/client/apps` response returns the exact
  setup URL, hash, and size.
- The final shared-UI rebuild launched the exact EXE, remained responsive, and
  handled the normal window-close request by hiding the window while keeping
  the tray process alive and responsive. The test process was terminated after
  the smoke; connected tray-exit/TUN teardown remains a separate manual gate.
- The rebuilt setup remains `NotSigned`. The accepted outside-store beta risk
  does not turn that result into trusted signing or SmartScreen reputation.
- Retained visual evidence is under
  `E:/POKROV-ops-evidence/2026-08-13-goal-continuation/windows-app-audit/`,
  including `1.0.4-final-home.png`.

## Local Verification Commands

From `POKROV-app/`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync-pokrov-core-runtime.ps1 -CoreRoot '<POKROV-core checkout>' -Platforms windows
powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1
Push-Location .\apps\windows_shell
flutter analyze
flutter build windows --release
Pop-Location
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -CoreRoot '<POKROV-core checkout>'
```

After launching the exact candidate once, resolve its live application-support
directory from diagnostics and inspect the state file there:

```powershell
$statePath = '<application-support-path>\app-first-session-windows.json'
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
if ($null -ne $state.session_token) { throw 'Raw session_token remains in JSON state.' }
if ($state.session_token_storage -ne 'secure') { throw 'Secure-storage marker is missing.' }
```

Restart the candidate and perform an authenticated profile refresh before
accepting this check. Expected result: no raw `session_token` value in app
state, support export, or logs, and the existing session still works.
The runtime options test must also keep LAN control exposure closed:
`allow-connection-from-lan=false`, `enable-clash-api=false`, and local ports on
`127.0.0.1` only unless a future release explicitly documents a protected
control API.

For a gated beta packaging smoke where tests/analyze already ran:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze
```

If the local Flutter/Dart toolchain fails in the online `pub.dev` security-advisory report while the dependency cache is already populated, rerun with `-OfflinePubGet`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-release.ps1 -SyncRuntime -OfflinePubGet
```

## Expected Local Outputs

- release runner root: `apps/windows_shell/build/windows/x64/runner/Release/`
- staged unsigned bundle root: `apps/windows_shell/build/release_bundle/`
- required release files:
  - `pokrov_windows.exe`
  - `pokrov_service.exe`
  - `flutter_windows.dll`
  - `pokrov-core.dll`
  - `libcronet.dll`
  - `data/app.so`
  - `data/icudtl.dat`
- staged manifest and unsigned setup EXE use the exact names from
  `config/windows-release.seed.json`
- `zip_path` must be `null`; a portable package cannot carry the required SCM
  service contract

These outputs are regenerated local verification artifacts. They are useful for operator inspection and local validation, but they are not production release truth.

Historical local packaging notes:

- `2026-06-03`: `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests -SkipAnalyze`
  succeeded after the full Task 8 verification run.
- The generated unsigned setup EXE, portable ZIP, manifest, and the Android
  debug smoke APK were retained in
  `artifacts/releases/pokrov-app/0.2.0-beta.1+20260603-local-mvp/`.
- This retained pack remains local engineering handoff, not trusted signing or
  public hosting approval.
- `2026-06-04`: the same packaging command succeeded again for the local RC
  pass after Android release-smoke APK/AAB builds. The generated unsigned setup
  EXE, portable ZIP, and manifest were retained in
  `artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/` with
  verified checksums and `runtime_sync_allowed=false`.
- Owner decision on `2026-06-04`: trusted Windows signing is an accepted skip
  for the current outside-store beta, but trusted signing, SmartScreen
  reputation, Microsoft Store, WinGet, and broad stable-distribution claims are
  still not allowed.
- `2026-06-05`: `scripts/build-windows-release.ps1 -SyncRuntime -SkipTests
  -SkipAnalyze` succeeded after the P5/WARP pass and produced local
  `1.0.0-beta` unsigned artifacts under
  `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta*`.
- Phase 6 uploaded `pokrov-windows-setup-x64.exe` on `2026-06-05`; its
  recorded hash is dated evidence and was superseded by the `2026-06-08`
  refresh. Read `config/release-handoff.seed.json` for the current exact
  filename, hash, size, public repository, and download-smoke state.

## Current 2026-08-13 Core Gate

The exact POKROV Core `v1.0.3` DLL pinned in
`config/runtime-artifacts.seed.json` completed 100 serial raw start/stop cycles
through the real desktop bindings. This is `PASS` for DLL loading and lifecycle
shutdown only. A new packaged Windows client candidate, private ACL, TUN
traffic, route modes, DNS/leak, real WARP, sleep/resume, and clean-machine
checks remain required.

## Retained 2026-08-04 Internal Build

The unsigned `1.0.2-core-test.1` Windows client completed the canonical local
release pipeline. The exact local QA artifacts are:

- portable ZIP: `37506815` bytes, SHA-256
  `4a37bc459c582c3ebd368dbc3875382893a7dd951a053fbaf9b39b7624bbbd94`.
- setup EXE: `37392384` bytes, SHA-256
  `27ac017896eeba18b7b5ad9077f731effefe425e556160ee6bfca41fbcbc9570`.
- manifest: `2675` bytes, SHA-256
  `903ebd2de8ae471479e1c133abaf618fe205d75d7109d69d09a1d24b61840d99`.
- trusted signing and public publication: `NOT_REQUESTED`.

The exact bundled DLL also passed the 100-cycle local runtime gate. Packaged
TUN traffic, elevation, sleep/resume, and clean-machine installation remain
manual exact-candidate checks.

## Current 1.2.0 Safe Claims

Safe to claim from current local evidence:

- Windows source uses an authenticated service bridge and service-owned Core
  runtime instead of an elevated Flutter process;
- source/build tests enforce fixed runtime paths, bounded profiles, atomic
  staging, ABI 2 negotiation, sanitized failures and fail-closed authenticated
  egress proof;
- local packaging requires the service and emits no portable ZIP;
- installer syntax and unsigned local package generation pass;
- no 1.2.0 service installation, clean-VM runtime, signing, publication or
  release claim follows from those checks.

Not safe to claim:

- SCM install/upgrade/uninstall or owner-SID behavior passes on a clean host;
- Windows TUN traffic, DNS/leak, selected-app routing, crash/reboot recovery or
  teardown passes for an exact 1.2.0 candidate;
- the generated local installer is production-signed or publishable;
- the current source is a promoted 1.2.0 Windows candidate.

## Retained 1.1.x Safe Claims (Superseded)

The following wording belonged to the retained outside-store lane and is not
current 1.2.0 authority.

Safe to claim for the retained candidate at its recorded time:

- the Windows host shell uses the real desktop FFI runtime lane
- the Windows connect path fetches a live managed profile, materializes route mode and optional WARP in Dart, secures the staged file, and starts POKROV Core through desktop ABI 2
- the local release build bundles the pinned POKROV DLL and `libcronet.dll` into the Windows runner output
- the Windows seed lane has a reproducible unsigned package step with a manifest, portable ZIP, and first-layer setup EXE for gated beta inspection
- the current `v1.0.3-beta.2` unsigned setup EXE and portable ZIP are uploaded
  to the public GitHub prerelease for outside-store beta access
- the current Windows source materializes `Full tunnel`, `All except RU`,
  selected-process routing, and client-local WARP into raw config before the
  POKROV Core start call. `VPN/TUN + system` remains the default; advanced
  settings expose `mixed`, `gvisor`, and a loopback-only Core-owned system proxy
  that is restored on stop
- current source fail-closes when the selected outbound works through the local
  proxy but the ordinary Windows TUN/DNS path does not; this is source evidence,
  not proof for the still-public `1.1.3` artifact
- this source-level change does not prove elevation, route capture, DNS/leak
  behavior, or teardown on the published or any future exact candidate
- this Windows lane now lives in the canonical `POKROV-app` repo
- this Windows lane is the current repo-backed outside-store beta release truth
  for Windows, but not a trusted-signed, store, or broad stable distribution
  lane
- unsigned Windows builds may be used for gated beta only with explicit SmartScreen or unknown-publisher warning guidance

Not safe to claim now:

- the Windows executable is production signed
- a trusted-signed production installer or `MSIX` publication flow is ready
- Microsoft Store, WinGet, or SmartScreen reputation is approved
- the Windows lane is approved for broad public distribution
- this lane is trusted-signed, store, or stable release truth for Windows
- this repo alone authorizes a later candidate without its own current handoff
  and evidence

## External Blockers

- exact clean-VM SCM install, owner-SID, upgrade, uninstall and repair evidence
- exact-candidate service crash/reboot and uninstall-while-connected recovery,
  including live route/DNS restoration
- exact-candidate TUN, DNS/leak, route modes, UI-crash persistence and teardown
- trusted Windows code-signing material is not wired into this lane
- trusted installer signing and `MSIX` publication are still not wired into this lane
- anonymous public artifact hosting is closed through `Kiwunaka/pokrov`;
  stronger updater policy remains distribution scope, not a repo-side blocker
  for the current outside-store beta
- outside-store Windows beta distribution is no longer blocked on unsigned
  posture: the owner accepted unsigned beta risk and the setup EXE is uploaded.
  Stronger broad/trusted distribution remains blocked on signing, live
  exact-artifact runtime route-mode smoke, and DNS/leak validation
- platform publishing policy remains outside this client readiness document

## Blocked Runtime Verification

The current outside-store beta handoff remains valid for its recorded
candidate. Before reusing that result for a later candidate or making stronger
trusted/stable claims, attach:

- exact-artifact install, restart, session restore, secure-storage, and
  selected-app process-routing smoke: `MANUAL_OWNER_TEST`.
- POKROV Core ABI/export/hash probe is locally complete; clean-profile traffic,
  Naive/libcronet loading, Windows version compatibility, and user-only ACL
  behavior inside the packaged exact candidate remain `MANUAL_OWNER_TEST`.
- The rebuilt exact DLL completed 100 serial raw start/stop cycles locally.
  This is `PASS` for the narrow DLL shutdown backtest only; sleep/resume,
  interface changes, service recovery, real WARP, Naive/Cronet, and packaged
  TUN behavior remain `MANUAL_OWNER_TEST`.
- `Only selected apps` picker, persistence, route-policy echo, and generated
  `process_name` / `process_path` behavior.
- `Full tunnel` route-mode smoke.
- `All except RU` route-mode smoke.
- DNS split behavior and leak checks.
- Connect, reconnect, disconnect, and recovery after failure.
- Close while connected -> hidden tray state -> reopen without losing the
  service-owned running session; then tray `Выход`, UI crash, service restart
  and uninstall -> deterministic Core/TUN/route/DNS recovery:
  `MANUAL_OWNER_TEST` for the exact candidate.
- current-origin, brain-origin, and RU-origin checks where runtime reachability matters.

## Release Rule

Historical stable-direct uploads remain evidence only. Current source is newer
and cannot reuse any 1.1.x release identity. Do not promote 1.2.0 until the
exact machine-wide setup candidate passes service install/upgrade/uninstall,
Hiddify-off full-tunnel browser/DNS and leak checks, reconnect, UI-crash
persistence, service recovery and teardown. Portable ZIP is not an eligible
candidate. Trusted/store claims remain blocked on signing, SmartScreen
reputation and the target channel's publishing requirements.
