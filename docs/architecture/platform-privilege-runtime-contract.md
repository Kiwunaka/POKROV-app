# Platform Privilege And Runtime Contract

Last updated: 2026-09-01

This document owns the client-side trust, privilege and lifecycle boundaries
for Windows, Android and the conditional Linux beta lane. It defines intended
architecture. Release readiness still depends on current code, tests and exact
candidate evidence in the platform-specific operation documents.

## Smart Access capability negotiation (local source, NOT_VERIFIED)

`RuntimeSnapshot.smartAccessLeaseVersion` is 0 unless the initialized host
recognizes version 1 from its loaded Core. Android reads the additive gomobile
getter and requires the exact lease-revocation method. Windows matches the owned
descriptor and requires `pokrovCoreRevokeSmartAccessLease`; it transports the
version through the installed service's negotiated snapshot extension (bit 8).
An older peer receives its previous snapshot shape. The Dart descriptor parser
accepts only 0/1 and requires catalog-window version 1 for Smart Access version 1.

This reports engine API availability only. It does not authorize a provider,
activate a grant or establish service health. The platform's signed grant path
is now connected to profile assembly under the existing coordinator for the
bounded web/current-origin subset described in the bootstrap workflow.
Smart Access stage first persists restriction identities against the final host
request digest. Android checks `expectedProfileDigest` before the private config
write; Windows checks it against the complete IPC body before queueing stage.
No new IPC command, privilege or connection owner is added. Storage failure
prevents native staging, and a late or superseded callback cannot send stage.
The returned digest must match before the client accepts the stage. Ordinary
profile staging and WARP rewrites cannot bypass this path for leased profiles;
WARP fallback prepares a fresh profile through the existing coordinator.
`runtimeEngine.revokeSmartAccessLease` carries exactly a 64-character profile
digest, 32-character lease ID and boolean `terminateActive`. Android serializes
it on the existing service executor and fences both invocation and reply by
service owner, runtime session, command generation and committed profile digest.
Windows command 10 requires negotiated bit 8 and existing authenticated IPC;
its body is exactly `digest:lease:0|1` (99 ASCII bytes), with the existing short
3-second control deadline. The service requires the matching running profile
and invokes Core under its existing execution lock. No new lifecycle phase,
disconnect, route owner or privilege is introduced. Core absence/host rejection
does not become a successful revocation acknowledgement.

`runtimeEngine.revokeRoutingCatalog` carries only the 64-hex running profile
digest. `routingCatalogControlVersion` is separately negotiated: Android requires
the getter and exact gomobile method; Windows matches the descriptor and requires
`pokrovCoreRevokeRoutingCatalog`. Windows command 11 uses capability bit 9,
existing authenticated IPC, the same serial runtime owner and the 3-second control
deadline. Older peers omit the additional snapshot field; lifetime support alone
does not advertise control. The response binds schema/profile/boolean result.
Absent windows or an unavailable Core never become a positive acknowledgement.
This command closes catalog rule admission and relay flows without replacing the
TUN; already routed non-lease connections and admitted DNS exchanges are unchanged.

Control version 2 additionally requires `revokeSmartAccessPolicy(boolean)` on
Android and `pokrovCoreRevokeSmartAccessPolicy(int)` on Windows. Its host method
`runtimeEngine.revokeSmartAccessPolicy` accepts exactly `profileDigest` and
`terminateActive`; its reply binds schema, profile, action and boolean result.
Windows command 12 requires negotiated capability bit 10 and an exact 66-byte
`digest:0|1` body, under the existing authenticated session and 3-second deadline.
Peers without bit 10 see at most control version 1. The loaded export is required
before version 2 is reported. Android reuses the existing service executor and
profile/session/generation fences. Both hosts invalidate matching profile reuse
after a positive Core result. Ordinary catalog rules are unchanged by this call.

Control version 3 requires `revokeRoutingCatalogService(String)` on Android and
`pokrovCoreRevokeRoutingCatalogService(const char*)` on Windows. The host method
accepts exactly `profileDigest` and `serviceId`, returning schema/profile/service/
boolean result. Windows command 13 requires negotiated bit 11; its body is
`digest:service_id` (66–129 ASCII bytes), with a 64-hex digest and the catalog's
1–64 character service-ID grammar. It uses the same authenticated session,
serial runtime owner and short control deadline. Older peers see only their
supported control version. Android keeps the existing owner/session/generation/
committed-profile fences. Positive results invalidate matching native reuse.
No routes, lease credentials or new policy bytes enter this restriction command.

Control version 4 adds `renewSmartAccessLease` / `pokrovCoreRenewSmartAccessLease`.
Android checks the actual loaded method and runs it through the existing service
executor with owner/session/generation/committed-profile fences. It commits
matching saved-profile invalidation before calling Core; a failed commit cannot
enable renewal. Windows command 14 requires bit 12 and a fixed 193-byte ASCII
body: profile digest, old/new 32-hex lease IDs and three exact UTC timestamps,
separated by `|`. It retains authenticated IPC, the runtime execution lock and
short control deadline. Older peers see at most their negotiated control version.
Both hosts preserve the running instance and assets while removing matching
stage reuse. The Windows snapshot still recognizes that exact running digest
when staged reuse is absent; this does not authorize reconnect without a stage.

Flutter requests contain exactly six fields and replies exactly schema/profile/
old-ID/new-ID/renewed. Core validates generation and time limits; the app verifies
signed grant scope and persists old/new restriction identities before dispatch.
This command changes only lease identity/dates, never relay, resolver, domains,
quotas or routes. A missing/rejected/unconfirmed result is not acknowledgement.

A positive Core revoke also withdraws native reuse of that exact profile:
Android commits removal of the matching persisted profile and clears its staged
pointer; Windows clears the matching stage acknowledgement. Live phase, active
digest and bundled assets are retained for the safety policy's draining flows.
Different staged profiles are preserved. Android returns unconfirmed on a failed
persistence commit; subsequent delivery retries the commit even if preferences
are already empty in memory. Native executor work does not depend on a live
Flutter callback, but this does not fetch new remote decisions with the UI closed.

The shell now delivers fresh signed provider-policy decisions for leases whose
stage acknowledgement matches the running native digest. Foreground/account
refresh uses the existing coordinator generation and a shared bounded budget.
The restriction-only binding and received decisions now persist through the
existing secure-storage mechanism, restoring only against the matching running
digest. It never supplies a grant to the assembler or persists a Core success
acknowledgement. The signed request-bound control endpoint now carries account
and whole-policy/catalog disable decisions. Signed catalog/access denial now
also withdraws ordinary timed catalog rules for the exact profile. The same
secure inventory persists the catalog digest, original lifetime and latched kill;
new catalog windows require control pins and native control version 4. It supplies
restrictions only; no grant or host privilege follows from it. An unavailable or
corrupt inventory does not block fresh signed catalog/access denial: foreground
refresh uses the running native digest and existing exact-profile command, with
no reconstructed grant or lifetime. Its memory-only restriction survives metadata
recovery; catalog disable suspends cache reuse before attempting persistence.
Signed provider-only disable and issuance-only drain also reach the current Core
without readable lease identities through the version-2 command. The coordinator
retains the strongest received action until acknowledgement; termination dominates
drain. Background fetching and durable recovery after storage failure remain open.
The feature remains default-off; retained AAR/DLL identities are
unchanged. Tests, formatting, builds and runtime acceptance are deferred to the
owner-requested separate verification phase.

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

The current local R12 source requires negotiated `ProfileIdentity` (bit 5) and
`Cancellation` (bit 6) capabilities on both UI and service. Frame version stays 1; a mixed old/new
bundle fails capability negotiation and requires matching UI/service installation.
`connect` carries exactly one lowercase 64-hex SHA-256 of the acknowledged stage
request. The digest covers the flag line, materialized JSON and embedded ruleset
bytes. It identifies local content, not a server assignment revision.

The service changes `staged_profile_digest` only after the atomic stage commits.
It sets `effective_profile_digest` only after Core start, egress proof and recovery
transaction commit, and clears effective identity on stop/failure. A connect with
a different digest fails before network mutation. Failed staging retains the
previous staged identity. Service restart clears in-memory identity and requires
restaging; durable last-known-good restoration remains a separate N02 gate.

The bounded status response includes both digests. The native parser rejects
malformed identity, a running effective/staged mismatch and partial healthy data.
The UI keeps its expected stage digest across polling; another session's staged
profile cannot silently become this session's protected connection. Relaunch
without a local intent may show the actual service-owned running profile, but a
new connect still requires an acknowledged stage. Flutter receives only bounded
digests and the fixed origin `windows_service_stage_request_sha256`; raw profile,
ruleset, endpoint and credential data never enter this projection.

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
  service replaces a pipe instance, for at most five seconds. The service now
  admits at most eight authenticated sessions while keeping one runtime owner;
- a three-second monotonic budget for each IPC frame transfer, shared by its
  header and body. Partial frames, idle sessions and unread replies cannot
  monopolize a session slot indefinitely. An incompatible hello gets a
  bounded opportunity to consume its rejection; no follow-up request is run.
  Session teardown never calls an unbounded pipe flush;
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

