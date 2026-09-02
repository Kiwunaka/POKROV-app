# Platform Privilege And Runtime Contract

Last updated: 2026-09-01

This document owns the client-side trust, privilege and lifecycle boundaries
for Windows, Android and the conditional Linux beta lane. It defines intended
architecture. Release readiness still depends on current code, tests and exact
candidate evidence in the platform-specific operation documents.

## Universal invariants

- UI state is unprivileged and cannot become network authority by relaunching
  the whole application with wider rights.
- Each host has one runtime session owner and one writer for Core, TUN, routes,
  DNS, proxy and kill-switch state.
- A host reports verified protection only after current DNS and selected
  outbound egress proof. Process start, interface creation and route mutation
  are intermediate states.
- Commands crossing a trust boundary are versioned, length-bounded, schema
  validated and allowlisted. A raw shell command, arbitrary privileged path or
  caller-provided executable is never part of the protocol.
- Unknown protocol, capability or saved-state versions fail closed before
  privileged mutation.
- Session and generation identifiers fence late callbacks. Stop and rollback
  are idempotent.
- Credentials, raw profiles, private keys, provider payloads and browsing
  history do not cross into logs, fixtures or evidence.
- Signing, service installation, store access, physical-device and clean-host
  proof are operator/candidate gates; source tests cannot replace them.

## Windows trust domains

The target has three processes or authorities:

```text
ordinary user session
  pokrov_windows.exe
    UI, tray, account, settings, support, typed status presentation
          |
          | authenticated local protocol
          v
Windows service control plane
  pokrov_service.exe
    Core, Wintun, routes, DNS, proxy, kill switch, recovery transaction

installer / repair authority
  installs, upgrades, rolls back or removes the service and package
```

The ordinary UI never runs continuously as administrator. UAC is limited to
installer or explicit service-repair work. The service is a separate SCM
singleton and does not depend on how many UI sessions are open.

### Per-user activation channel

UI activation is not service IPC and grants no privileged capability. The
current source contract is:

- mutex namespace: `Local\\POKROV.UI.<session-id>`;
- frame magic: `PKRA` as little-endian `0x41524B50`;
- frame version: `1`;
- fixed header: 16 bytes;
- maximum payload: 512 bytes;
- commands: `show` and `acquisition_continue`;
- `show` has no payload;
- acquisition payload is printable ASCII and must start with
  `pokrov://acquisition/continue?`;
- future versions, unknown commands, non-zero reserved fields, wrong lengths,
  trailing bytes and control characters are rejected.

The first process owns the mutex for its lifetime. Any later ordinary or
acquisition launch sends one typed frame to that process and exits. Both paths
restore/focus the same UI. Session-local isolation prevents one interactive
Windows session from becoming another session's singleton. The channel still
is not security evidence for the future privileged service protocol.

### Startup contract

The per-user Run value is the exact quoted executable plus `--startup`.
Startup mode:

- installs the normal tray and keeps the Flutter window hidden;
- does not request UAC;
- yields to an explicit acquisition continuation, which must open the UI;
- becomes eligible for service-owned auto-connect only after a later contract
  proves service compatibility/readiness, restored configuration and network
  availability.

The 1.2.0 source has no `--connect`, process-token elevation check or `runas`
continuation. Failure or incompatibility of the service blocks connection; it
never falls back to an elevated Flutter UI.

### Privileged service protocol

The service transport is a local named pipe with:

- ACL limited to LocalSystem, Administrators and the installation owner's SID;
- server-side caller token/SID verification;
- protocol version and capability negotiation before commands;
- bounded request/response/event frames;
- correlation ID, deadline, cancellation and operation nonce;
- replay resistance for connect, update and recovery mutations;
- closed commands for status, initialize, stage/invalidate profile, connect,
  disconnect, cancel, recover and a sanitized diagnostic state;
- server-side authorization per command.

The protocol contains no arbitrary command execution, URL fetch, caller-owned
privileged output path or raw secret-bearing log request. Unknown or
unauthorized input fails before Core or network mutation.

