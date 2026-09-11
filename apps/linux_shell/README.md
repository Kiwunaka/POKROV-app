# POKROV Linux conditional beta

[R12-L01 scope verification](../../docs/operations/evidence/2026-09-11-r12-android-abi-promotion/README.md#r12-l01--verified--i3--already_fixed)
confirms the existing Ubuntu 24.04 amd64 boundary and current capability against
main 57352ae source and CI. It closes the scope decision only; live runtime,
package and desktop-session acceptance below remain open.

This lane is a non-public foundation for the conditional Linux beta. The
Flutter UI always runs as the desktop user. Privileged VPN state belongs to the
systemd-activated `pokrov-linuxd` service and is never performed by the UI.

The IPC boundary is `/run/pokrov/pokrov-linuxd.sock`. Each request is bounded,
the daemon authenticates the kernel-provided Unix peer credentials, and every
mutating action requires `space.pokrov.linux.manage` through polkit. A world
connectable socket does not grant authority; it only makes the authenticated
system-service endpoint reachable without placing desktop users in a standing
privileged group.

Current source status is `IMPLEMENTED_PARTIAL`. The L02 live lifecycle is
implemented and [verified in an isolated Ubuntu VM](../../docs/operations/evidence/2026-09-11-r12-l02-linux-runtime/README.md);
durable recovery and signed desktop-package acceptance remain open:

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
- Core owns `pokrov0`, mark `0x504b`, route table 20555 and rule priorities
  20555–20565. Existing TUN/table/rule ownership conflicts reject preparation.
  Profiles cannot choose executable paths, TUN names, marks, namespaces or log
  files. A loopback mixed inbound is allowed; AWG endpoints and auxiliary
  services are outside this Linux profile boundary;
- the daemon installs its atomic `inet pokrov` output filter before starting
  Core/TUN. NetworkManager checkpoints only the newly created owned TUN, then
  resolved gets per-link DNS and `~.`; the NM checkpoint is committed last.
  Commands are fixed absolute executables with typed arguments and no shell;
- disconnect restores resolved and any pending NM checkpoint while TUN exists,
  waits for Core's explicit stop acknowledgement, then deletes only its own
  nft table. A failed owner remains pending for retry; the traffic filter stays
  in place if earlier cleanup fails. No host ruleset is flushed;
- systemd sends the initial stop signal only to linuxd (`KillMode=mixed`) so
  Core cannot disappear before per-link cleanup. The socket unit owns its path
  and directory across daemon stop and socket reactivation;
- Ubuntu 24.04 LTS amd64 with the required system stack is the only
  foundation-supported host row; exact desktop-session VM proof remains open;
- Fedora Workstation remains a package/runtime-proof backlog row;
- `supports_live_connect` reflects the required host stack and executable Core;
  `can_connect` additionally requires a staged profile and no active transaction.
  Running follows actual Core start and network application. DNS and egress
  health remain unknown (`null`); the UI must not infer validated health from
  the running phase alone;
- retained VM proof covers non-root IPC, TUN/DNS/TLS HTTP, normal disconnect,
  foreign-rule rejection and active service stop/reactivation. Its temporary
  polkit fixture grant was removed. It is not a desktop authentication-agent,
  Flutter GUI, signed deb or public-candidate test. Crash/suspend/reboot recovery
  and package acceptance remain L03/L04 gates.

No Linux artifact or availability promise belongs to release 1.2.0 until those
gates and exact-package evidence close.