POST12 source work (NOT_VERIFIED) adds optional IPC capability bit 7 for the
`routing_catalog_window_version` snapshot extension. The bit declares protocol
support only. The field is 1 only after the service initializes a Core with the
exact owned catalog-window descriptor; an old Core or uninitialized service
reports 0. Old peers receive the original snapshot body, and new clients accept
an old service's body as version 0. Unknown extension values fail parsing.
Busy/cancelled responses preserve the extension without changing their existing
failure/protection semantics. The Flutter host bridge exposes this value through
the common runtime snapshot; no UI process loads a second Windows Core to infer
the service's capabilities. Pinned artifacts and installed-service proof remain
unchanged. See [catalog lifetime](bootstrap-workflow.md#native-catalog-lifetime-and-host-negotiation-not_verified)
for the rule contract and remaining apply work.

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

Debug builds expose bounded isolated handshake modes used by native tests.
Release builds do not expose that entrypoint. The service and UI client are
copied into the local release bundle and the Inno source installs a machine-wide
SCM service. Debug IPC fixtures use no installed runtime root or recovery
backend, so the protocol tests cannot open the host's recovery journal. Bounded
local installed-service evidence is linked from
[Windows readiness](../operations/windows-release-readiness.md); it does not
establish final-candidate signing or the complete managed-network matrix.

The UI accepts `WM_QUERYENDSESSION` without exiting and tears down through its
normal native destruction path only on a confirmed `WM_ENDSESSION`. A canceled
session end keeps the UI alive. Restart Manager can therefore release the UI
files during an update without the ordinary close-to-tray preference preventing
shutdown. The service keeps its separate SCM lifecycle. The installer removes
the exact obsolete `pokrov_activation_protocol_test.exe` left by earlier bundles;
this is not a wildcard cleanup of the installation directory.

The production pipe loop isolates client-session failure from service
availability. A caller that disconnects before `hello`, fails caller
authorization or sends an invalid frame is rejected and recorded without
terminating the SCM service or discarding the owned runtime. Only the SCM stop
event ends the production loop. Debug tests retain a bounded client limit so a
rejected first session followed by a valid session is exercised without
exposing a release entrypoint. A separate native concurrency test opens 32
clients against one serial pipe instance and requires every bounded retry to
reach the server.

Connect also checks its admitted deadline and the SCM stop signal before
mutation and between snapshot, Core start, egress verification and journal
commit. The wall-clock deadline is converted once to a monotonic deadline.
A signal observed after mutation rolls back through the existing journal on
the same runtime owner before returning; it cannot publish effective profile
identity or protection. A rollback failure takes precedence and remains
`recovery_required`. Successful rollback preserves the staged profile. The
native UI parser accepts `deadline_exceeded` and `operation_cancelled` as closed
failure categories; matched UI/service source must be packaged together.

Status and cancellation can be served during Connect. A concurrent mutation
returns `runtime_busy`; it is not queued inside the privileged service. Cached
`connecting`/`busy` snapshots expose no protection or effective identity and
do not permit another connect. RuntimeHost itself is touched by only one
dispatcher execution, including rollback.

A cancel request carries exactly 64 lowercase hexadecimal characters encoding
the target connection's session token and operation nonce. It still has its own
authenticated session, correlation, deadline and fresh replay-protected nonce.
Only the active token/nonce pair can be cancelled. `cancellation_requested`
acknowledges the request; the original Connect response proves its outcome.
The dispatcher also rolls back a cancellation accepted after the final runtime
check but before completion is published. Active identity is cleared under the
cancellation lock; stale cancellation cannot reach a later connection. Target
tokens and nonces never enter the event journal.

The UI runs service calls on one bounded worker queue and completes method
results on the window thread. A replacement connect, stage, invalidation or
disconnect requests cancellation of the preceding connection before its queued
mutation runs. A separate authenticated IPC exchange sends that cancellation.
Client frame I/O is overlapped and bounded (three-second hello/write frames,
33-second normal response budget); window destruction abandons pending reads
after requesting cancellation. This does not assert that the remote runtime
has already stopped.

Windows lost-response handling now has source changes (NOT_VERIFIED). A queued
connect whose control is already cancelled/abandoned exits before opening IPC.
Once its authenticated request exists, an uncertain frame write, missing frame
response, mismatched response identity, malformed runtime snapshot or accepted
response for a different effective profile requests cancellation of that exact
session-token/nonce pair over a fresh authenticated exchange. Semantic rejection
retains the target only inside the current client invocation; it never exposes
it in a runtime snapshot. Rejected frame identity also clears compatibility.
The companion
cancellation thread observes cancellation before lost-response completion and
makes a final bounded attempt; it does not silently stop waiting first. Failed
cancellation remains an unknown remote outcome, never a successful disconnect.
No target token is logged and an unscoped Disconnect is not substituted. The
service may already have completed the original request before semantic
rejection; `operation_not_active` does not prove teardown or authorize stopping
a newer connection. The original parsing/profile failure remains the result.

The shared shell now preserves the Windows host-owned runtime-call deadline as
it already does for Linux. Its shorter generic Flutter timeout cannot abandon a
normal Windows connect while the native owner still waits for its bounded
response/rollback. This does not remove native IPC budgets, change profile API
timeouts or prove bounded blocking Core calls. Worker queue/destruction and
lost-frame/cancel races still require the separate verification stage.

The egress request uses asynchronous WinHTTP, retains callback state until
`HANDLE_CLOSING`, and closes the pending request on interruption. Retry waits
also check interruption. HTTPS, proxy bypass and the required proof marker are
unchanged. The loopback HTTP factory exists only in Debug test builds. See
[WinHTTP cancellation and callback lifetime](https://learn.microsoft.com/en-us/windows/win32/api/winhttp/nf-winhttp-winhttpclosehandle).

Blocking Core Start/Stop and recovery calls still must return before the
cooperative signal can be observed; bounded in-call Core cancellation and
rollback duration remain unproven. The `recover` and `diagnostic-state` command
identifiers still return `runtime_not_owned`; automatic startup recovery is
separate. Local IPC/worker tests do not close installed WFP coexistence, Win10
or the final package's connected-network acceptance.

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

While the Windows UI process is alive, including when hidden in the tray,
it samples the local service status every two seconds with at most one such
request in flight. This does not fetch profiles or run network probes. A
service stop/restart or unavailable observer clears the previous UI/tray
protection claim. Poll results that cross a runtime action or replace an older
snapshot are discarded; polling stops when the shell is disposed. The existing
bounded Android post-connect diagnostics remain separate.
Equal status values do not rebuild the shell or notify tray listeners. The
comparison includes diagnostics and profile revision/identity values, so a
health or source change within the same runtime phase still reaches the UI.

Runtime diagnostics retain the fetched, staged and effective upstream revision
and protocol family separately from local content digests. The shell sends only
these bounded fields, proof stage and optional observation time in the existing
authenticated runtime-stats request. Local paths, profile contents and digests
are omitted. Reports use a random per-bootstrap run ID and monotonic sequence;
they do not establish server traffic proof, access or onboarding completion.
The observation time is the first locally observed transition into full healthy
proof. Ordinary polling never renews it; unhealthy state or changed effective
content clears it. Attaching to an already healthy service leaves the time
unknown. Protocol data missing from an older cache is reported as unknown.

If restart or a final journal-write failure leaves the transaction at
`recovered`, retry clears the saved network snapshot in the atomic `clean`
commit. A failed write retains the `recovered` checkpoint and its snapshot for
another retry. The completed journal must reload as `clean` before a later
transaction starts. Native tests cover this interrupted completion using a
synthetic network backend and a locked journal; installed-package reboot and
last-known-good profile restoration remain separate proof obligations.

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

The daemon's transaction event envelope remains closed: one `network_manager`,
`resolved`, `routes` or `nftables` subsystem, one `checkpoint`, `apply` or `rollback`
stage, a bounded transaction/correlation ID, generation and an allowlisted
result/error code. No commands, paths, network material or raw errors enter it.

The live path starts only the fixed root-owned executable
`/usr/lib/pokrov/pokrov-core`, with no caller-supplied process arguments. Core
reads the private staged profile, validates the privileged profile boundary and
engine schema, then emits a bounded `pokrov-linux-core-v1` plan over inherited
FD 3. That plan is restricted to TUN `pokrov0`, mark `0x504b` and its fixed DNS
gateway addresses. Core creates the nonpersistent TUN and assigns its fixed
addresses before its system stack binds listeners. Its private Linux context
disables sing-tun route/rule mutation, including implicit IPv6 rules. This
switch is not a profile JSON option. The daemon owns route table and priority
20555, protocol 243 and metric 42700; pre-existing ownership rejects connect
before mutation. Cleanup matches exact objects and never deletes a priority range.

The transaction order is fixed:

1. persist the private recovery record and reject occupied route ownership;
2. require absence of `inet pokrov`, validate and atomically install only that
   output filter. It allows loopback, the owned tunnel, Core's mark and required
   DHCP/IPv6 link control, dropping other output;
3. start the prepared Core, record its TUN index and apply the owned IPv4/IPv6
   policy routes under a persisted write-ahead intent;
4. create a 90-second NetworkManager checkpoint for that exact TUN only, with
   no flags that delete other connections or restore global DNS;
5. apply per-link resolved DNS, `~.` and default-route settings;
6. commit the NM checkpoint after the other participants have applied.

Disconnect and failed apply restore resolved and any pending NM checkpoint
while TUN exists. They remove exact owned routes, then wait for Core's explicit stop acknowledgement
before releasing the nft table. Failure retains the pending owner and traffic
filter for retry. Existing foreign rules are neither
flushed nor restored from a whole-host snapshot. Native commands use fixed
absolute paths, typed arguments, bounded output and deadlines, without a shell.

The root-only mode-0600 `/var/lib/pokrov/network-recovery.json` records schema,
boot identity, transaction/generation, a random nft ownership comment, link
index, pending subsystems and the NM checkpoint's unique D-Bus owner. It has
no profile, provider or credential fields. Atomic replacement includes file
and directory sync; invalid or unsupported records are retained and fail closed.
Daemon startup and unexpected Core exit resume cleanup. On startup, only the
specific live-TUN refusal permits a bounded five-second wait for the prior
Core's parent-death signal and one retry once `pokrov0` disappears. Recovery
still refuses a live or replaced TUN, checks the nft ownership comment and preserves changed or
ambiguous route objects. Missing TUN implies removal of its per-link resolved
state. After a new boot with no owned nft table, recovery retires the old record
without modifying current-boot routes. NM object paths are used only while
their recorded unique D-Bus owner still exists. A failed stage retains the record
and prevents profile replacement until authorized cleanup succeeds.

The systemd service uses `KillMode=mixed`: linuxd receives the initial stop
signal and orders Core teardown itself. The unit sets `StateDirectoryMode=0700`
to keep the private state root restricted after socket activation and restart,
matching the package installer. The socket unit owns `/run/pokrov` and
the socket path; daemon listener close does not unlink it. The UI's 130-second
response budget covers authorization, connect, failed-connect restoration and
the host probe.

The Linux UI uses the existing desktop service-status poll every two seconds.
It reads local IPC only, allows one outstanding observation, preserves a newer
explicit UI action and updates the UI when the daemon stops or recovers outside
that UI action. It does not infer healthy DNS/egress from a running daemon.
This fixes the observed package-7 GUI retaining its Disconnect/checking state
after the daemon had stopped and removed TUN. [Installed package-8 proof](../operations/evidence/2026-09-11-r12-l04-ui-status/README.md)
shows the same non-root GUI changing to Retry/error after external Core SIGKILL,
without app interaction or restart; all seven network baselines were restored.

The installed `pokrov-linux-sleep.service` is required before `sleep.target`.
It stops both socket and daemon before sleep and starts the daemon on resume,
so any retained journal is recovered before IPC resumes. Exact suspend/reboot
acceptance remains a host evidence gate.

Current source advertises live connect on the supported stack with an executable
Core. A staged profile and absence of an active transaction or pending recovery also gate
`can_connect`. Running means actual Core/network startup. After the network
transaction, linuxd requests bounded DNS and selected-proxy HTTPS proof from
its private Core child. Both must pass for the connected/healthy message;
missing or failed proof remains unhealthy. Results belong to that running
session and clear on stop or error; they are connection-establishment proof,
not continuous reachability monitoring. The Linux compiler
accepts the fixed TUN and loopback mixed profile shape, rejects file/namespace/
interface/mark control and auxiliary services, and does not yet accept AWG
endpoint profiles.

[L02 runtime evidence](../operations/evidence/2026-09-11-r12-l02-linux-runtime/README.md)
proves non-root IPC, real TUN/DNS/TLS HTTP, disconnect restoration, foreign-rule
rejection and active service stop/reactivation on an isolated Ubuntu 24.04
amd64 guest. Authentication success used a temporary guest-only polkit fixture
grant, subsequently removed; production-policy denial was separately verified.
This is not Flutter GUI, desktop-agent or signed-package proof.
[L03 recovery evidence](../operations/evidence/2026-09-11-r12-l03-linux-recovery/README.md)
adds dual-stack traffic, Core/daemon crash recovery, preserved foreign rules,
partial rollback retry, actual suspend/resume and connected reboot. Real
`pkttyagent` verifies missing-agent/timeout behavior using a scoped `AUTH_SELF`
fixture condition, with no credentials entered; production-policy denial is
verified after fixture removal. [L04 package-7 desktop evidence](../operations/evidence/2026-09-11-r12-l04-linux-desktop/README.md)
adds non-root GUI authentication with the production polkit action, native
permissions, connected upgrade, rollback and connected uninstall/purge.
All seven captured host network baselines match after upgrade and uninstall;
profile, settings and keyring bytes are retained. RU/full route observations
pass, but intermittent full-mode TLS failures remain unresolved. Current
package crash/suspend/reboot, foreign-rule preservation and partial rollback
retry now pass on the same installed guest, with all seven original network
hashes and profile bytes restored. Recovery fixtures use root peer credentials
without an API refresh; actual GUI/polkit proof remains separate. Overall
acceptance remains open.

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

For a runtime-ready Linux profile, full-device mode normalizes the VPN selector
and route rules before staging: inherited RU/direct exceptions are removed
except private-address routing. DNS uses the VPN resolver lane while retaining
transport-domain bootstrap and private-address resolution. The all-except-RU
mode keeps its managed RU rules; Windows process routing stays Windows-only.
Both Linux modes resolve proxy hostnames through the materialized `dns-direct`
resolver with `ipv4_only`, as Windows already does. Inheriting the API's local
bootstrap resolver would send node resolution back into systemd-resolved after
its traffic has moved into TUN, creating a dependency on the unestablished VPN.
Content DNS retains its configured VPN/direct routing policy.

The Linux UI retains the transport's bounded 130-second wait for authorization,
connect and cleanup instead of applying the shared 18-second runtime deadline.
Profile API requests keep their existing deadline. Before staging, the Linux
adapter uses the shared Core config materializer to remove API-only `_meta`
and unused cache-file settings, with WARP disabled for this beta. Core still
validates the complete privileged profile boundary before network mutation.

For an IPv4-only plan, the owned IPv6 default is an unreachable route. Recovery
matches its native `ip -N` representation (`type: 7`, `dev: lo`) together with
the fixed table, protocol and metric; a different device remains a conflict.

A compiling Core or UI, an unsigned package, or an AppImage containing only UI
does not prove VPN beta support. Public facts remain unchanged until the exact
signed package passes install, upgrade, rollback, uninstall, non-root,
authorization, suspend/recovery and route/DNS restoration checks on every
named matrix entry.

## Observability boundary

Support bundle `build.build_id` and `build/identity.json` carry the same actual
build number used by the support-mode audience and operational events. The
candidate label is not the build number. Android diagnostics use Flutter's
build flavor: `direct` for production APKs and `store` for store AABs. This is
separate from the operational release channel (`alpha`, `beta`, `rc`, `stable`,
or `local`); distribution flavors must not be passed as `POKROV_RELEASE_CHANNEL`.

Platform components emit only closed lifecycle identifiers, correlation and
session/generation identifiers, bounded stage/result enums and sanitized
status. Windows service/UI logs are separate; Android release logs stay
app-private; Linux daemon events use journald with safe fields.

Flutter and isolate error handlers retain the closed crash marker without
forwarding the original exception or stack to previous/default handlers. The
isolate callback reports the error handled so the VM does not print raw values.

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
- Linux remains conditional and absent from public scope. The non-root Flutter
  host uses authenticated typed IPC to the polkit-gated systemd service. The
  private Core child now supplies and executes the validated TUN/mark/DNS plan;
  the daemon applies its dedicated nft table and per-link NM/resolved changes.
  Isolated Ubuntu 24.04 VM evidence covers traffic, restoration, foreign-rule
  preservation and service stop/reactivation. Health fields remain unknown;
  durable crash/suspend/reboot recovery and real-agent authorization negatives
  now have bounded L03 VM proof. L04 proves real GUI authentication and the
  signed package's install/upgrade/rollback/uninstall lifecycle. Intermittent
  full-mode TLS failures remain open; the same installed package now also has
  crash/suspend/native reboot recovery proof.
  See the conditional Linux section above.

These statements describe source progress, not a 1.2.0 candidate or release.

### Reconnect and repair cancellation ownership

Local POST12 source (`NOT_VERIFIED`): the existing shell coordinator extends
connect cancellation to reconnect/recover. The shared native-call wrapper binds
only the fresh ID dispatched by the owned action. Each logical pipeline keeps a
completion until its body settles, including a pre-connect disconnect. Cancellation
invalidates continuation, never reverses an already-started restoration operation.
Existing Android, Windows and Linux exact-invocation mechanisms below apply only
after a fresh connect ID exists; no unscoped cancel target is substituted.

Repair's sheet callback captures its coordinator generation and is removed when
that cycle finishes. Stale callbacks cannot cancel another operation. The sheet
stays busy through readback and labels supersession as interrupted. It does not
start new diagnostics from an interrupted repair or infer teardown from a
cancel acknowledgment. Normal post-repair diagnostic reads remain separate.
Unknown/pending/running stop state blocks a replacement stage/connect, and failed
cleanup remains owned by its original host. These source changes require later
shell/native race and restoration checks; no host capability or privilege changed.

### Linux primary connect cancellation

Local POST12 source only (`NOT_VERIFIED`), limited to the conditional Linux beta
lane. `LinuxDaemonRuntimeEngine` gives each connect a fresh random request ID and
an in-memory cancellation completer. Only the matching active ID signals it;
completion clears the mapping. Returned snapshots retain a weak local ID
association, not native proof. The shell exposes primary `Отменить`, advances
its generation and joins the old pipeline before reading daemon state.

The existing `pokrov-linuxd-v1` newline JSON request/response envelope gains an
optional connect-only stream trailer: one byte `0x03` after the request newline.
It cancels only the connect on that authenticated Unix socket. No global cancel
command, persisted ID, new listener or privilege is introduced. Any other
trailing input or EOF aborts that in-flight request too. Other actions retain
their one-request behavior. The client cancels its owned socket connection task
before dispatch; after dispatch it sends the trailer and keeps waiting for the
original response under the existing transport deadline. A late socket is
destroyed. The daemon drains its one-byte monitor before writing the response,
so no monitor can affect a later invocation.

The service still holds its existing mutex across runtime mutation and rollback.
Request cancellation reaches polkit's bounded process, is checked after
authorization/lock acquisition, and parents Core's existing 30-second prepare/
start and separate 20-second health contexts. Peer identity and polkit authority
remain required. A cancelled polkit process uses the existing dismissed/denied
authorization result; it does not grant access. Core pipe-read cancellation
sets that read's deadline and joins its callback before a subsequent read.
This prevents a delayed callback from interrupting cleanup.

Transaction failure retains the existing independent 30-second restoration
budget. Cancellation after transaction success also restores only that newly
created transaction with the existing stop owner. Dirty rollback state remains
retained and is reported as pending; no successful stopped state is inferred.
`linux_operation_cancelled` / `operation_cancelled` is a bounded failure result,
not teardown evidence. The shell reads the current daemon state and keeps a
warning for running, unavailable or recovery-pending state. Cancellation after
the final ownership check may lose to completion and cannot stop an established
session or a different invocation. An older daemon may ignore the trailer;
no cancellation guarantee is inferred from a normal connect reply.

Socket/process races, authorization outcomes, independent rollback, exact host
restoration and mixed-version behavior await the separate verification phase.
No Linux binary was built, installed or published by this source change.

### Windows primary connect cancellation

Local POST12 source only (`NOT_VERIFIED`): Windows
`MobileArtifactRuntimeEngine.connect()` sends a fresh 128-bit random ID as the
sole `requestId` argument. The runner requires 32 lowercase hexadecimal characters
and binds the ID to the accepted queue item's `ServiceCallControl`. Failed queue
submission leaves the previous mapping intact. Replacement connect/stage/
invalidate/disconnect invalidates that mapping; window teardown clears it.

`runtimeEngine.cancelConnectRequest` accepts the same exact argument shape and
returns `{schema: 1, requestId, cancelled}`. The window thread sets the matched,
unfinished invocation's flag without queuing behind connect. A worker marks the
invocation completed before delivering its result; completed or mismatched IDs
return `cancelled: false`. This flag acknowledgment does not prove delivery to
the privileged service or tunnel teardown. The native service client keeps the
existing private session-token/nonce target and authenticated cancellation IPC;
neither value crosses the method channel. No service wire/ABI change is added.

Primary cancellation keeps the original native timeout and waits for that
invocation and its logical shell pipeline before reading host state. The service
may have committed connect before cancellation arrives, including after local
flag acceptance. Running or connecting/busy remains unconfirmed, as does an
unavailable host. The UI does not substitute an unscoped Disconnect or allow a
new primary attempt while the cancellation action owns the pipeline. Preparation
cancellation before native dispatch only cancels owned preparation work.

Queued/active/completed races, stale IDs, failed IPC/readback, window teardown
and applicable Windows/Flutter checks remain deferred to the verification phase.
The Android ownership mechanism below retains its separate service semantics.

### Android stage/start identity

The Flutter-to-host connect cancellation path now has source implementation
(NOT_VERIFIED). Each Android `MobileArtifactRuntimeEngine.connect()` creates a
fresh 128-bit random request ID, carried through the local method channel,
permission token and service START intent. `AndroidConnectRequestOwner` keeps
the current ID, cancellation flag and optional identity-bound Core/profile
digests in process memory. Both permission
resume and not-yet-committed startup reject a cancelled/replaced request. Normal
user STOP and permission revoke invalidate the current request as well.

`runtimeEngine.cancelConnectRequest` accepts only that exact request ID. Its
schema-1 reply echoes the ID and says whether cancellation was accepted by the
current owner; it is not a TUN teardown acknowledgment. A service STOP carrying
the cancellation ID rechecks both the accepted START and current cancellation
owner, so a delayed cancellation cannot consume a replacement's pending state
or stop its session. A cancelled START delivered later is rejected. Quick
Settings and OS starts retain their host-owned path without a Flutter ID.

The shell captures the ID started by a runtime action, and the runtime engine
associates each returned connect snapshot with that invocation in a weak local
map. This association is not native proof. Timeout/supersession cancels the
captured ID, never whatever request happens to be current later. Android settle
uses the existing 180/10 × 450 ms budgets as wall-clock limits, including snapshot
waits; exhausting a still-pending attempt is an error. Cancellation dispatch has
a separate three-second acknowledgment cap. Missing/malformed/failed replies
become `connect_cancel_unconfirmed`, without an unscoped disconnect fallback.
Native teardown timing, process-death/device races and older-host handling still
require the separate verification stage. This path does not add backend fields,
network telemetry, persisted request IDs or release-support claims.

Startup cancellation source work (NOT_VERIFIED) now binds each queued start to
the existing monotonic service-command generation. START/STOP/revoke invalidate
that generation's child scope before the serial owner performs teardown. A
superseded queued start exits; a start interrupted during preparation closes
its own resources without publishing a failure for a newer command. A staging
invalidation also cancels a not-yet-committed start through its staged digest.
After a TUN has committed, editing the next profile retains the existing live
tunnel until an explicit start/stop, as before.

Each Core command server receives handlers capturing its own runtime session
for TUN creation, reload, stop, debug messages and network-monitor registration.
Old callbacks cannot adopt the replacement's current session. TUN publication
checks command/session ownership and the initial staged identity after
`Builder.establish()`; a superseded descriptor is closed without publishing
running state or route counts. Publication shares the command/state monitors
with command acceptance and staging. Quick Settings completion for the owning
start is attached before the Core call, so synchronous TUN callbacks see it.

`AndroidStartupEndpointProbe` moves endpoint preparation to the bounded session
worker and applies the existing five-second per-hop budget to queueing, DNS and
TCP together. The serial service owner can leave on cancellation/timeout. On
API 29+, cancellation also signals `DnsResolver`; sockets are closed on every
terminal path. Before API 29 the OS DNS call may outlive interruption, but its
late answer cannot open a socket or commit a result. No raw endpoint/error is
logged by this helper. This does not prove physical-device timing or interrupt
every blocking libbox operation; native lifecycle tests and exact candidate
acceptance remain in the separate verification stage.

POST12 host scope work (NOT_VERIFIED) rejects a profile that supplies both
non-empty include and exclude package lists; neither list silently wins.
Connection ownership preserves the observed UID but supplies a package name
only when the OS resolves that UID to exactly one distinct visible package.
The OS can associate several packages with one UID; see
[PackageManager.getPackagesForUid](https://developer.android.com/reference/android/content/pm/PackageManager#getPackagesForUid(int)).
An ambiguous shared UID therefore cannot match a package-specific Core route
or DNS rule by arbitrary package ordering. Other rule conditions and the
explicit mode default still apply; this does not establish signer identity or
authorize automatic catalog app exceptions. Focused host checks are deferred
to the separate verification stage.
The existing `AndroidTunPackagePlannerTest` case that expects an include list
to override an exclude list describes the superseded behavior and must be
updated in that stage; it is not current acceptance evidence.

POST12 local discovery source work adds `runtimeEngine.catalogAppIdentities` to
the existing activity bridge. A bounded worker reads at most 256 explicitly
requested visible packages; certificate data crosses only the local method
channel. The lifecycle-bound receiver invalidates its single memory cache on
package changes. This method cannot alter Builder include/exclude lists, stage
a profile or start a service. The existing app-selection preview consumes
matched outcomes and requires explicit user confirmation plus a fresh scan.
Native automatic app authorization remains open. The VPN service now invalidates
its bound catalog app scope on package changes or signed expiry, closes its TUN
and stops the runtime; this source-only path has no device or regression PASS. The matching and
visibility rules are owned by [bootstrap workflow](bootstrap-workflow.md#post12-android-catalog-app-discovery-not_verified).

The bridge persists and acknowledges SHA-256 over exact staged content,
route mode and the egress requirement. Service intents, including deferred
notification/VPN consent and Quick Settings, carry the captured digest. Service
start compares saved metadata and actual content before touching a live session,
and uses the verified immutable string for Core. A replaced file at the same
path cannot inherit the previous start intent. Deferred consent ownership also
compares digests, so completion of an old request cannot release a newer one.

`stagedProfileDigest` names the staged input; `effectiveProfileDigest` is emitted
only for a running, egress-validated active input. Staging a different digest
invalidates previous proof; an old proof cannot validate the replacement. Stop
and failure clear active proof. The fixed origin is
`android_private_stage_request_sha256`; these digests are not server revisions.
Quick Settings requires a supported record with a valid digest. Old records
without one require an app refresh. Local JVM tests do not prove packaged Core,
Android filesystem crash durability, routing coverage or physical-device behavior.

Android system-started always-on commands reuse that same persisted profile only
after its route scope has been confirmed and its digest is valid. They enter the
ordinary foreground start path, which checks the saved metadata against the
actual config before creating a TUN. A missing or unconfirmed profile fails closed;
an already running or pending connection is not restarted by a duplicate system
start. System lockdown remains Android-owned and can block apps outside the
selected-app allowlist, including while the selected tunnel is connected.


The temporary support-mode consent sheet uses the available screen height and
scrolls its disclosure and actions when needed. Both consent choices remain
reachable on compact Android screens; enabling the mode still requires the
explicit confirmation after the signed policy has been redeemed.

### Smart Access background restriction command (source only, NOT_VERIFIED)

The additive `runtimeEngine.configureSmartAccessRuntimeControl` method accepts
exactly `profileDigest` and `configJson`, returning exactly schema 1,
`profileDigest`, and boolean `configured`. The sensitive JSON is bounded to
16384 UTF-8 bytes and never written as a profile or diagnostic artifact. Only
the authenticated Flutter/native owner may provision it. Core receives local
public verification pins and a restriction-only delegation, not a full account
access token or refresh token. The worker cannot issue or renew a lease.

Android negotiates `SmartAccessRuntimeControlVersion() == 1` and the two-string
gomobile method from the loaded AAR. It checks the JSON profile/platform binding,
then uses the existing runtime executor, owner/session/generation/committed
profile fences and synchronous reusable-profile invalidation before dispatch.
Windows negotiates service bit 13 / command 15 and Core descriptor field
`smart_access_runtime_control_version: 1` with the corresponding two-string
export. Its request body is `profileDigest + | + configJson`, at most 16449
bytes, through the existing authenticated IPC and execution lock. Core checks
the embedded profile binding. Only `configured=0` or `configured=1` acknowledges
the service call. Events contain a fixed command name, never its body.

Old IPC peers do not receive the new snapshot suffix. The Windows snapshot
parser permits a running exact effective profile with no reusable staged digest;
it still requires a staged digest before reconnect. Core ties worker lifetime
to the captured instance and rejects late delivery after replacement or stop.
Signed restrictions latch; connection errors and later `none` responses cannot
clear them. Native profile reuse is invalidated before enabling background
delivery. Client-store handback is connected below. Positive-authority recovery,
artifact/device/runtime verification and background grant renewal runtime proof
remain open.

The same source capability now requires native restriction-journal read and
acknowledgement methods/exports. `runtimeEngine.readSmartAccessRestrictions`
accepts no arguments and returns schema 1 plus bounded `journalJson`.
`runtimeEngine.acknowledgeSmartAccessRestrictions` accepts only `snapshotSha256`
and replies with schema 1, the exact hash and boolean `acknowledged`. These are
private state-transfer operations, not diagnostic exports. Android invokes the
loaded static libbox functions on its existing host task scope. Windows commands
16/17 use the same authenticated capability bit 13 and service execution lock;
they work after initialization with no running profile. The service releases the
Core-owned returned C string through `freeString`. Journal responses allow 1 MiB
for bounded lease identity handback; extended runtime snapshots allow 1024 bytes, while other control replies
retain the 512-byte bound. Events contain only fixed command names.

The client durably merges every returned restriction/uncertain marker into its
separate secure ledger and every lease identity into the original bound inventory
before acknowledging. Core refuses stale snapshot hashes
and never deletes a live worker's record. The consumer permits one reread after
a changed snapshot; failed retention or a superseded operation cannot dispatch
ACK. Catalog/Smart Access stage requires this read/retain/ACK sequence and no
live worker, preventing Android staging from racing a background receipt.
Retained profile and catalog restrictions gate stage and renewal. Foreground
recovery has a bounded share of the action budget so storage failure leaves time
for signed foreground control. Snapshot entries include the original runtime
authority expiry captured and updated by Core before authority changes; this
allows bounded retention after client metadata loss. No credential lifetime is
substituted. Records without any recoverable bound remain open; foreground
renewal recovery is connected below. This source path has no crash/device validation.

`runtimeEngine.readSmartAccessLeases` accepts exactly `profileDigest` and returns
schema 1, that profile and `leaseIdsJson`. The JSON string now holds a schema-1
object: `lease_ids` (at most 256 unique lowercase 32-hex IDs) and `selections`
(at most 256 strict service rows), within a 65536-byte response. Core enumerates only
current outbound generations. Android uses the existing runtime executor and
owner/session/generation/committed-profile fences before read and reply, without
invalidating reuse for this read. Windows command 18 uses existing capability bit
13, three-second IPC deadline and serial service owner; it requires the exact
running effective profile. Only this command permits the larger lease reply.
Events contain its fixed name, never IDs or JSON. Runtime control version 1 is
available only when the loaded Core exposes this method/export too.

The read supplies identity, not grant authority. A subsequent renewal requires
fresh signed control/policy/grant data and the saved scope fingerprint, persists
both identities, and still compares old/current lease ID in Core before mutation.
This permits foreground renewal after UI restart without storing a full grant.

Restriction snapshots now have ten fields per entry, including up to 256
23-field lease identities and 256 `scope_actions` entries. Android, Dart and Windows command 16 all enforce the
1 MiB response bound. The Windows frame ceiling accommodates that response;
profile requests retain their 256 KiB bound, lease/selection responses 64 KiB and
ordinary control replies 512 bytes. Recovery reads current IDs before pruning
expired metadata, retains native candidates without treating them as grants,
preserves kills and updates the active coordinator before ACK. A changed native
snapshot still requires reread; failed/missing/corrupt client binding cannot
acknowledge live identities. Native background production/application is now
connected in source: it records both identities and checks freshness before
adopting a signed next generation. Signed negative responses tighten the exact
outbound (including older active generations) and retain its scope action. The
client consumes scope actions before ACK without blocking unrelated scope renewals.
Foreground enrollment now follows successful worker setup and fresh authority,
with at most one mint per refresh for an exact current verified lease. This path
has not been built or tested.

`runtimeEngine.configureSmartAccessRenewal` accepts exactly `profileDigest` and
`configJson`, with the same 16384-byte command bound and schema-1/profile/boolean
`configured` acknowledgement as restriction-worker setup. Its JSON schema is
`pokrov-smart-access-runtime-renewal-worker-v1`; it contains profile digest,
opaque renewal capability, issuance/expiry and the 23-field lease identity.
The command is never saved or included in events. Android checks the nested lease
platform and uses the existing executor/session/generation/committed-profile
fence, invalidating saved reuse before dispatch. Windows command 19 requires
capability bit 13, uses the three-second authenticated serial service path and
invalidates matching staged reuse. Runtime control version 1 now also requires
the loaded `configureSmartAccessRenewal` method / `pokrovCoreConfigureSmartAccessRenewal`
export. Core requires a live matching restriction worker and current lease;
enrollment cannot itself extend dates or clear revocation. Production artifacts
and observed background-renewal evidence have not been produced by this source change.

## Suspend-inclusive transport clock (ATS-005, source only)

`RuntimeBootClock.readBootClock` returns closed schema 1: `boot_ref`, nonnegative
safe-integer `elapsed_ms`, and `quantum_ms: 1`. Boot references are local metadata,
never diagnostic/telemetry/API identifiers. Unsupported hosts fail closed.

- Android's existing method channel adds `runtimeEngine.clockSnapshot`, using
  `SystemClock.elapsedRealtime()` and `Settings.Global.BOOT_COUNT`. Missing or
  inaccessible boot count returns `runtime_clock_unavailable`; no permission
  prompt, wall-clock fallback or synthetic boot identity is introduced.
- Linux adds `clock_snapshot` to the existing authenticated Unix-socket protocol.
  It reads `/proc/sys/kernel/random/boot_id` and `CLOCK_BOOTTIME` via the standard
  syscall ABI. It does not probe network/runtime or acquire polkit permission.
  The reply's `clock` object is separate from tunnel health/snapshot.
- Windows adds authenticated service command 20 and capability bit 14. The
  Flutter method queues that command and returns its bounded local JSON. The
  service uses `QueryInterruptTimePrecise`; absence fails closed. A protected
  SYSTEM/Administrators-only volatile registry key at
  `HKLM\SOFTWARE\space.pokrov\POKROV\Service\TransportClock` contains random
  `BootRef`. It is created on the first clock request, survives app/service
  restarts and sleep, and is discarded by the OS at reboot. Lost/missing marker
  gets a new identity and therefore cannot revive an old anchor; corrupt values
  fail closed. No calendar-time-derived boot epoch is reused for this purpose.
- iOS and macOS share `packages/runtime_engine/apple/TransportBootClock.swift`,
  compiled into each Runner target. It reads `kern.bootsessionuuid` and
  `mach_continuous_time`, converts ticks with `mach_timebase_info` using bounded
  full-width integer arithmetic and emits `ios:<uuid>` / `macos:<uuid>`.
  iOS uses the existing runtime channel; macOS registers only the clock method
  on that channel while its runtime remains on the desktop FFI path. The helper
  runs in the host app, does not start Core or a tunnel, and does not cache a
  synthetic identity. Denied/unavailable sysctl or malformed timebase fails with
  `runtime_clock_unavailable`; no wall-clock or process-uptime fallback exists.

The Windows metadata helper does not acquire the tunnel execution lock or mutate
route/Core state. Existing trusted peer, nonce, deadline and capability checks
still apply. Old hosts lacking capability 14 are rejected before command 20.
This source adds no package or protocol compatibility claim. Apple host clocks
are implemented in source only; transport policy remains disabled by default.
Sandbox/API availability, privacy review and exact signed-host proof are still
Apple readiness gates, not established by the shared helper.

Boot rollover, suspend/hibernate, app/service restart, marker permissions/lifetime,
clock correction, counter discontinuity, frame parity and host error behavior
remain NOT_VERIFIED. Full VM/kernel/storage rollback is not proven by these APIs.

## Loaded Core transport inventory (source only)

`RuntimeSnapshot.transportCapabilities` is an optional immutable typed inventory
of compiled Core ingredients. Android reads the loaded gomobile
`Libbox.transportCapabilities` through reflection after successful setup. The
desktop FFI binding reads optional `pokrovCoreTransportCapabilities` from the
same loaded library as start/stop and releases its bounded string with
`freeString`. Windows service reads that export after setup, retains its ASCII
JSON in memory and passes it through the existing authenticated snapshot as
`transport_capabilities` (`none` when unavailable). The Runner forwards it as
`transportCapabilitiesJson`; Android uses the same field.

No source/build flag or filename supplies a fallback inventory for an older
artifact. At the Dart boundary only schema 1, canonical compact JSON, unique
lexically sorted known feature IDs, and a 4096-byte ASCII representation are
accepted. Unknown, malformed, missing or oversized answers produce no inventory.
Snapshots outside initialized/config-staged/running phases also omit it. Snapshot
state equality includes the canonical inventory; this never changes protection
health or a connection proof. Ordinary runtime compatibility is unchanged.

The Windows snapshot bound increases from 1024 to 8192 bytes to carry the bounded
inventory beside existing fields; request/control/profile limits are unchanged.
Native metadata rejects semicolons and nonprintable/non-ASCII characters before
the delimited frame; Dart owns closed JSON/feature validation. New clients accept
older snapshots without the trailing field. A new service and Runner must ship
together: older strict snapshot parsers cannot consume the added field. No new
command, peer permission or TUN owner is introduced.

Core's ABI contract owns feature meanings: native sing-box TLS/VLESS/XHTTP,
build-gated uTLS/Reality, Hysteria2 and the bounded AWG 3.1 endpoint subset. These
are ingredients, not an arbitrary-profile compatibility claim. Opaque signed
capability refs/revisions, exact loaded-artifact digest, profile requirements,
IP-family and host readiness remain separate resolver obligations.

Linux `initialize` obtains preflight inventory from the fixed root-owned
`/usr/lib/pokrov/pokrov-core --transport-capabilities` command, with a three-second
deadline, bounded output and discarded stderr. It sends no profile or user
argument. Memory-only reuse requires the same regular root-owned executable,
inode, size, mtime and mode; this is a replacement fence, not a content hash or
rollback proof. It is never substituted for a running child's inventory. The
normal Core child includes its own `transport_capabilities_json` in `prepared`;
linuxd uses that answer while the child exists, clearing availability when it
exits. The bounded child reader grows to 16 KiB for escaped JSON; the daemon
snapshot remains within its existing 64 KiB response limit. The Dart Linux
snapshot uses the same closed decoder. Older Core metadata mode/export absence
stays unknown. A new Core and linuxd must ship together because old child
decoders reject the additive field. No extra daemon action or TUN is introduced.

iOS shares `CoreTransportInventory.swift` between Runner and PacketTunnelExtension.
It calls the generated `LibboxTransportCapabilities()` binding directly and
bounds printable ASCII to 4096 bytes. The pinned gomobile build emits static
archives (`c-archive`), so each target links its own Core implementation. A
direct reference retains the getter and lets the generated Objective-C/Swift
declaration govern return ownership; no optional dlsym cast is used. Building
these sources requires matching Core headers/archive with that getter. An old
archive is a build incompatibility, not a runtime feature fallback.
After Runner setup the local answer is available only for preflight. Running
snapshots use a read-only lookup of the one matching configured provider and
the existing `sendProviderMessage` channel; no manager is created/saved and no
VPN is started by this lookup. The exact `transport_capabilities` message returns
only inventory while the extension's Core service is running. Runner requires
a connected session, enforces a three-second completion limit and fences the
reply against intervening initialize/stage/connect/disconnect/WARP operations.
Timeout, error, invalid inventory, stopped session or an old extension's unrelated
status reply cannot fall back to the Runner's inventory. Preflight and running
answers still need independent artifact/profile/operation identity binding.

The Xcode project links the static XCFramework in both targets and does not copy
it into Runner's Embed Frameworks phase. The Runner runtime locator names
`Bundle.main.executableURL` and its bundle directory, instead of requiring a
fictional runtime `PokrovCore.framework/PokrovCore` file. Linked Core calls prove
symbol presence at build time; this path metadata does not prove module hash,
successful setup or tunnel health. Runner and extension are different executable
images; neither archive/xcframework checksum nor Runner's eventual image digest
may stand in for the extension executing the VPN. Apple module identity and
preflight-to-extension selection binding remain unfinished.

No new Core artifact was generated; source, ABI/export,
frame-size, parser and build-tag checks are NOT_VERIFIED and deferred.

Signed policy consumption now uses manifest `capability_bindings`, decoded with
the same pure-domain feature enum as runtime inventory. A capability maps to one
opaque Core revision, required features, allowed `(platform, module SHA-256)`
pairs and profile refs. The client derives the selection context from those
authenticated rows and the current inventory; caller-supplied capability sets
are no longer accepted. Coordinator inventory changes revoke that context's
selection. The selector now obtains `coreModuleSha256` from the native snapshot
and no longer accepts a separate caller-supplied digest. Missing/changed digest
closes selection just like changed inventory. Linux, Windows and Android producers are
described below; Apple/desktop-FFI producers and executor pre-start
revalidation remain open. A filename, package-container hash or unchanged feature
list cannot establish identity. No activation or remote attestation is implied.

### Linux and Windows module digest (source only)

Linux's fixed metadata command returns a closed compact three-field envelope:
`schema: 1`, `transport_capabilities_json`, `core_module_sha256`, then one newline.
The daemon requires exact re-encoding equality in that field order and bounds
stdout to 8449 bytes, including escaped inventory. Core streams SHA-256 from
`/proc/self/exe` (128 KiB buffer, regular positive-size file at most 1 GiB), checks
size/mtime and cancellation, and returns empty identity on error. Its prepared
reply also carries the actual child's digest. Snapshot reads never substitute
preflight metadata for a live/exited child's unavailable answer. File-identity
checks still fence preflight reuse; it does not authorize the next exec by itself.

Windows `service_core_identity` opens the intended DLL with read sharing only
before `LoadLibraryExW`. For a freshly loaded image it matches the loaded module
pathname's volume/file ID to that held file and streams BCrypt SHA-256 in 64 KiB
chunks, with the same 1 GiB resource bound. A module loaded outside this owner,
unavailable pin, file mismatch or hash failure yields no digest. The process's
single Go Core module and its file handle remain retained across setup retries
until process exit; Core replacement therefore requires service shutdown/restart.
This matches the existing no-unload Go runtime lifetime. No DLL hash is guessed
from a filename or reread from a replacement after the module was loaded.

Windows snapshots append `core_module_sha256` (`none` when unavailable), and
Runner forwards `coreModuleSha256`. The existing 8192-byte frame bound remains.
Dart requires 64 lowercase hex characters and an initialized/config-staged/running
phase, includes the digest in snapshot state equality and uses it for signed
artifact allowlist matching. Linux forwards the analogous native field. Existing
ordinary ABI/health behavior does not gain a success/failure result from this
metadata; ATS cannot open without it. These hashes are observations within the
owned native trust boundary, not protection against a compromised host/Core.

No hashing, DLL loading or child execution was performed during implementation.
Source is NOT_VERIFIED; native/link/build checks, known-file digest parity,
load/retry/replacement and lifecycle races remain deferred. The executor still
must compare the expected identity before starting the selected profile.

### Android module digest (source only)

After successful Core setup, `AndroidRuntimeState` optionally invokes the
Android gomobile `space.pokrov.core.mobile.Mobile.coreModuleSHA256()` getter.
Only a lowercase 64-hex result becomes `coreModuleSha256` in the existing
snapshot. Missing method/class, linkage error or malformed result leaves it
null. Initialization clears previous bridge metadata first. The shared Dart
ready-phase gate and selector use the same native field as on Linux/Windows;
the Android locator's guessed package path never supplies this digest.

Core's Android-only hcore source uses `dladdr` on its own C anchor, then matches
the containing executable `/proc/self/maps` mapping to the backing descriptor's
device/inode. The ELF PT_LOAD executable segment binds the anchor's address to
the exact mapped file offset. Extracted libraries and direct APK loading are
supported: an APK must contain one matching uncompressed entry, whose ELF bytes
are hashed instead of the container. Missing access or any mismatch yields no
identity. No file paths, addresses or native error text cross the bridge.

The module limit is 1 GiB, backing-file limit 2 GiB, hash buffer 128 KiB and maps
read limit 16 MiB (16 KiB lines). Core rechecks file size/mtime/ctime and mapping
after hashing and caches the observation for its no-unload process lifetime.
Installed-image immutability relies on the owned OS/package trust boundary;
compromised host/Core remains outside this claim. No user permission, new
storage, network connection or tunnel action is introduced by the getter.

This source does not update the retained AAR. Generated Java names/retention,
all Android ABIs, linker/proc availability, extracted/direct/split APK packaging,
known-module digest parity and replacement/lifecycle behavior remain deferred
gates. No hashing, native call, build or test ran. Status: NOT_VERIFIED.

### Android connect with expected Core identity (source only)

`RuntimeCoreIdentityConnect.connectWithCoreIdentity` is implemented by the mobile
engine for Android and Windows (Windows details below). Unsupported hosts reject
the method; ordinary `connect()` does
not silently substitute. Its dedicated `runtimeEngine.connectWithCoreIdentity`
method takes `requestId` (32 lowercase hex), `expectedCoreModuleSha256` and
`expectedProfileDigest` (64 lowercase hex each). The latter is the exact staged
profile digest, not a catalog ref or filename. Missing/malformed values are
rejected before starting a request. The existing process-local owner binds
these values to the request ID and rejects reuse with conflicting digests.

The method also requires `bootRef`, `startedElapsedMs` and `deadlineElapsedMs`.
Android additionally requires `expectedNetworkContextRef` from the same bridge's
`runtimeEngine.transportNetworkContext` method. That read returns exactly schema
1 and `network_context_ref` (`network_<32 lowercase hex>`), or an unavailable
error. Caller refs cannot manufacture the observer/ref binding. The bridge checks
a fresh read before admission, and the request owner checks the retained ref
through permission callbacks, service admission and startup. This Android method
has seven fields; the Windows method also requires its service-issued network ref.
Android checks the boot against `Settings.Global.BOOT_COUNT`, integer codec types,
safe integer range, positive interval at most 86,400,000 ms (the signed budget
schema ceiling), and current `elapsedRealtime` inside the original interval.
This ceiling is not an operational budget default. The deadline is immutable
in the request owner, permission token and START intent; replay cannot extend
it or omit it from a bound request. Process restart does not preserve the owner.

After setup the bridge compares the loaded Core getter and restored staged
profile with those expectations, before permissions or service dispatch. The
pending permission token includes the Core expectation and original profile
digest; notification and VPN consent resumptions retain them. Service START
requires the recorded ID/Core/profile tuple, so dropping or substituting an
expectation cannot downgrade a bound request into the ordinary start path.
Cancelled or replaced owners remain ineligible. No new identity is persisted.

The service rechecks request ownership around native identity/file reads, compares
Core before replacing the runtime session, then checks again after setup before
endpoint preparation and immediately before `startOrReloadService`. It uses the
native module getter's process-lifetime observation, not a new hash of the
installation path. Missing/mismatched identity reports fixed
`core_identity_mismatch`; startup cleanup remains scoped to the owned session.
The existing immutable profile-byte check still binds service execution to the
requested staged digest. This does not prove that profile's signed resolver
origin or the identity of every host transformation applied to it.

The response is a closed envelope `{schema: 1, requestId, snapshot}`. Dart checks
the exact ID/shape, current invocation, native Core hash and staged digest. It
does not use the ordinary helper's post-error snapshot fallback. Failure sends
the existing exact-request cancellation; inability to confirm that cancellation
is reported separately. A valid response only returns current request state:
permission wait/start dispatch is not connectivity proof, and cancellation ACK
is not TUN teardown. Executor permits, original policy/lease deadline, diagnostic
byte reservations and exact stopped/healthy readback still require integration.

The ordinary shell Connect/Quick Settings/OS paths do not call this new selector
method. No ATS activation or automatic policy-bound restart is implemented here.
Linux's expected-identity/deadline integration is described below;
Windows integration and cooperative Core cancellation are described below;
Apple start checks remain open. Status: NOT_VERIFIED;
no API/native call, random ID, hash, test, generator or build was executed. Later
checks must cover exact/missing/conflicting identities, old host rejection,
permission delay, cancellation/replacement and pre-start refusal with no TUN.

Android deadline handling now uses the original native-clock sample plus the
reserved remaining duration supplied by `TransportChildPermit`. The Dart API
takes `budgetStartedAt` and `budget`; it does not start a fresh budget after
awaiting clock or method-channel replies. It publishes the cancellable request
ID before the first clock await, checks the same boot/interval before dispatch
and after reply, bounds outstanding channel waits and cancels the exact request
on failure. Changing or cancelling the request during clock acquisition cannot
later dispatch an abandoned start.

While permissions are pending, one bridge watchdog expires only the current
request and retires its pending state. Once the service accepts it, the service
retains a separate immutable deadline on that exact runtime session. Queued
START/file/native admission and runtime callbacks check elapsed time directly.
The session watchdog fences its generation and closes owned child scopes before
queueing teardown; its queued STOP checks that generation again. Thus a replaced
watchdog cannot stop a newer session. Watchdogs run at 100 ms handler intervals,
re-evaluate elapsedRealtime after suspension and are removed on owner teardown.
They do not wake the device or claim a hard real-time teardown latency: main
thread scheduling and native-call interruption remain device validation gates.

No successful-start/protected flag removes this deadline. Until a separate
proof/lease-bound handoff is implemented, even a started tunnel from this entry
point expires with its original attempt. Timeout is not a dataplane failure or
grant revocation and does not clear a concurrently staged durable profile.
Ordinary Connect still does not call the new method. Diagnostic byte reservation,
native lease/access limits, proof-bound promotion and exact stopped readback are
unfinished; local watchdog source is not proof of any of those behaviors.

### Linux connect with expected Core and profile identity (source only)

`pokrov-linuxd-v1` adds the dedicated `connect_with_identity` action. Its closed
payload requires `expected_core_module_sha256`, `expected_profile_sha256` (64
lowercase hex each), daemon-issued `expected_network_context_ref`
(`network_` plus 32 lowercase hex), `boot_ref`, `started_elapsed_ms`, and
`deadline_elapsed_ms`.
Unknown fields, nulls, missing fields and invalid digests/deadlines are rejected.
This action shares existing polkit authorization
and the socket cancellation monitor with ordinary connect. An old daemon rejects
the action; the caller must not retry it as ordinary `connect`. An existing
transaction or pending recovery returns `linux_runtime_busy` without changing
the existing session's health or running recovery on behalf of a new candidate.

The read-only `read_network_context` action returns schema 1 and one random
process-local ref. The daemon privately samples main-table physical default
routes, active interface addresses, per-link `resolvectl status`, NetworkManager
active connection and Wi-Fi access point/BSSID. `pokrov0`, its route table and
resolver link do not enter the sample. Read or state failure invalidates the
ref; this source currently admits NetworkManager Ethernet/Wi-Fi uplinks only.
Bound admission compares it before authorization, after Core preparation
and after startup; a running owner is rechecked and cancelled on change or
unavailable observation through the existing exact rollback path. Raw physical
metadata is neither returned nor logged. These source paths are NOT_VERIFIED;
daemon restart reconciliation remains open. A passive netlink subscription now
invalidates the process-local ref for selected physical link/address and default
route events, and cancels the exact bound call. POKROV's own TUN/custom route
table are excluded. Event invalidation is independent of slow sampling: an
in-flight read cannot restore the old ref after a netlink change. A failed
physical sample also revokes a current ref and cancels its bound request;
cancellation of an unrelated reader does not masquerade as a network change.
Before sampling, linuxd also waits for a system-bus monitor subscription to
NetworkManager signals. Selected physical device, active-connection and access-
point identity/state changes and selected IP/DNS config changes invalidate the
ref between reads; NetworkManager owner replacement does the same. Signal
parse/monitor failure blocks further
bound reads and cancels the bound owner. Unselected Wi-Fi scan/strength updates
do not invalidate it. The same monitor revokes the ref on systemd-resolved
owner replacement or a signal from a selected physical link. This is source
only, NOT_VERIFIED. Some resolved DNS properties do not emit change signals;
direct configuration changes without an emitted link signal still depend on
sampling and can be transient between reads.

`coreprocess.PrepareWithIdentity` launches only the fixed installed Core and
requires its private `prepared` reply to contain `identity_schema: 1`,
`deadline_schema: 1` and both
matching digests. This occurs before `networktxn.Execute`, its recovery record
and its first network checkpoint/apply. A mismatch aborts the child and returns
fixed `core_identity_mismatch`. The profile digest is over the exact staged
bytes read by Core; it matches `profile.Store.Stage`'s input digest and is not
the transformed runtime config's hash. The service lock keeps staging and
connect serialized, while Core retains the already-read config in memory.

The session sends `start_with_identity` with that same pair and nested `deadline`
object on the fixed stdin channel. Core compares it against the prepared pair,
rereads its own module SHA and checks the boot-relative interval before
`hcore.Start`. Bound `started` replies confirm both schemas, the pair and exact
`connect_deadline` object. Any failure at that stage uses the existing transaction
restoration path; failed restoration retains ownership. The command limit is
512 bytes and Core/linuxd must be shipped as a matching pair. No new privilege,
path, listener, durable profile metadata or entitlement is introduced.

`LinuxDaemonRuntimeEngine` implements `RuntimeCoreIdentityConnect` with original
`budgetStartedAt`/`budget`. It publishes its owner before clock IO, accepts only
the matching response with running Core and effective input-profile digest, and
checks the original same-boot interval before dispatch and after response. There
is no ordinary snapshot fallback. Invocation timers cover dispatch and final
clock read without renewing on each await. A second local start is rejected
until cancellation/disconnect settles the bound owner.

The daemon observes CLOCK_BOOTTIME before authorization and uses a clock-checked
cancellation context through authorization, host probe subprocesses, startup and
health probe. Core checks that same interval before/after Start and retains a
100 ms clock watcher after responding. Expiry, boot mismatch or clock loss closes
the attempt; successful start does not renew it. The 24-hour ceiling is a schema
bound, not a default or lease permission. Neither watcher wakes the host or
claims hard real-time scheduling/native interruption. Restoration uses the
existing separate cleanup deadline and retains dirty owners on failure.
An exited child whose deadline is expired/unavailable reports `connect_deadline`
after restoration; this observation does not establish causal crash telemetry.

`cancel_connect` takes only `connect_request_id` and can cancel after the start
socket closes. It matches the retained bound invocation and original kernel peer
(UID/PID/process start time), without another polkit prompt or authority to
disconnect a different process. The invocation is registered before authorization;
a separate lock lets cancellation reach its context while startup holds the
runtime lock. Its completion channel closes after authorization/start returns.
One invocation record is retained, and a new bound request cannot replace an
unfinished call or resources whose restoration remains unconfirmed.

The success envelope contains exactly `protocol`, `request_id`, `ok` and
`connect_cancellation`; the latter contains exactly integer `schema: 1`,
`connect_request_id` and boolean `settled`. `settled: true` requires the exact
invocation to have ended and its native owner to have been released after
restoration. Unknown/replaced requests or a restarted daemon return false;
an idle global snapshot never substitutes for this receipt. The wait for invocation
completion is capped at 35 seconds; runtime-lock acquisition and restoration are
separate, and no hard upper bound on OS calls is claimed. Timeout/failed cleanup
keeps ownership and allows an explicit exact-request retry. A distinct request
rejected before admission with `linux_runtime_busy` carries the same receipt in
its failure envelope; reuse of the existing ID cannot get an unowned receipt.

Before lease promotion, loss of the kernel-identified UI peer cancels the bound
attempt. Promotion checks peer liveness before and after the Core ACK. Once the
exact lease is promoted, UI exit no longer stops the native runtime; physical
network-context invalidation still cancels and restores that exact runtime.
The daemon's Core IPC accepts the explicit `promoted` and `lease_revoked` reply
phases and checks their exact profile/lease fields before publishing a handoff
or revocation. An unknown phase still fails closed.

Dart implements `RuntimeConnectSettlement.cancelAndConfirmConnectStopped`.
It signals cancellation and joins outstanding clock/socket futures before
consuming the receipt. Even late replies that lose the cancellation race retain
their non-admission result. The production transport can also prove cancellation
before any request bytes were written; ambiguous delivery cannot do so. Missing,
old or malformed receipts retain the local owner. Bound `disconnect` uses this
exact path, not a general stop of a replacement. Ordinary connection behavior is
unchanged. Cancellation/expiry never deletes the profile. Recovery across daemon
restart still needs a separate ownership reconciliation path; false is not proof.

Snapshots expose the last staged input digest in memory and actual child's
effective input digest. Restart leaves the staged digest unknown until staging;
the effective digest comes only from the current child. Neither is a claim about
the transformed config hash or remote authorization. Selector executor, byte IO
and proof/lease-bound handoff remain open. Ordinary Connect does not enable ATS.
Source is NOT_VERIFIED: no native/hash/test/format/build execution. Later checks
must cover boot/suspend/expiry, old schemas, profile mismatch, cancellation
before/after response, peer/request replacement and failed restoration.

### Windows service connect with expected identity and deadline (source only)

Private service protocol v1 adds `kConnectWithIdentity` (command 21), negotiated
with `kCapabilityBoundConnect` (bit 15), `kCapabilityConnectSettlement` (bit 16),
`kCapabilityTransportNetworkContext` (bit 18), existing boot-clock and profile-identity
capabilities. Its bounded canonical ASCII body is
`core_sha256|profile_digest|boot_ref|started_elapsed_ms|deadline_elapsed_ms|network_context_ref`.
Both digests are 64 lowercase hex; boot ref is `windows:` plus 32 lowercase hex.
Times are canonical unsigned decimal milliseconds, end at most JS-safe integer,
start < end, and duration at most 24h (schema ceiling, not an operational default
or lease grant). The ordinary frame deadline remains an additional IPC/start
limit. Older services reject the opcode/capability rather than silently treating
it as ordinary Connect.

`RuntimeHost::ConnectWithIdentity` rejects an already running or recovery-owned
runtime. It uses the existing staged request digest, including flags and bundled
rules, and compares the pinned loaded DLL digest before recovery work and at
the checks surrounding `CoreRuntime::Start`. This observes the service's existing
protected staging owner; it does not introduce proof of every materialized file
or replace signed profile authorization. Missing/changed module identity yields
`core_identity_mismatch`. Boot identity and QueryInterruptTimePrecise are read
through the existing service clock producer; the same original interval is
checked through startup/probe, with `connect_deadline` on expiry or uncertainty.

The dispatcher retains the exact session-token/operation-nonce owner after a
successful bound start. Its 100 ms observer marks cancellation/expiry and uses
the existing serial execution lock for Disconnect/restoration. It never races
Stop against Start or operates on a replacement owner. Status and restriction
commands cannot erase this owner; a competing start/stage/initialize is busy.
Restoration failure retains the owner and recovery state, without timer-driven
repeated cleanup; an explicit exact cancel can retry. No wakeup or hard real-time
teardown is claimed. Bound startup now requires the additive Core export
`pokrovCoreStartInterruptibleV1` before arming recovery. Its invocation-scoped
callback observes the same cancellation and original boot interval. Core polls
it every 25 ms and cancels the startup context; context-aware work and lifecycle/
TUN admission checks observe that cancellation. The observer joins before the
DLL returns, so it cannot access a stale C++ owner. Missing export rejects with
`core_abi_incompatible`; bound start cannot fall back to ordinary start.
The callback never calls Stop; after return the original serial owner performs
rollback and retains failed restoration. An arbitrary blocking OS/driver call
still must return before cleanup; this does not claim forced interruption or a
hard teardown deadline. Successful startup leaves its context live and the
service's original deadline armed.

The C++ service client negotiates the new command, preserves cancellation across
lost/invalid replies, and checks returned module/effective profile digests. The
private `ServiceCallControl` can retain its cancellation target after the reply;
`CancelInstalledServiceConnect` addresses only that target. It is never exposed
in snapshots, logs, or diagnostics, and cancellation admission is not stopped-TUN
proof. Windows runner/Dart dispatch is implemented below; selector executor,
byte IO and proof/lease handoff remain open. Ordinary Connect
does not activate ATS. All of this is source-only, NOT_VERIFIED; no native clock,
registry, randomness, hash, test, formatter, build or service operation ran.

The Windows runner accepts the dedicated method-channel call with exactly seven
fields: requestId, expectedCoreModuleSha256, expectedProfileDigest, bootRef,
startedElapsedMs, deadlineElapsedMs, expectedNetworkContextRef. Request IDs are fresh 32-hex values;
elapsed values must be integral and bounded, and the profile must match the
runner's acknowledged stage request. It queues command 21, retains its private
control and returns the closed `{schema: 1, requestId, snapshot}` envelope only
for a matching live Core/profile response. Cancelled/superseded completions and
service failures cannot return a successful fallback snapshot.

Dart supports this entry point on Windows and checks the original clock interval
before dispatch/after response, the request ID, loaded module and staged/effective
profile digests. Invocation-wide timers cover clock reads and the channel reply;
the shared Android method now uses the same timers without per-await renewal.
Windows cancellation first signals the exact control immediately, then queues
its service cancellation lookup behind the original worker call. Thus it also
covers a response already delivered or a start that never reached IPC. The ACK
retains the runner control and its private cancellation target; it cannot discard
the ability to retry failed restoration. Neither fresh Status nor a general
Disconnect snapshot releases the bound runner/Dart owner. Exact settlement is
required as described below; busy/recovery/error fallback cannot substitute.
Window teardown settles queued work and makes a final exact cancellation lookup
for an unpromoted attempt; after confirmed lease handoff it leaves the service
lease running under native network and expiry monitoring. The native startup
deadline stays armed when an unpromoted cancellation ACK is unavailable. These are source
ownership rules, not completed native proof. Ordinary shell Connect still does
not call the selector entry point. Cooperative Core interruption is implemented
in source; executor/proof/byte/lease integrations and runtime verification remain
open. No new verification was run.

### Windows exact stopped receipt (source, NOT_VERIFIED)

The dispatcher owns a `ServiceNetworkObserver` for its service lifetime. It
registers IP interface, unicast-address and route notifications and cancels those
registrations outside callbacks before destroying their context. Registration
failure refuses bound admission. No second polling thread is introduced: the
existing bound watcher samples adapter/DNS metadata at its 100 ms cadence.
Status and bound-control boundaries also refresh that sample. A racing callback
cannot be incorporated into a sample of older adapter state: the captured atomic
revision must still match. Metadata and numeric revisions remain private process
memory; the opaque reference described below is the only context value exported
over the private pipe. No storage, telemetry or privilege extension is added.

The observer excludes the recovery-owned `POKROV` adapter, retaining its known
LUID for deletion notifications. Other IP interface/address/route changes, DNS
order/suffix, prefix/DAD state and adapter status/metrics/MTU changes invalidate
the bound revision. Metadata read failure also cancels it. Cooperative startup
checks consume the revision, and the existing execution lock joins Start before
Stop/rollback. The public failure remains `operation_cancelled`; an exact stopped
receipt still requires successful cleanup. Before cleanup publishes its result,
the dispatcher substitutes a pre-captured `busy` snapshot for stale `running`
state and retains `transport_proof_pending=1`. A recorded `recovery_required`
snapshot stays visible. This is not a new positive proof or a cleanup receipt.

`kReadTransportNetworkContext` (command 24, capability bit 18) accepts an empty
request and returns exactly `network_<32 lowercase hex>`. The observer retains one
random ref for its current revision; a different revision or service process
gets a new ref. Read/capture failure returns unavailable, with no synthesized
identity. The service client checks the closed ref format and the runner returns
exactly `{schema: 1, network_context_ref}` to Dart. The shared selector obtains
and rereads it from the same engine used for staging, within the original budget.
Bound Start carries it as the sixth canonical body field; service rereads and
compares it before admitting any native mutation. Stale refs obtain only a
pre-admission stopped receipt, never an owner for the current network. Old
clients/services without bit 18 cannot use this bound path. No ref contains an
IP, DNS suffix, network name, counter, session token or cancellation target, and
neither the ref nor its mapping is persisted/logged/exported to the backend.

The service samples WLAN connection state, SSID/BSSID and security attributes
locally when an up Wi-Fi adapter is present, and its WLAN notifications advance
the revision on connection or roaming changes. This material never crosses IPC.
Through exact Core lease promotion, the Windows service checks the original
client process; after promotion it monitors the physical network and lease
deadline without cancelling solely because the UI exits. Restart reconciliation
and handoff validation remain open. Source only, NOT_VERIFIED.

Service command 22, `kCancelConnectAndConfirm`, requires capability bit 16 and
the existing private cancellation-target body (original session token/operation
nonce). The service validates that exact target, signals its cancellation before
waiting for the serial execution lock, then restores only the same runtime owner.
It returns only `settled=0` or `settled=1` with status OK. True requires successful
restoration or a retained record that this invocation already ended without an
owned runtime. The dispatcher keeps one stopped-target record, including bound
requests rejected before runtime admission. Unknown/replaced/lost history returns
false, including after service restart. Failed restoration retains active ownership.
No status snapshot is used to infer this receipt and no private target is exported.

The runner signals the original control immediately and queues settlement behind
the original worker invocation. The client retains an ambiguous IPC write target;
only a completed invocation with no published target proves it never wrote.
The runner exposes the closed `{schema: 1, requestId, settled}` response through
`runtimeEngine.cancelAndConfirmConnectStopped`, and releases its control only on
true. A pre-queue rejection uses `core_identity_connect_not_dispatched` with this
same exact-ID receipt in error details. Unknown method/old service/malformed or
lost responses cannot release an owner. Bound connect now negotiates bit 16 before
dispatch; there is no fallback to snapshot-based settlement.

Windows `MobileArtifactRuntimeEngine` implements `RuntimeConnectSettlement`.
Cancellation dispatch happens before joining pending clock/channel futures, so
it can interrupt a native Start cooperatively. Even late non-dispatch errors are
processed, and all started futures finish before returning or freeing ownership.
Bound disconnect follows exact settlement; a competing start remains busy until
confirmation. Native blocking calls and serial cleanup can outlive IPC timeouts;
an uncertain receipt remains false and the same request can be retried. Cross-
restart ownership reconciliation and the shared executor are
still open. No tests, builds, native calls or runtime receipts were executed.

### Android exact stopped receipt (source, NOT_VERIFIED)

Android implements the same closed `{schema: 1, requestId, settled}` method-channel
receipt and `RuntimeConnectSettlement` as Windows. The process-local request owner
binds one admitted `VpnService` instance to a bound request. A different ordinary,
Quick Settings or bound start cannot replace an unsettled owner. A bound START
cannot adopt a service instance that has already accepted another command; it
must reach a fresh service owner. Retained receipt IDs cannot be reused.

Cancellation before service admission atomically fences all later permission
callbacks and START intents, clears matching permission waiters, and can return
true without creating/stopping a service. Unknown requests return false. A valid
pre-admission rejection carries `core_identity_connect_not_dispatched` with the
same exact-ID receipt in its error details; conflicting known IDs cannot obtain
that bypass. The Android bound connect call requires exactly the seven documented
fields, including the preparation network ref.

After service admission, cancellation fences the runtime session immediately and
queues cleanup on that exact service's serial executor after startup. Bound
cleanup retains CommandServer/TUN handles on close failure, remembers a completed
closeService separately from CommandServer.close, and joins cancelled child pools
and their cancellation hooks. Each child-pool join has a 30-second limit; timeout
or hook failure is not settlement. Native close itself has no forced-interruption
or hard timeout claim. Only confirmed cleanup allows stopped state and an exact
receipt; failure reports runtime_stop_failed/pending and preserves the owner.

If Android destroys the service before confirmed bound cleanup, the request owner
retains its exact instance and serial executor for retry. Successful cleanup
releases that reference and shuts down a destroyed service's executor. A failed
cancellation hook remains unconfirmed rather than being inferred closed on a
later idle read. This is process-local ownership, not proof across process death;
restart reconciliation remains open. Legacy ordinary cleanup is unchanged when
there is no bound owner. Dart uses shared Android/Windows pending-future joins,
pre-dispatch receipts and exact bound disconnect, with no snapshot-based release.

The common executor, proof/lease handoff and actual route/DNS settings binding
remain open. No ATS activation or native/runtime verification is claimed. Later
checks must cover permission cancellation, late/duplicate START, failed closes,
child settlement, service destruction, request replacement and explicit retry.

### ATS final profile identity at stage (source, NOT_VERIFIED)

RuntimeCoreIdentityStage is an additive Dart host interface implemented by
Android/Windows MobileArtifactRuntimeEngine and LinuxDaemonRuntimeEngine. It
reuses the ordinary materializer and stage command. A caller binding callback
receives the exact final private identity input after all adapter transformations:
Windows memory-limit flag plus the existing config/rule-set bundle; Android
probe flag, service route mode and config; Linux exact transformed config bytes.
The callback returns SHA-256; raw identity input is never a diagnostic artifact.

Before callback/native stage and after acknowledgement, the operation must still
be owned, initialized/config-staged and non-pending with the expected actual
Core digest. Host returned stage digest must match. Android/Windows send that
expected digest through their existing pre-write check. Linux compares the
existing exact-byte store digest after its atomic stage and again at bound
connect. A changed/missing Core or cancelled owner cannot produce a stage receipt.
No unscoped profile invalidation is issued on a late response.

If materialized config requires catalog/Smart Access restrictions, the existing
persistence callback remains required before stage. When ATS binding and that
callback both run, their digests must agree. Linux still rejects these profiles;
its missing restriction runtime is not bypassed. The coordinator holds its child
until the native stage future returns, rather than freeing it on timeout alone.
A stage receipt is not TUN ownership or health, and the original template digest
is not the platform stage digest. Full connect/proof/lease-reuse integration and
Apple/desktop-FFI support remain open. No native call/build/test/hash was run.

### Shared ATS invocation ownership (source, NOT_VERIFIED)

`RuntimeCoreIdentityConnect` now requires `onRequestCreated`: Android/Windows and
Linux publish their exact local request ID after registering its owner and before
any await/native dispatch. Callback failure follows the same joined cleanup path;
failure before publication guarantees no native work for that invocation. This
is a Dart API change, with no new host wire fields or native ABI change.

The selector retains the staging engine, reserves the tunnel before snapshot/
connect work, and passes the original permit clock/interval. Native acknowledgement
does not free the tunnel. A separate retained owner keeps cancellation/deadline
effective after the Start future completes, joins concurrent stop requests and
requires exact settlement plus executor completion. False/error retains ownership
for explicit retry and prevents a replacement selection. Android pending status
is admission only; health, proof-bound handoff and restart recovery remain open.

ATS restriction persistence now uses that stage child's ownership for native
journal recovery/readback, durable retention, ACK and the exact profile binding.
The shell requires the same runtime engine and current catalog-control/journal
capabilities. Pending native/storage operations stay joined after cancellation;
no stopped claim follows from an expired Dart timeout. The receipt carries the
retained catalog identity only after native stage confirmation, and catalog/service
revocation guards remain attached through connect. Linux's missing restriction
runtime is still rejected. These source changes are NOT_VERIFIED.

### ATS bound background control (source, NOT_VERIFIED)

Android also exposes `runtimeEngine.snapshotForConnectRequest` with the sole
`requestId` argument and a closed `{schema: 1, requestId, snapshot}` receipt.
The process owner rejects an ordinary, cancelled, stopped, unknown or expired
request. Its state read checks the admitted module/profile; running identity
additionally requires the bound service/session and completed Core Start.
Publishing TUN before Start returns is still pending. This read exposes the
actual running digest independently of legacy egress health, without changing
the ordinary snapshot or its health oracle. Staged digest may be absent after
authorized reuse invalidation, while the running bound profile remains exact.
The shared executor retains its original tunnel child through pending reads;
cancellation does not replace a read with an unbound snapshot or free ownership.
This is lifecycle progress, not transport/DNS/payload/egress proof.

`RuntimeBoundSmartAccessControl` uses the closed method-channel request
`runtimeEngine.configureBoundSmartAccessRuntimeControl` with `requestId`,
`profileDigest`, `configJson`. Its receipt has exactly `schema: 1`, `requestId`,
`profileDigest`, `configured`. Unsupported hosts cannot substitute the ordinary
digest-only method. Dart checks the owner again after receipt.

Android resolves the request to its admitted service and checks current request,
session, generation, profile and original deadline in the serial executor before
Core configuration and again when returning its result. Windows negotiates
command 23 / capability bit 17. The runner binds the local request to the retained
private cancellation target; the bounded service body is that 64-hex target,
`|`, then the existing digest/config body. The original connect control is not
reused as the new IPC call's mutable control. The dispatcher holds its execution
lock across owner/profile/deadline checks and Core mutation. Concurrent cancel
suppresses a positive receipt and serial cleanup follows; a replacement with
identical profile bytes cannot receive the delayed configuration. Private target
and configuration are never returned or logged. These source changes have no
host/runtime proof yet; ordinary control/renewal retains its existing protocol.

### Android bound network and Core reload ownership (source, NOT_VERIFIED)

`AndroidConnectRequestOwner` retains a local uplink generation once its admitted
service is ready to start Core. Admission of that binding checks exact service,
request, deadline and current monitor generation. It cannot be rebound after a
network change. Completed-start progress requires a bound network, and subsequent
owner checks include it even after the startup/TUN commit.

The existing default-network monitor advances the context for a selected-network
replacement/loss and LinkProperties changes on that network. It enters the
request owner only after releasing the monitor lock; the owner fences the request
before calling its exact service outside the owner lock. Serial cleanup and
retained failed-resource handles remain authoritative. A network event does not
constitute a stopped receipt. Network-triggered and Core-requested reloads of a
bound attempt likewise cancel rather than preserve proof across a new Core run.
The retained stop reasons distinguish network invalidation/reload from user stop.
No new raw network identity is exposed through Flutter, storage or diagnostics.
Activity closure fences and cancels an unpromoted bound attempt. After native
lease promotion the service retains the passive physical-network observer, and
releases it only when that exact service owner stops; Activity closure alone no
longer revokes the accepted lease. Pre-start selector context, cross-process recovery and other
platform hooks remain open; this source has not been run or validated.

### ATS proof-pending snapshot across UI restart (source, NOT_VERIFIED)

Windows `stageWithCoreIdentity` requires service command 25/capability bit 19.
The runner sends the ordinary profile body and verifies its unchanged digest;
the service records a bound-only bit only after successful staging. Its ordinary
Connect path rejects that profile as `profile_identity_mismatch` before Core or
network changes. Replacement ordinary staging or invalidation clears the bit;
closing only the UI does not. The service does not restore staged admission after
its own restart. This source path has not been tested.

Android preparation uses one passive network observer owned by the bridge. It is
created only on an explicit transport-context read and unregistered on bridge
close. It registers underlying-network and default-network callbacks (API 24+),
matching the app's minimum supported SDK. Default changes between samples invalidate
the previous ref, while the VPN becoming default preserves the observed eligible
uplink. Loss/selected-network/LinkProperties changes and changes to selected
uplink transport, validation or captive-portal capabilities invalidate its opaque
ref; fresh reads also reconcile the current underlying-network choice. Capability
comparison is local and adds no SSID/BSSID access. The observer
notifies the request owner outside its lock. Service network binding compares
the actual Core monitor's Network/LinkProperties before retaining its generation.
Bridge close invalidates a still-bound attempt and uses exact service cleanup;
it cannot transfer that attempt to a recreated UI. No new Android permission,
network request, probe, socket, disk state or external network identifier is added.

Android staged ATS input retains `requires_bound_connect` in private profile
metadata. The host commits this restriction before replacing config bytes. The
tile opens the app for such input; service admission rejects a missing bound
request/Core/deadline as `profile_identity_mismatch` before replacing Core/TUN.
Existing exact-owner, deadline and immutable-content checks remain authoritative.
No request identity or deadline is restored from disk, and this is not successful
attempt recovery or permission to reuse an expired lease.

Native snapshots now expose whether an admitted bound owner still requires ATS
healthy handoff. Android method-channel and Windows runner use boolean
`transportProofPending`; Linux JSON uses boolean `transport_proof_pending`.
Windows service snapshot framing appends `;transport_proof_pending=0|1` after the
module digest. Its parser checks field ordering, boolean and end-of-frame, and
preserves whether the field was present. Older status frames remain readable for
ordinary operation but cannot provide the ATS admission capability.

Android retains a volatile bit from bound admission through exact service or
pre-admission settlement; snapshot reads do not invert request/state lock order.
Windows derives the bit under its dispatcher state lock from the retained bound
owner, including cancellation or failed restoration. It decorates status and
runtime-operation snapshots, not control or stopped receipts. Linux derives it
from the retained bound request under the service mutex. No sensitive owner
identity is added to these snapshots, and no new persisted proof is introduced.

Shared `RuntimeSnapshot.transportProofPending` is nullable for unsupported hosts.
Present malformed wire values cannot authorize health. True blocks the shared
healthy predicate, proof timestamps and verified presentation after UI recreation.
The coordinator keeps that block through failed/missing status; explicit false
only clears it after ended runtime and no local child/TUN ownership. A new ATS
selection requires field support, pre-start state false, and subsequent bound
startup/control/proof snapshots true. If a new UI owner observes a running native
runtime with this bit still true, startup/resume or desktop polling now publishes
the pending state and requests a runtime disconnect; it cannot inherit the old
attempt's nonce, budget or proof. A failed stop retains the negative gate. The
future successful handoff must change this state through an authenticated
exact-owner transition; host process restart and cleanup reconciliation remain
open. No tests, native calls or builds have been run for this source change.

### ATS bound probe adapter boundary (source, NOT_VERIFIED)

The new Dart `RuntimeBoundConnectivityProbe` interface requires exact-owner and
effective module/profile checks before and after native work, stage-specific
results, diagnostic reservations before IO and joined cancellation settlement.
Payload/egress success requires a real authenticated verifier exchange, not only
well-formed refs in the parsed response. Local request fields include native boot
time and network context; they are not a public API or telemetry body.

No host implements this new interface yet. Its consumer reports unavailable and
keeps ATS presentation unverified. Existing URL-test/204 results remain their R12
observations and cannot be promoted to a four-stage ATS proof. Native parity,
verifier-origin ownership, wire-byte accounting and healthy-lease handoff remain
open. The owner set `max_diagnostic_bytes` to all network bytes of a probe,
including DNS, handshakes, headers and retransmissions; payload counters alone
cannot discharge that budget.
The selector also rejects a stage `PASS` if its native producer never reserved
diagnostic bytes. This only closes the zero-reservation case; it does not prove
that the producer measured every network byte.
An `egress` result cannot pass yet, even with well-formed verifier/receipt refs:
the first-party payload endpoint reports its observed client IP, but no
endpoint-authorized egress set is bound to that observation and native path
evidence remains absent. The proof executor rejects that result
until a separate expected-egress oracle is wired into the same bound attempt.

For payload, the adapter receives a session-owned `RuntimePayloadProbeExchange`
with the exact bound request. It must take its sensitive request once, use only
that configured HTTPS API endpoint through the admitted Core owner, disable
redirects/retries, enforce the 2 KiB response limit while reading, and pass the
actual endpoint/status/body to one response acceptance. Token and payload must
never enter receipts, logs or persistent storage. The schema/body checker does
not supply TLS or transport authority. The producer joins request/response and
diagnostic-reservation callbacks as well as native IO before completing, including
cancellation; closure is a cancellation signal, not a settlement receipt. On
success it leaves the accepted verifier/receipt refs available to the executor,
which compares them against the native result and then closes the exchange.
Preparation consumes the original payload child deadline. This is a Dart boundary
and consumer implementation only; host IO and its evidence remain open.

### ATS accepted-lease status after UI restart (source, NOT_VERIFIED)

Android, Windows and Linux native snapshots now distinguish an accepted bound
lease (`transportLeaseActive`) from an unfinished bound proof
(`transportProofPending`). The marker contains no request, endpoint or lease ref.
Android publishes it from the process owner without reversing the runtime-state
lock order; Windows adds an ordered optional status field; Linux derives it from
the retained daemon owner. Service ownership and lease deadlines still govern
traffic while the UI is closed.

On Linux, a confirmed terminal lease revocation clears the active marker and
restores proof-pending while the rejecting Core target awaits exact stop. The
same profile cannot be promoted again after revocation. A drain retains the
accepted owner while Core permits only already open flows until their original
deadline; DNS/egress health is negative in either case. Dart checks the terminal snapshot
before accepting its revocation receipt.
Android likewise changes the exact process owner to proof-pending and clears its
active-lease marker only after Core confirms terminal revocation. A closed UI
then stops that owner; a concurrent UI close forces exact service cleanup rather
than leaving a terminated lease detached. The host bridge checks both markers.
Windows service projects proof-pending and clears active-lease as soon as it
admits a terminal revoke command: concurrent `Status` cannot report the old
lease as active while Core settles the command. The markers remain negative
after Core ACK or uncertain cleanup; runner requires them in the returned
snapshot and does not publish healthy DNS/egress while proof is pending. A
terminated owner no longer survives loss of its client process;
drain retains its original active-flow deadline.

A recreated UI has no exact lease identity and cannot resume signed-policy
refresh or targeted revocation for that owner. On startup/resume and desktop
polling it presents such a running lease as unverified and requests native
disconnect before a fresh selection. If stop is unconfirmed, it keeps the
negative presentation instead of treating the healthy host snapshot as a new
proof. Native proof producers, byte-accurate diagnostic caps and runtime restart
proof remain open; no build, test or device operation established this behavior.