The current WO-005B1/005B2/005C source implements:

- separate `pokrov_service.exe` identity with SCM start/stop/shutdown wiring;
- production pipe `\\.\pipe\POKROV.Service.v1` and installed-owner SID read
  from protected HKLM service configuration;
- a protected DACL for LocalSystem, Administrators and the installation owner;
- caller-token impersonation and exact SID/administrator validation after the
  bounded, non-mutating hello frame and before any request;
- protocol v1 capability negotiation, random session token, correlation ID,
  operation nonce, five-minute maximum deadline and a session-bounded replay
  set that fails closed instead of evicting old nonces;
- allowlisted status, initialization, profile staging/invalidation, connect,
  disconnect, cancel, recover and sanitized-state command identifiers;
- UI-side server authentication by exact pipe-server PID bound to the running
  `POKROVService` SCM record, its LocalSystem start account and the sibling
  installed `pokrov_service.exe` path. This query is available to the ordinary
  user UI and does not require reading the protected LocalSystem process token;
- bounded UI-side pipe acquisition. A genuinely absent service pipe fails
  immediately. After observing an existing but busy pipe, the client retries
  both another waiter's `CreateFileW` race and the short gap while the serial
  service replaces its pipe instance, for at most five seconds;
- a persistent service runtime owner that loads only the sibling
  `pokrov-core.dll`, negotiates desktop ABI 2 and the optional exact capability
  descriptor, and owns Core setup/start/stop after the UI disconnects;
- fixed `%ProgramData%\POKROV\ServiceRuntime` storage protected for System and
  Administrators through a protected inheritable DACL, with bounded profile
  bytes written through `managed-profile.pending` and atomically promoted to
  `managed-profile.json`;
- a Windows-only `POKROV_PROFILE_BUNDLE_V1` handoff for materialized local
  binary rule sets. The unelevated client reads the user-owned `.srs` inputs,
  replaces their profile paths with service-relative slot paths and sends at
  most eight assets, 128 KiB each and 160 KiB total, inside the existing
  256 KiB IPC frame. The service accepts only canonical sequential names and
  base64, requires one slot marker per asset, writes the exact bytes into
  protected `working\data\rule-set\profile-{a,b}` generations, secures every
  file and binds the staged profile to the newly completed generation. The
  privileged service never opens a caller-selected source path;
- service-side selected-outbound proof over WinHTTP with proxy bypass. A green
  runtime requires HTTPS `204` plus the exact
  `X-Pokrov-Egress-Probe: pokrov-authenticated-egress-v1` marker. Failure stops
  Core, returns to `config_staged`, and emits only
  `core_egress_probe_failed`;
- a strict status snapshot where `running`, `core_egress_validated` and
  `dns_ready` converge. Unknown phases, failures or inconsistent booleans fail
  closed in the UI client.

Privileged evidence stays separate from the user-space
`pokrov-runtime-events.jsonl` journal. The service owns
`service-events.v1.log` plus one `service-events.v1.previous.log` under the
protected runtime root. Each file is limited to 256 KiB; producers enqueue at
most 4096 closed records without doing file I/O on SCM or IPC threads. A single
writer preserves order, flushes each record and rotates with write-through
replacement. The `POKROV_SERVICE_EVENT_V1` wire contains only timestamp,
sequence, closed event/outcome/command/status values and an opaque correlation
or boot-epoch identifier. It has no free-form error, request body, profile,
session token, operation nonce, endpoint, URL, path or network destination.

The closed source events cover SCM start/run/stop/shutdown/preshutdown,
suspend/resume and a boot-epoch marker; authenticated IPC request/response
spans; and network snapshot, Core/Wintun, adapter, route, DNS, egress, commit
and rollback stages. They are a local producer seam only. Unified support
envelopes, export/upload, remote ingest, retention and alerts belong to the
observability work order.

Debug builds expose a one-client isolated handshake mode used by native tests.
Release builds do not expose that entrypoint. The service and UI client are
copied into the local release bundle and the Inno source installs a machine-wide
SCM service. This is source/build/package-syntax evidence only: no current
1.2.0 service installation, clean-VM runtime, signing or exact-candidate proof
exists.

