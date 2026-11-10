# POKROV Linux engineering host

The Linux host uses the shared Flutter shell and a separate privileged daemon. See [packaging](packaging/README.md) for the Ubuntu build path and the [platform runtime contract](../../docs/architecture/platform-privilege-runtime-contract.md) for ownership.

- The desktop UI runs as the signed-in user. The daemon uses a local socket, peer identity, typed requests and polkit for authorized mutations.
- The daemon owns the fixed installed Core child, TUN and the NetworkManager, systemd-resolved and nft transaction. It captures owned settings before changes and keeps a private recovery record under `/var/lib/pokrov`.
- Connect/cancel and replacement use the bound operation on the selected uplink. A request mismatch or expired deadline leaves the prior valid operation isolated. Stop restores owned DNS and routing before releasing the tunnel. Restoration failure stays visible and can be retried.
- The native daemon and package checks live in [daemon](daemon/) and [packaging](packaging/). The public client targets are described in the [repository map](../../docs/architecture/folder-structure.md).
