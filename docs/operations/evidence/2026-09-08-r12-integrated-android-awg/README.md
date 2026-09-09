# Integrated Huawei AWG acceptance

Follow-up: **PASS_BOUNDED**. [Rule analysis](rule-final-analysis.json) explains
the original rule-hash gap below. Both changed lines differ only in `fwmark`
low 16 bits: 221 became 239, matching Android's current active default network
ID 239. Substituting the old number reproduces each original complete-line
SHA-256; priorities, masks, targets and every other byte match. Routes match,
VPN/TUN are absent. Exact raw rule hashes remain different; no stale VPN-rule
finding follows from this OS network renumbering. The original observations
and receipt are preserved without rewriting their results.

2026-09-08, **PASS_BOUNDED_WITH_RULE_RESTORE_GAP**. The [receipt](receipt.json)
binds ARM64 APK `88452b99…5850` (1.2.0+4053), client `7ae931b`, Core
`02a091c`, the physical Huawei Android 12 / SDK 31 and existing owned DE labs.
The local platform source tuple was not deployed; runtime control used the
existing brain backend. No new candidate or public activation was performed.

The owner authorized all test profiles on 2026-09-08. The current installation
was identified from the app account and the server device record refreshed by
opening its device list. Exact installation-hash preview matched, with a
one-second last-seen age. Model-name matching had selected an old record and
was not used for mutation. Only the confirmed installation entered the cohort.

Its material was 226.1 hours old, beyond the seven-day validity window.
Guarded reprovision rotated the old records without deleting them, created one
ready record per protocol and retained the same endpoint material. Entitlement
was unchanged. Each switch checked that shared defaults and other cohorts did
not select these labs, and compared the complete config before writing.

Ordinary reconnect applied AWG3.1, then AWG2, then AWG3.1 again. The app showed
working protection, foreground VPN service and TUN. Independent server inner
captures observed bidirectional TCP payload and a recent handshake:

| Phase | Capture | Outbound/inbound payload packets | Handshake age at end |
| --- | ---: | ---: | ---: |
| First AWG3.1 | 40 seconds | 159 / 196 | 30 seconds |
| AWG3.1 handover | 50 seconds | 143 / 138 | 31 seconds |
| AWG2 | 30 seconds | 118 / 138 | 21 seconds |
| Return AWG3.1 | 25 seconds | 62 / 56 | 17 seconds |

Fresh server/material alignment passed all 11 checks for each protocol,
including exactly one matching live peer, protocol fields and server key.
These counts prove traffic on the owned tunnel interface; they do not prove
full-device DNS/IPv6 leak exclusion or a complete MTU/UDP53 matrix.

AWG3.1 survived Wi-Fi → MOBILE → Wi-Fi with the same PID, foreground service,
VPN network agent and TUN. Protection was visible on mobile and restored Wi-Fi.
The 50-second server capture spans the sequence, so it is not a separate
cellular-only traffic measurement. An earlier parser failure is retained and
excluded from PASS.

The entire original rollout configuration was restored by hash, resolving to
`legacy_reality_fallback`; ordinary reconnect again showed working protection.
After an initial missed disconnect tap during sheet dismissal, the second tap
stopped VPN and removed TUN. Final installed APK hash matched; Wi-Fi and mobile
were enabled and the exact original route hash matched. Policy rules had the
same count (20), but two line hashes changed after handover. Their cause is
undetermined: **exact rule restoration remains open**, not PASS. Intermediate
samples immediately after stopping still contained four additional rules;
they were absent at the final observation.

Commands used the retained `lab-control.py` plan/switch/restore helper,
`reprovision.py`, `handover.py`, `sample-network.py`, SDK `adb shell input`,
`pm path`, `sha256sum` and `exec-out screencap -p`. Server checks used platform
`scripts/remote_count_owned_awg_packets.py` with `--capture-scope inner` and
`scripts/remote_audit_owned_awg_alignment.py`, strict known-hosts and explicit
local credential input. The first alignment invocation lacked the credential
path and stopped before remote access. No raw credentials, connection material
or identifiers are included here. Script and evidence hashes are in the receipt.

Full Android scope, outage/expiry/revocation, rule restoration, independent
leak/MTU/UDP53, sustained energy/soak and final release/channel gates remain open.
The phone is left with the same APK and VPN off. Refreshed lab material is
retained, but the temporary cohort and lab gates are back to their original state.

Verification: `pwsh -NoProfile -File scripts/validate-seed.ps1 -PlatformRoot
C:/Users/kiwun/Documents/ai/VPN-consolidated-plan-start -CoreRoot
E:/r12core-implementation`, `pwsh -NoProfile -File test/docs-contract.ps1`,
all 31 retained size/hash comparisons and `git diff --check` passed.
`git diff --name-only -- artifacts/releases` was empty. Existing generated
registrant changes were preserved outside this write set. No push or deploy.