The production pipe loop isolates client-session failure from service
availability. A caller that disconnects before `hello`, fails caller
authorization or sends an invalid frame is rejected and recorded without
terminating the SCM service or discarding the owned runtime. Only the SCM stop
event ends the production loop. Debug tests retain a bounded client limit so a
rejected first session followed by a valid session is exercised without
exposing a release entrypoint. A separate native concurrency test opens 32
clients against one serial pipe instance and requires every bounded retry to
reach the server.

### Windows network transaction target

The service owns an atomic recovery journal and these stages:

```text
clean
snapshotted
core_started
network_applied
verified
committed
rolling_back
recovered
```

The Windows source implements this as `POKROV_RECOVERY_V1` with a bounded,
hex-encoded `POKROV_NETWORK_V1` snapshot. Core uses one exact Windows TUN
interface name, `POKROV`. Before Core starts, the service snapshots that
interface's GUID, IPv4/IPv6 interface fields, unicast addresses, routes and DNS
settings and writes the journal through an atomic pending-file replacement.
Rollback first persists `rolling_back`, then stops Core, restores only that
owned interface and only then advances through `recovered` to `clean`.

The 1.2 service lane does not mutate WinINET proxy state. Core's strict-route
firewall policy uses a dynamic WFP session, so it is released with the service
process and has no persistent firewall identifier to restore. The journal does
not duplicate unchanged global proxy or firewall state.

Failure, service restart or reboot resumes the same idempotent rollback. Before
the Windows service accepts its first IPC client, it checks the durable journal
and eagerly initializes Core only when pending recovery exists. A clean journal
preserves lazy Core initialization. A failed Core stop or network restore leaves
the initialized runtime in `recovery_required`, disables a new connect and
permits a repeated disconnect/recovery attempt. A corrupted, partial or future
journal is preserved and fails closed; it is not silently erased while
POKROV-owned network state may remain.

The boot marker is derived from system FILETIME minus Windows uptime, so a
service restart in the same OS boot retains the same opaque boot correlation;
a later boot changes it. This is source-level correlation, not retained proof
that an exact candidate survived a real reboot.

## Android trust and lifecycle boundary

Android `VpnService` remains the platform authority. Flutter supplies typed
intent and presentation; it does not own the established TUN descriptor.

One active session owns a generation and bounded child work for network
monitoring, probes, latency, updates and stats. Stop cancels the entire session
scope. Late callbacks must match the active generation. Fire-and-forget raw
threads are not an accepted lifecycle primitive. The VPN service owns a bounded
session scope for the Core status stream and selected-egress probe; the Android
host bridge owns a separate Activity/Flutter-engine scope for latency, variant,
installed-app and verified-update jobs. Service destruction, runtime
replacement and Flutter-engine cleanup cancel their respective parent scopes.

The foreground notification and its public lockscreen version use
`VISIBILITY_PRIVATE` and a generic protection state. Country, route, selected
applications, endpoint and speed are available only inside the authenticated
app. Release 1.2.0 has no system-surface preference that can opt those details
back into the notification; retained legacy `true` values are rewritten to the
privacy-safe all-false state.
When selected-egress validation is required, the notification remains in the
connecting state until Core confirms DNS, transport and outbound reachability.
An explicit failed validation renders the generic failure state; it must never
publish the connected state merely because Android established the TUN.
Traffic speed comes from the Core `CommandStatus` TUN totals and is converted
with monotonic time into session rates. The bridge exposes explicit
`unavailable`, `warming`, `available`, `reset` and `overflow` counter states;
counter decrease never becomes a speed spike, and a stopped or superseded
session clears its totals and rates. When the capability is unavailable, the
UI shows unavailable data; it does not substitute whole-UID traffic.

