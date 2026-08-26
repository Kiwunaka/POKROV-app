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
- Ubuntu 24.04 LTS amd64 with the required system stack is the only
  foundation-supported host row; exact desktop-session VM proof remains open;
- Fedora Workstation remains a package/runtime-proof backlog row;
- live Core lifecycle, NetworkManager checkpoint/rollback, resolved/nft
  transactions, suspend/recovery, package signing and VM proof are not yet
  implemented;
- therefore the daemon returns `supports_live_connect=false` and rejects
  `connect` with `linux_live_connect_unavailable`.

No Linux artifact or availability promise belongs to release 1.2.0 until those
gates and exact-package evidence close.
