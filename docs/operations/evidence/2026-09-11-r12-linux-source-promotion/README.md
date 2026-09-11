# Linux L02/L03 client source integration — 2026-09-11

`PASS_SOURCE_INTEGRATION`: [PR #116](https://github.com/Kiwunaka/POKROV-app/pull/116)
merged signed client source `5485b5ae87f9e42c4eeb0f4e2ed5c724c80e1fe3`
into main `5eee49714426b9920f310f758bfd58b9ca3cad77`. The signed PR and merge
share tree `a770ab64a9fcb073d88405b7f851eb087a1722b3`. All active source,
configuration, scripts, tests and workflows match tested feature commit
`62dff5c8c07330c35a537fb4cada89cf15c28cb7`; evidence dependency closure adds
the referenced L01/Android ABI and ARM64 historical families.

Both exact-head CI runs passed the cross-repository contract, client/Android
tests and native Linux daemon tests/vet/build. The dispatch-only replay-ref
step was conditionally skipped and is not a pass claim. Main protection before
and after is identical: signed commits, strict required CI, enforced admins,
PR with zero required approvals under the existing owner-solo exception,
linear history and no force push/deletion. Independent review was not performed.

The Linux Core input remains `97ec91e3a74c96db3ce5c0c98364b715bf344964` on
its separate feature branch. Core main promotion is pending coordinated
artifact binding: current Android/Windows binaries remain bound to their old
source. This integration changes no release artifact or public pointer.
Signed deb, GUI approval and final Linux candidate acceptance remain open.

The [receipt](receipt.json) hashes the retained source, CI, merge and policy
captures. Runtime evidence remains [L02](../2026-09-11-r12-l02-linux-runtime/README.md)
and [L03](../2026-09-11-r12-l03-linux-recovery/README.md), with their original
candidate identities and limits unchanged. This source integration does not
turn fixture authorization into desktop approval or a Linux release.