Managed-profile MTU accepts only an integer in `1280..1500`; missing,
malformed and out-of-range input uses `1280`. Immediately before TUN creation,
the Android host applies the same bounds and caps the requested value to the
active platform interface MTU when that ceiling is at least `1280`. `9000` is
not a fallback. Any later adaptive/PMTU tuning must preserve a known-safe
rollback and record only bounded diagnostics.

Direct and store builds share the intentional package/signing lineage but have
different update authority:

- direct: install-packages permission, canonical signed APK updater;
- store: no install-packages permission or provider/direct-installer path;
  explicit Google Play handoff and store-managed update only.

Before direct installer handoff, the completed APK must match canonical
origin/channel, monotonic version, exact size/SHA-256, expected package ID,
authorized signing-certificate lineage, minimum SDK and device ABI. Cached
artifacts repeat the identity checks. Failure disables the update; it never
relaxes signer/package validation.

The current source realizes this as Gradle `direct`/`store` flavors. Direct
verifies the installed signer and the target's platform-reported current signer
and certificate history, requiring an authorized signer plus continuity with
the installed identity. The verified file is atomically promoted only after
identity validation, and opening it repeats the whole validation before any
permission, settings or installer intent. Store has no network/APK/cache path
and targets `com.android.vending` explicitly. This source/build proof is not a
production-signer, Play-console or exact-candidate device pass.

## Conditional Linux beta boundary

Linux is not a public client surface. A beta requires a recorded distro,
desktop, init, network-manager, policy and package matrix first.

The target uses a non-root Flutter UI and a systemd-owned privileged daemon.
IPC uses authenticated peer identity plus an explicit authorization policy,
with D-Bus/polkit preferred unless a documented Unix peer-credential design
provides the same boundary. NetworkManager is the primary integration for its
declared matrix; resolved, networkd and nft behavior is explicit and
fail-closed for IPv4/IPv6.

The daemon's network transaction observability contract is closed before live
mutation is enabled. Each event names exactly one `network_manager`, `resolved`
or `nftables` subsystem and one `checkpoint`, `apply` or `rollback` stage. The
only results are pass, unavailable or stage-specific rejection. The envelope
contains a bounded transaction ID, request correlation ID, generation and an
allowlisted error code; it has no command, argument, path, interface, address,
resolver, rule, destination or raw error field. A current `connect` attempt
records `checkpoint/unavailable` for all three required owners and then returns
`linux_live_connect_unavailable`. It does not manufacture apply/rollback success
before those operations exist.

The source also contains a dormant system transaction implementation behind
that event seam. It accepts only an internal typed plan: a daemon-owned
`pokrov*` tunnel interface, one non-zero Core routing mark and one to four
validated IP resolver addresses. None of those values can arrive as a raw
command or shell fragment through IPC. The transaction order is fixed:

1. create a NetworkManager D-Bus checkpoint covering all devices, with a
   bounded automatic rollback timeout and new-device/connection plus internal
   DNS tracking;
2. verify the owned resolved link and absence of the dedicated
   `inet pokrov` nftables table;
3. apply per-link DNS, `~.` routing and default-route ownership through
   `resolvectl`;
4. validate and atomically apply only the generated `inet pokrov` output table,
   allowing loopback, the owned tunnel, the Core routing mark and required
   DHCP/IPv6 link control while dropping other output;
5. destroy the NetworkManager checkpoint only after the other participants
   have applied successfully.

Checkpoint and apply failures trigger reverse rollback. Every dirty owner is
attempted even when an earlier rollback fails, and only failed owners remain
eligible for an explicit recovery retry. Resolved rollback uses per-link
`revert`; nftables rollback deletes only `inet pokrov` and never flushes or
restores a global ruleset; NetworkManager rollback uses only the bounded object
path returned by its checkpoint call. Native commands are fixed absolute
paths, run without a shell, have per-call deadlines and bounded stdout, and
discard stderr. The host probe now requires the system-bus client used by this
implementation.

This engine is source-only and deliberately not wired into `connect`: the
current Core does not yet provide the exact Linux tunnel/mark/DNS lifecycle
plan, and there is no durable restart/suspend recovery or clean Ubuntu 24.04
runtime proof. Therefore no command in this implementation runs in the current
product path and the unavailable preflight behavior above remains authoritative.

