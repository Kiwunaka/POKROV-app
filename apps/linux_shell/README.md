# POKROV Linux conditional beta

[R12-L01 scope verification](../../docs/operations/evidence/2026-09-11-r12-android-abi-promotion/README.md#r12-l01--verified--i3--already_fixed)
confirms the existing Ubuntu 24.04 amd64 boundary and current capability against
main 57352ae source and CI. It closes the scope decision only; package and
desktop-session acceptance below remain separate.

This lane is a non-public foundation for the conditional Linux beta. The
Flutter UI always runs as the desktop user. Privileged VPN state belongs to the
systemd-activated `pokrov-linuxd` service and is never performed by the UI.

The IPC boundary is `/run/pokrov/pokrov-linuxd.sock`. Each request is bounded,
the daemon authenticates the kernel-provided Unix peer credentials, and every
mutating action requires `space.pokrov.linux.manage` through polkit. A world
connectable socket does not grant authority; it only makes the authenticated
system-service endpoint reachable without placing desktop users in a standing
privileged group.

The Linux entrypoint mounts the shared UI directly with its app-first
bootstrapper. Operational observability remains limited to Android/Windows;
calling that unsupported startup API on Linux aborts before the first frame.
The Linux shell does not initialize that API or claim its telemetry coverage.

Current source status is `IMPLEMENTED_PARTIAL`. The L02 live lifecycle is
implemented and [verified in an isolated Ubuntu VM](../../docs/operations/evidence/2026-09-11-r12-l02-linux-runtime/README.md);
durable recovery also has [L03 VM evidence](../../docs/operations/evidence/2026-09-11-r12-l03-linux-recovery/README.md).
The later [installed criterion review](../../docs/operations/evidence/2026-09-11-r12-l03-installed-auth/README.md)
verifies L02/L03 at I4 for the declared Ubuntu scope, including current-package
polkit negatives and explicitly bounded reuse of identical recovery components.
[Client source integration](../../docs/operations/evidence/2026-09-11-r12-linux-source-promotion/README.md)
has passed PR/main CI; coordinated Core promotion and signed desktop-package
acceptance remain open.
[Desktop fixes and packaging integration](../../docs/operations/evidence/2026-09-11-r12-linux-desktop-promotion/README.md)
subsequently passed signed PR/main CI at main `b7034e1`; native package results
below keep their own artifact identities and Linux acceptance remains open.

The [Ubuntu packaging source](packaging/README.md) supplies the GTK runner,
deb assembler and lifecycle hooks. A [native package and detached-signature
receipt](../../docs/operations/evidence/2026-09-11-r12-l04-linux-package/README.md)
binds the first signed candidate. The later [package-7 desktop evidence](../../docs/operations/evidence/2026-09-11-r12-l04-linux-desktop/README.md)
proves clean installation, real non-root GUI/polkit, installed permissions,
rollback, connected upgrade and uninstall/purge on Ubuntu 24.04.4 Xfce/X11.
Observed RU/full routes and IPv6 rejection pass; intermittent full-mode TLS
failures remain unresolved. The same package now passes crash, partial rollback,
actual sleep/resume and native reboot recovery on that guest; final acceptance stays open.
The later [package-8 DE-path investigation](../../docs/operations/evidence/2026-09-11-r12-l04-de-tcp/README.md)
reproduces curl35 alongside pending TCP handshakes: repeated SYNs appear at
MINI egress but not in the simultaneous DE capture. The loss cause is unknown;
successful no-VPN controls and other paths do not close this acceptance gate.
The [September12 lifecycle attempt](../../docs/operations/evidence/2026-09-11-r12-l04-de-tcp/README.md#2026-09-12-package-8-lifecycle-stopped-before-purge)
stops before purge because six traffic checks and system DNS fail. The exact
302-file package, profile, network and non-root GUI were restored. At that
September12 observation, the default DE delivery address was absent from DE
interfaces while node delivery/DNS still advertised it; MINI and Brain timed out.
The missing default address was restored by the separately authorized
September12 production incident recovery. The [September13 same-package recheck](../../docs/operations/evidence/2026-09-13-r12-l04-recheck/README.md)
now passes the default-DE path (six HTTPS) and bounded full/RU/DNS/IPv6 runtime
fixtures; all302 installed entries and profile/network restoration pass.
The alternate DE path still fails all six requests (one curl28/five curl35).
Production repair is no longer awaiting approval for that default address;
this does not close the separate alternate-path or final-package gates.
The [subsequent existing-US-path check](../../docs/operations/evidence/2026-09-11-r12-l04-de-tcp/README.md#exact-package8-connected-purge-and-separate-restoration-through-us)
passes exact package8 connected purge and network/state preservation. Automatic
apt reinstallation fails with an internal pathname error; separate same-byte
dpkg installation restores all302 files and the UID1000 GUI. The apt failure
and historical DE failures remain retained. Final Linux acceptance stays open.

- the non-root UI host, typed protocol, peer identity, polkit action, systemd
  units, fail-closed host matrix and secret-free journald envelope exist;
- every mutation now records one bounded authorization decision. Root peer
  credentials and the `pkcheck` wrapper over polkit D-Bus are distinct closed
  backends; allow, deny, missing agent, dismissed prompt, timeout and service
  failure map to allowlisted outcomes/error codes. PID, UID, process tuple,
  action details and diagnostic text have no journal field, while the IPC
  response remains the generic fail-closed authorization error;
- request-frame read, interactive authorization and response-write deadlines
  are separate, so a valid polkit prompt may outlive the input window without
  turning a completed mutation into a lost response;
- the daemon has a closed NetworkManager/resolved/nft transaction-event seam
  for `checkpoint`, `apply` and `rollback`. It accepts only typed
  subsystem/result values and emits transaction/correlation IDs, generation,
  stage, outcome and allowlisted failure code; commands, paths, destinations,
  raw errors and network material have no field;
- `connect` starts the fixed root-owned `/usr/lib/pokrov/pokrov-core` child.
  Core validates the private materialized profile before any network mutation
  and returns only a bounded `pokrov-linux-core-v1` plan over a private pipe;
- Core owns nonpersistent `pokrov0`, its fixed addresses and mark `0x504b`.
  linuxd owns route table/priority 20555, protocol 243 and metric 42700.
  Existing TUN/table/rule ownership conflicts reject connect. Core's private
  Linux context bypasses all sing-tun route/rule mutation, including the
  implicit IPv6 rule; addresses are assigned before system-stack listeners bind.
  Profiles cannot choose executable paths, TUN names, marks, namespaces or log
  files. A loopback mixed inbound is allowed; AWG endpoints and auxiliary
  services are outside this Linux profile boundary;
- the daemon persists its root-only recovery record, checks route ownership,
  and installs its atomic `inet pokrov` output filter before starting
  Core/TUN. It applies exact owned routes, then NetworkManager checkpoints
  only the newly created owned TUN, then
  resolved gets per-link DNS and `~.`; the NM checkpoint is committed last.
  Commands are fixed absolute executables with typed arguments and no shell;
- disconnect restores resolved and any pending NM checkpoint while TUN exists,
  removes exact owned routes, waits for Core's explicit stop acknowledgement,
  then deletes only its own
  nft table. A failed owner remains pending for retry; the traffic filter stays
  in place if earlier cleanup fails. No host ruleset is flushed;
- `/var/lib/pokrov/network-recovery.json` retains bounded ownership and pending
  cleanup, with mode 0600, atomic replacement and file/directory sync. Startup
  and unexpected Core exit resume cleanup. A live/replaced TUN, changed nft
  ownership or ambiguous route object blocks cleanup without deleting foreign
  state. A fresh boot with no owned nft table retires the old journal without
  acting on new-boot routes. Invalid journals remain for recovery;
- NetworkManager checkpoints are bound to its unique D-Bus owner. Restarted
  NM object paths cannot be mistaken for an older transaction's checkpoint;
- systemd sends the initial stop signal only to linuxd (`KillMode=mixed`) so
  Core cannot disappear before per-link cleanup. The socket unit owns its path
  and directory across daemon stop and socket reactivation;
- the installed sleep unit stops both socket and service before sleep and
  starts the daemon on resume, running journal recovery before IPC;
- Ubuntu 24.04 LTS amd64 with the required system stack is the only
  foundation-supported host row; the recorded package-7 desktop row is Xfce/X11
  with LightDM and the production polkit action;
- Fedora Workstation remains a package/runtime-proof backlog row;
- `supports_live_connect` reflects the required host stack and executable Core;
  `can_connect` additionally requires a staged profile, no active transaction
  and no pending recovery.
  Running follows actual Core start and network application. After that
  transaction, linuxd requests bounded DNS and selected-proxy HTTPS proof from
  its private Core child before completing connect. Both proofs must pass for
  the connected message; a failed or missing reply cannot produce healthy
  egress. Only the running session exposes those results, and stopped/error
  snapshots clear them. This is connection-establishment proof, not continuous
  reachability monitoring. Package 8 predates this behavior and returned unknown
  (`null`) health, leaving its GUI at “Проверяем…” despite working traffic;
- the shared desktop UI reads local daemon status every two seconds, without
  fetching a profile or repeating network probes. An external stop or recovery
  clears the cached running state. [Package-8 installed proof](../../docs/operations/evidence/2026-09-11-r12-l04-ui-status/README.md)
  shows the same non-root GUI switching to Retry/error after external Core
  SIGKILL, without an app click or restart. This fixes the observed stale
  package-7 GUI after daemon disconnect;
- retained VM proof covers non-root IPC, TUN/DNS/TLS HTTP, normal disconnect,
  foreign-rule rejection and active service stop/reactivation. Its temporary
  polkit fixture grant was removed. It is not a desktop authentication-agent,
  Flutter GUI, signed deb or public-candidate test. L03 additionally proves
  dual-stack traffic, crash/suspend/reboot restoration, partial rollback retry
  and real-agent authorization negatives. L04 adds real GUI authorization and
  exact package lifecycle and crash/suspend/reboot recovery proof. TLS
  consistency and final acceptance remain open L04 gates.

No Linux artifact or availability promise belongs to release 1.2.0 until those
gates and exact-package evidence close.
