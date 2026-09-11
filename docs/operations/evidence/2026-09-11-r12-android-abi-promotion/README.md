# Android ABI source integration and Linux scope verification

2026-09-11. **PASS_SOURCE_INTEGRATION** for [PR115](https://github.com/Kiwunaka/POKROV-app/pull/115).
Local source `90337b33180b1600f0d6c25029627d0e9dc5b217`, GitHub-signed `b5f1edaf33b89c1577678ac862686ca154f09334` and merged main
`57352ae3bfc149c6e21e615b6f751b92dc2afff1` have the identical complete Git tree `fcb045f014e5883eae29147dd1a129bef06746e6`.
The reviewed diff contains only Android Gradle target ABI selection and its
owning documentation. The feature apps/packages/scripts/config objects matched merged main at source
readback. This later documentation update adds a Linux README evidence link;
it does not change runtime implementation.

Both [PR CI](https://github.com/Kiwunaka/POKROV-app/actions/runs/34568361963) and [main CI](https://github.com/Kiwunaka/POKROV-app/actions/runs/34569091378) completed successfully,
with executed cross-repository contract, client/Android flavor tests and Linux
test/vet/build steps. Each run used attempt 1. The dispatch-only ref validation
step is an expected conditional skip, not an executed pass. The Windows exact
candidate workflow was not dispatched or claimed for these sources.

Required checks, signed commits, strict branch freshness, PR-only integration,
admin enforcement, linear history, conversation resolution and disabled force
push/deletion remained unchanged. Signature and full-tree readbacks passed.
Independent review was not performed under the existing owner-solo exception.
One PR watch request failed with a network timeout; a fresh readback showed the
same job still running. Observation resumed without rerunning CI.

The existing [ARM64 APK receipt](../2026-09-11-r12-current-android-arm64/README.md)
retains its original compiled revision `90337b3` and SHA-256
`3ecff58793e0f6b354ce49eabd5f84f06052a92176cd12e4c5c7583a91cc41a0`. Tree equality does not relabel its diagnostics SHA.
No new package, installation, deployment, public pointer or release candidate
was created in this integration step.

## R12-L01 — VERIFIED / I3 / ALREADY_FIXED

This closes the original decision/scope DoD, not a Linux runtime or package
gate. R12-G01 is already verified. [Source review](l01-source-review.json)
compares 16 exact objects between feature, tested and signed sources; merge
adds a complete-tree equality check. Existing canonical owners are
[Linux README](../../../../apps/linux_shell/README.md) and the platform matrix.

| Original L01 requirement | Current evidence |
| --- | --- |
| One first beta distro/architecture | support-matrix.v1.json has exactly one foundation_supported row: Ubuntu 24.04 amd64; Fedora remains pending |
| Declared system prerequisites | Matrix names systemd, NetworkManager, systemd-resolved and nftables; README, polkit policy and authorization implementation require the closed manage action and interactive polkit for desktop mutations |
| Separate scope | platform-matrix.seed.json keeps Linux conditional; only Android/Windows are public release targets |
| Current capability reflects implementation | The daemon advertises supports_live_connect=false and returns linux_live_connect_unavailable; inspected connect code does not start Core or apply the dormant transaction plan |
| No public claim before its own gate | Linux owner explicitly keeps live Core, durable recovery, signed package and exact VM evidence open |

[Selected executed CI lines](linux-ci-pr-selected.log) and their
[binding](linux-ci-pr-binding.json) retain five Linux Flutter tests and successful
Go host/auth/service packages on the reviewed tree. These are fixture/source
checks. They do not prove installation, an interactive polkit agent, TUN/DNS,
network restoration or a supported Ubuntu desktop session.

L02/L03/L04 remain open; Fedora, aarch64 and per-app have no new availability
claim. No host OS, service, firewall, account or desktop environment was changed.
The full R12 and supplementary objective remains open.

## Retained verification

[Receipt](receipt.json) binds the captures; [validation](validation.json) records
final client seed/docs, platform docs/context, work-package links and diff checks.
Source integration used promote.py, verify-ci.py for PR and merge heads,
merge.py with match-head-commit, and capture-linux-ci.py. No forced push,
admin merge bypass, paid option or LFS upload was used.