Every mutating request also emits one closed authorization decision before any
profile or network write. The backend is exactly `peer_credential` for the
root service peer or `polkit_dbus` for the non-root `pkcheck` path. The latter
is the documented wrapper over polkit's system-bus authorization interface.
Exit results are reduced to allowlisted pass/denied/unavailable/reject outcomes
and fixed error codes for denial, absent authentication agent, dismissed
prompt, timeout, unavailable authority or invalid subject. PID, UID, process
tuple, action details, stdout/stderr and raw D-Bus errors have no event field.
The caller still receives one generic fail-closed authorization error.

The socket uses separate budgets: twelve seconds to receive the bounded request
frame, up to sixty seconds for the interactive polkit decision, then five
seconds to write the bounded response. An expired input deadline is never
reused for the response, so a completed authorization cannot mutate state and
then silently lose its result solely because the prompt outlived the frame
read window.

A compiling Core or UI, an unsigned package, or an AppImage containing only UI
does not prove VPN beta support. Public facts remain unchanged until the exact
signed package passes install, upgrade, rollback, uninstall, non-root,
authorization, suspend/recovery and route/DNS restoration checks on every
named matrix entry.

## Observability boundary

Platform components emit only closed lifecycle identifiers, correlation and
session/generation identifiers, bounded stage/result enums and sanitized
status. Windows service/UI logs are separate; Android release logs stay
app-private; Linux daemon events use journald with safe fields.

The Windows UI and service also install `POKROV_WINDOWS_CRASH_V1`. The filter
unwinds only the faulting thread and retains at most 32 RVAs from fixed
allowlisted POKROV, Flutter, Core and app modules. It stores one current and one
previous record under separate per-user and protected service roots. Unknown
modules are omitted. Symbols, module paths, absolute addresses, registers,
exception text, command lines, profiles, network material, heap and full memory
dumps are not captured. This local source contract does not replace a
controlled exact-candidate crash/recovery test.

The Android host writes `android-operational-v1.jsonl` plus one previous file
under its app-private no-backup directory. Each file is capped at 256 KiB and
the writer uses a bounded single-consumer queue. The schema accepts only UTC
time, local sequence, a positive optional generation, dropped-record count and
closed event/outcome enums. VPN lifecycle/permissions, default-network
callbacks, Doze, app-standby/background restriction, a rate-limited stack-free
main-thread watchdog and direct-updater identity/handoff are producers. Raw
Core text, exception messages, URLs, profiles, credentials, network identity
and stacks have no field in this journal.

Release builds keep arbitrary Core debug callbacks disabled. The only native
diagnostic allowed through that callback is the bounded AWG handshake contract:
Core reconstructs `awg_safe_diag` from a closed category plus occurrence
`1..4`, and Android independently requires the exact canonical form before
placing that same category/count in the in-memory runtime snapshot. The value
is visible only in the dedicated diagnostics evidence list, survives no process
restart and clears at the next connection attempt. Prefixes, suffixes, unknown
categories and upstream formatting arguments are dropped; the lane never
carries endpoints, peer material, keys or raw messages and does not change
runtime health by itself.

The common envelope, error catalog, planted-secret gate, encrypted diagnostic
bundle, ingest, support console, retention and alerts are separate
observability owners. Platform work must not create a competing pipeline.

## Rollout state

As of 2026-09-03:

- Windows per-session singleton, typed UI activation and tray-only startup are
  locally proved under WO-005A;
- the Windows service identity, authenticated protocol, UI client, Core
  lifecycle owner, fixed profile storage, service-side authenticated egress
  proof and machine-wide installer source are locally implemented under
  WO-005B1/005B2;
- the Windows factory routes production Windows calls through
  `RuntimeLane.windowsService`; full-process elevation and the per-user system
  proxy compatibility path are absent. A legacy persisted `systemProxy` value
  migrates to the service/TUN lane;
