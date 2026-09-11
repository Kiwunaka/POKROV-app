# L02 live Linux Core integration — 2026-09-11

`PASS_BOUNDED`: actual Core/TUN and daemon network transactions on an isolated
Ubuntu 24.04 amd64 VM. This is development source/runtime proof, not a signed
Linux beta, final candidate, desktop-agent or Flutter GUI acceptance.

[Receipt](receipt.json) binds Core base `904e440`, client base `11aaaab`, exact
working source hashes, the binaries and final unit. Core revision 02 is
`2a15dd18` (54,886,526 bytes, Go 1.26.8); daemon revision 03 is `d13e0bcb`
(4,572,415 bytes, Go 1.25.13). The final service unit is `f987f2d8`.
Installed files were copied into the task-owned VM from those exact builds;
this was not a deb install or a production deployment.

## Observed behavior

[Runtime receipts](runtime-receipts-04.json) preserve both failed and corrected
runs, plus the daemon's closed journald fields. The final `live-04` run proves:

- ordinary UID 1000 IPC stages the profile and starts actual Core/TUN;
- the system resolver receives the fixed owned test-domain answer through
  Core's DNS path, and HTTP receives its marker through the TLS Trojan fixture;
- normal disconnect restores nftables, IPv4/IPv6 rules/routes, resolved DNS and
  domains, and removes the owned TUN;
- stopping the active systemd service restores the same state and leaves no
  Core/TUN; the socket remains usable, reactivates the daemon and supports
  another connect/disconnect with restoration.

The earlier `lifecycle-02` and `lifecycle-03` runs also prove that an injected
foreign rule at priority 20555 rejects preparation without changing host state
or leaving a child. Only that exact fixture rule was then removed. Route
comparison in the final run ignores only the observed RA `expires` countdown;
all route identities, metrics, flags and other fields remain in the hash.

The first stop test exposed systemd's default group-wide SIGTERM stopping Core
before resolved rollback. `KillMode=mixed` fixed the ordering. The next test
exposed loss of the socket directory: linuxd now keeps the inherited socket
path, and the socket unit alone owns its directory. Initial failure required
an orderly QEMU ACPI shutdown/restart of the isolated VM; its disk and failed
receipts were retained. This recovery action is not L03 reboot-recovery proof.
The [systemd 255 contract](https://github.com/systemd/systemd/blob/v255/man/systemd.kill.xml)
documents the signal behavior used by the fix.

## Authorization and isolation

Successful non-root mutations used `FIXTURE_GRANT`, a temporary rule restricted
to the task user and POKROV action inside this guest. Production policy denial
passed [before](guest-nonroot-baseline.json) and
[after removal](production-policy-restored.json). No desktop auth-agent success
is claimed. [Guest return state](return-state-04.json) confirms no TUN, Core or
owned nft table remains, and the fixture grant was retired.

The TLS fixture listened only on the QEMU host loopback, verified a generated
private password, and served fixed synthetic DNS/HTTP responses. It did not
forward destinations. TLS certificate verification remained enabled; private
keys, profiles and passwords stayed in owner-only fixture storage outside Git
and evidence. [Host return state](host-return-04.json) proves unchanged host
routes, rules and nftables and confirms the fixture listener was stopped.

## Verification and limits

- Native Core: `go test -p 1 ./v2/linuxruntime`, focused tagged vet and Linux
  executable build: [PASS](current-build-02.log).
- Native daemon Go 1.25.13: `go test -p 1 ./...`, `go vet -p 1 ./...`,
  `go build ... ./cmd/pokrov-linuxd`: [PASS](daemon-build-03.log).
- Runtime Flutter analyze: [PASS](flutter-runtime-analyze.log). Three focused
  Linux runtime tests passed in the tool run before native acceptance.
- Linux shell: five tests [PASS](flutter-linux-shell-tests.log); after the unit
  fixes, four focused packaging tests [PASS](flutter-packaging-04.log).
- DNS/egress snapshot health stays `null`; running alone is not validated
  health. The live fixture proves this slice, not arbitrary provider profiles.
- AWG endpoint profiles, crash/suspend/reboot recovery, durable retry state,
  desktop polkit/UI and signed install/update/remove remain outside this proof.
- Android/Windows release artifacts were not changed or rebuilt for L02.

The complete consolidated release/post-release objective remains open.
