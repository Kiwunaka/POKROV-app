# R12-L03 — bounded Linux recovery and authorization proof

Status: `implemented / I3 / PASS_BOUNDED`. This is source and owned Ubuntu
24.04 amd64 VM evidence for the conditional Linux lane. It is not a signed
deb, Flutter desktop-session acceptance, promoted candidate or public release.

Core commit `97ec91e` delegates policy routes to linuxd. The daemon persists
root-only recovery ownership before mutation and restores exact routes,
per-link DNS/NM state and its nft table after normal or interrupted operation.
The source and binary hashes are in [receipt.json](receipt.json). Core revision
08 was built with Go 1.26.8; daemon revision 09 with Go 1.25.13. No Android or
Windows artifacts were rebuilt or rebound.

| Check | Result | Retained evidence |
| --- | --- | --- |
| Core profile tests, Linux vet and build | PASS | [Core build](current-build-08.json), [log](current-build-08.log) |
| All daemon package tests, vet and build | PASS | [Daemon build](daemon-build-09.json), [log](daemon-build-09.log) |
| Non-root IPC, IPv4/IPv6 DNS and TLS HTTP | PASS | [Runtime](l03-live-03.json) |
| Disconnect and foreign same-priority rule preservation | PASS | [Runtime](l03-live-03.json) |
| Partial rollback retains journal/filter and rejects profile mutation; retry succeeds | PASS | [Runtime](l03-live-03.json) |
| Core SIGKILL and daemon SIGKILL/restart; reconnect | PASS | [Runtime](l03-live-03.json) |
| Actual suspend, resume restoration and reconnect | PASS | [VM power](sleep-qmp-02.json), [guest](l03-sleep-02.json), [systemd](suspend-service.log) |
| Connected reboot, new boot identity, restoration and reconnect | PASS | [Reboot](l03-reboot-01.json) |
| Production-policy non-root denial | PASS | [Return state](l03-return-state.json) |
| Missing agent and 60-second real-agent timeout | PASS | [Missing agent](l03-auth-missing.json), [timeout](l03-auth-timeout.json), [events](operational-events.json) |
| Host routes/rules/nft unchanged; listener stopped | PASS | [Host return](host-return-state-verified.json) |

Traffic tests used a temporary guest-only polkit grant. Negative agent tests
used a separate `AUTH_SELF` fixture condition for the same action/user and real
`pkttyagent`; no credentials were entered. Terminal EOF produced a PAM denial,
not the graphical-cancel branch. Both fixture conditions were retired and the
unchanged production policy was tested again. GUI authentication success remains
part of desktop/package acceptance.

The network comparison keeps all fields except the observed IPv6 RA `expires`
countdown. Resume waits for NetworkManager to restore its dynamic uplink route;
it must converge to the complete original state. The sleep02 helper's
`resume_settle_seconds` and sample fields were overwritten by its final cleanup
wait, so they are not used as resume latency evidence. Its restoration,
same-boot and reconnect assertions remain valid.

Earlier failed attempts are retained:

- Core06 skipped link addresses before system-stack listener bind; connect
  rejected and fully restored state: [first run](l03-live-01.json).
- The initial route matcher expected text `link`, while `ip -N` emits scope
  `253`: [route shape](route-shape.json). This blocked rollback after dual-stack
  traffic in [run02](l03-live-02.json). The corrected matcher has a native-format
  regression test; run03 passed. An ACPI shutdown/restart recovered the failed
  run's old journal without modifying new-boot routes.
- Core07's wrong netlink import failed vet; [build log](native-build-07.log).
  Core08 uses the repository's existing sagernet/netlink dependency.
- [Sleep01](l03-sleep-01.json) sampled the dynamic IPv6 route before NM settled;
  the [later complete route state](post-resume-route6.json) matched baseline.
  Sleep02 waits for convergence and passes.

Executed commands include native `go test -p 1 ./...`, `go vet -p 1 ./...`,
the exact build commands retained above, `flutter test --no-pub` from the Linux
shell (5 passed), `pwsh -NoProfile -File test/docs-contract.ps1`, and the scoped
VM harnesses retained under `E:/r12-l03-linux-recovery-20260911/`.
Private profiles, TLS keys and passwords were never copied into this evidence.

VM return state has no Core, TUN, owned nft table or recovery journal; the
daemon is idle behind the socket. The sleep/service/socket units remain
installed and enabled for the next package acceptance step. Source promotion,
signed packaging and final Linux candidate acceptance remain open (L04).
