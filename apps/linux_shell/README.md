# POKROV Linux conditional beta

This lane is a non-public foundation for the conditional Linux beta. The
Flutter UI always runs as the desktop user. Privileged VPN state belongs to the
systemd-activated `pokrov-linuxd` service and is never performed by the UI.

The IPC boundary is `/run/pokrov/pokrov-linuxd.sock`. Each request is bounded,
the daemon authenticates the kernel-provided Unix peer credentials, and every
mutating action requires `space.pokrov.linux.manage` through polkit. A world
connectable socket does not grant authority; it only makes the authenticated
system-service endpoint reachable without placing desktop users in a standing
privileged group.

Current source status is `IMPLEMENTED_PARTIAL`:

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
- the current unavailable `connect` path emits three honest
  `checkpoint/unavailable` preflight events, one per required network owner,
  before the existing `linux_live_connect_unavailable` result. It does not emit
  synthetic `apply` or `rollback` success;
- a dormant typed transaction engine now implements a fixed NetworkManager
  system-D-Bus checkpoint, per-link resolved DNS/default-route settings and one
  atomic `inet pokrov` nftables output table. It accepts only a `pokrov*`
  interface, non-zero Core routing mark and validated IP resolvers, runs fixed
  absolute commands without a shell, and rolls dirty owners back in reverse
  order while retaining any failed owner for retry. The nft participant never
  flushes or restores the host ruleset;
- Ubuntu 24.04 LTS amd64 with the required system stack is the only
  foundation-supported host row; exact desktop-session VM proof remains open;
- Fedora Workstation remains a package/runtime-proof backlog row;
- live Core lifecycle does not yet supply or invoke that transaction plan, so
  no new network command is reachable from `connect`. Durable restart/suspend
  recovery, native Ubuntu 24.04 mutation/restoration evidence, package signing
  and VM proof also remain open;
- therefore the daemon returns `supports_live_connect=false` and rejects
  `connect` with `linux_live_connect_unavailable`.

No Linux artifact or availability promise belongs to release 1.2.0 until those
gates and exact-package evidence close.
