# Linux desktop source integration — 2026-09-11

`PASS_SOURCE_INTEGRATION`. [PR #117](https://github.com/Kiwunaka/POKROV-app/pull/117)
merged signed source `aa562fe2c54fac6340a3c37b33415c2345925bfc` into main
`b7034e141b52d51438a0923d3d24c59404695d3f`. The merge signature is verified
and both commits have tree `2b2e3858547ff9d09aac9ed6f82a926290fc1073`.
The [receipt](receipt.json) hashes the source, CI, merge and policy captures.

All active apps/packages/scripts/config/tests/workflows match tested feature
source `aa08746`. The 145-file candidate adds the conditional GTK/deb packaging
and fixes observed startup, profile materialization, authorization timeout,
full-device routing, IPv6 reject cleanup, private state mode and stale Linux
GUI status. Its evidence dependency closure is included.

Both [PR CI](client-ci-pr-ui-poll.json) and [main CI](client-ci-merge.json)
passed the cross-repository contract, client and Android-flavor tests, and
native Linux daemon tests/vet/build. The dispatch-only replay-ref step was
conditionally skipped; it is not a pass. Branch protection before/after is
identical: signed commits, strict required CI, enforced admins, linear history,
no force push/deletion and zero required approvals under the existing owner-solo
exception. Independent review was not performed.

[Package-7 proof](../2026-09-11-r12-l04-linux-desktop/README.md) retains its
signed clean install, actual GUI/polkit, permissions, connected package lifecycle,
crash/suspend/reboot and network results. [Package-8 proof](../2026-09-11-r12-l04-ui-status/README.md)
adds the updated UI's actual Core-loss response, signed upgrade and installed
payload readback. The candidate/preparation JSON captures predate package 8;
their pending native-UI label is historical, resolved by that later record.
Neither package's results are silently relabelled as the other one's.

Linux Core `97ec91e` remains a separate exact build input pending coordinated
Core promotion. Android/Windows Core904 bindings and release artifacts are
unchanged. The old full-mode TLS35 cause, complete Linux acceptance and final
release remain open. This source integration does not publish a Linux artifact
or change its public availability.