- local proof consists of native Debug build, eight CTests, Flutter tests,
  static analysis, release bundle validation and unsigned Inno syntax/package
  generation;
- WO-005C source now has a durable versioned journal, exact `POKROV` adapter
  snapshot/restore backend, recovery-only fail-closed phase and injected faults
  for every persisted connect stage, Core-stop failure, network-restore
  failure, journal-completion failure, repeated disconnect, restart, partial
  journal and future journal;
- exact candidate.18 clean-VM installation and installed-file identity are
  proved, but its ordinary UI fails the LocalSystem process-token query and
  stops the service. Candidate.19 proves the SCM-bound correction, ordinary
  UI authentication and entitlement, then fails Core start with `CORE-005`
  because its managed profile still points at local rule-set files under the
  user's AppData while Core resolves them from the service working directory.
  Candidate.19 is immutable `NO_GO`. Exact candidate.20 setup
  `330b87cb…587f` proves the bounded service-owned rule-set bundle on an
  isolated Windows 11 VM: four service-relative assets, ordinary UI to
  LocalSystem service, default connect, TUN, DNS, authenticated egress,
  disconnect restoration, clean uninstall and public-1.1.6 migration. A later
  connected reboot restores the baseline and reconnects, but a forced service
  termination leaves the durable journal at `committed` after SCM restarts the
  service. Candidate.20 is therefore immutable `NO_GO`. Successor source now
  invokes pending recovery before the first IPC client and keeps a failed
  startup recovery retryable; exact successor VM proof is still required;
- exact candidate.23 build `4052` installs as `11/11` and initially reaches its
  authenticated connected state, but a subsequent UI request can report
  `CORE-001` while the SCM service remains running. Thirty-two simultaneous
  trusted status clients reproduce the single-instance pipe race with `0/32`
  accepted requests. The bounded client retry passes `32/32` against that same
  installed service and the native concurrency test, but is pre-candidate
  source evidence only. Candidate.23 is immutable `NO_GO`;
- Android notification privacy and safe MTU policy are locally proved by
  Android JVM/source-contract tests plus managed-profile and widget tests;
  physical OEM/lockscreen and exact-candidate behavior remain unproved;
- Android Core/TUN counters and session-scoped concurrency are locally proved
  by Android JVM tests, host source contracts, runtime-engine tests, the full
  app-shell suite and static analysis. Actual process death/restart, long-run
  traffic sampling and physical-device behavior remain unproved;
- Android direct/store flavor separation and updater identity enforcement are
  locally proved; production signer, Play-console and exact-device upgrade
  evidence remain candidate/manual gates;
- Android private release journaling and its lifecycle, permission, network,
  power/standby, watchdog and direct-updater producers are locally proved by
  both flavor JVM suites. Exact-device file permissions, lifecycle delivery,
  ANR behavior and long-run rotation remain candidate/device gates;
- Linux remains conditional and absent from public scope. The source now has a
  non-root Flutter host, a systemd socket-activated Go daemon, kernel peer
  credentials, polkit authorization for every mutation, bounded typed IPC,
  fixed private profile storage, a fail-closed Ubuntu 24.04 foundation matrix
  and allowlisted native journald fields. The polkit D-Bus wrapper now exposes
  one closed authorization decision for each mutation without peer identity or
  diagnostic text. A typed NetworkManager/resolved/nft transaction-event seam
  plus exact unavailable-preflight wiring exposes checkpoint/apply/rollback
  compatibility reasons without raw details. A dormant typed transaction
  engine now implements the fixed D-Bus checkpoint, per-link resolved change,
  dedicated atomic nft table and reverse recovery order with injected source
  faults; it is not connected to the product path and has no native runtime
  evidence.
  `connect` intentionally returns
  `linux_live_connect_unavailable` and `supports_live_connect=false` until the
  Core lifecycle supplies the exact internal network plan, the transaction is
  durably integrated, and suspend recovery plus exact signed package/VM
  matrices are implemented and retained.

These statements describe source progress, not a 1.2.0 candidate or release.
