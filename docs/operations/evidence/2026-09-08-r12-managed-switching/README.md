# Installed Windows managed-profile switching — 2026-09-08

PASS_BOUNDED for ordinary UI reconnect AWG 3.1 → AWG 2 → AWG 3.1 on the
existing disposable Windows 11 VM. Client source `6fc1e84`, Core `8dc57a8`,
and the exact v3 package from the [upgrade receipt](../2026-09-08-r12-upgrade-managed/receipt.json).
The [receipt](receipt.json) binds the retained observations and their original
local hashes. This is a local lab package, not a new release candidate.

The owner explicitly authorized all protocol tests and needed test profiles.
Only the existing exact-install cohort and its two lab gates were temporarily
changed. No entitlement or endpoint key material changed. All three guarded
Brain readbacks resolved the requested profile.

| Ordinary connection | Protected service profile SHA-256 | Observation |
| --- | --- | --- |
| AWG 3.1 first | `20ce76b31fbc16f2ae8f8f49c934a45325dc74fba82b0eaf4948218189fe0dfb` | `pokrov.awg31.endpoint.v1` |
| AWG 2 | `e6a2ef8faa7a04684c7cb5f522b4bcc21e5c1298572a2d2f9655714e116b10f8` | AWG2 server/persisted revision and endpoint shape |
| AWG 3.1 return | `20ce76b31fbc16f2ae8f8f49c934a45325dc74fba82b0eaf4948218189fe0dfb` | Exact first-file hash restored |

The sampler ran through normal guest UAC, read the service's protected profile,
and emitted hashes, contract IDs and field names only. It did not change ACLs
or export profiles. AWG2's existing renderer omits `contract_id`; an empty
contract list alone is not its identity proof. The ordinary account's persisted
revision changed to `awg2_lab:awg2-lab-v1` and back to the AWG31 generation.

Each steady observation reported running/Core/DNS/egress readiness, matching
staged/effective identity, one TUN, health 200 and successful DNS. Each UI
disconnect removed TUN, cleared effective protection and restored the same
route/DNS hashes. All 305 package files matched the original v3 manifest after
the tests. The installed diagnostic probe is unchanged; its `0218e89` source
label identifies the probe/service parent, not the newer UI source.

Independent route proof remains BLOCKED_BY_ACCESS. External egress hashes were
identical with and without the VM tunnel. Strict SSH rejected the DE host key;
the trusted Brain host had no matching saved target key. No trust record was
replaced and no verification was disabled. The owner was asked for an independently
verified fingerprint. Server peer counters and packet correlation were not run.
The UI retained the saved Milan location and unresolved access label while the
fixed lab transport was DE; full effective-location presentation is still open.

Executed commands: local `lab-control.py switch --profile awg31_lab`, then
`awg2_lab`, then `awg31_lab`, each with a unique evidence label; ordinary UI
connect/disconnect; guest `network.ps1 -Label routing-…`; elevated read-only
`read-profile.ps1`; guest `final-identity.ps1`; and
`lab-control.py restore --label restore-original`. Local controller:
`E:/r12-windows-routing-20260908/lab-control.py`. Failed preliminary sampler
launches are retained as limitations in the receipt; only successful outputs
support the profile comparison.

Cleanup PASS: full original rollout-config hash restored, temporary task absent,
sampler process count zero, guest shutdown completed, clone NIC set to none.
Host route/DNS hashes match the retained pre-lab baseline. Source VM and package
bytes remain preserved. No push, merge, release publication or deployment.
N01/W01 advance only for this installed switching slice; N03, crash/sleep,
WFP coexistence, Win10 and final candidate acceptance remain open.
