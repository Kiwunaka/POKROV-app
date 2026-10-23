# POKROV Runtime Engine

This package owns non-UI runtime materialization, native bindings and candidate
probes. [The repository map](../../docs/architecture/folder-structure.md) locates
its callers and platform hosts; [cutover readiness](../../docs/operations/cutover-readiness.md)
owns current binary and device acceptance.

Current scope:

- POKROV Core desktop ABI 2 negotiation for `Windows` and `macOS`
- artifact discovery from local host folders or `POKROV_CORE_ROOT`
- staging and starting a managed profile payload once a real config exists
- native runtime bridges for `Windows`, `Android`, and the partial `iOS` lane
- fail-closed capability/event ABI negotiation; the exact retained Core 1.0.3
  identity remains an explicit legacy mode, while current desktop Core requires
  the structured operational-event capability
- private, separate `awg2_lab` and `awg31_lab` boundaries for Android and
  Windows: an `awg` endpoint is accepted only with the exact contract ID/SHA,
  an enabled generation marker and `useIntegratedTun=false`; AWG 3.1 also
  requires its explicit endpoint contract ID. Host metadata is stripped before
  Core sees the sing-box JSON

Current limits:

- iOS still needs its complete built framework/device lane
- Apple signing, notarization, and store submission stay outside this package
- the package proves runtime wiring, not production rollout by itself
- AWG source/host tests do not prove an exact AAR/DLL, owned-server
  interoperability, physical-device behavior, battery/thermal behavior or
  mobile/RU-origin reachability

## Private candidate-probe builds

The loaded Core inventory recognizes `dnstt_vless_v1` so Core source `7a62031`
does not invalidate the existing transport features. Core's `1.2.14` version
alone does not imply this feature: older artifacts remain usable without it.
The App admits a DNSTT managed reserve only with this loaded capability plus
VLESS, an active Premium access window (including trial and lifetime manual
access), and the exact personal VLESS-to-pinned-DNSTT graph. A carrier cannot be
selected as a proxy on its own. The same checks apply to downloaded reserves
and protected cached material; ordinary country/Auto selection is unchanged.
This source support does not prove a packaged binary or network reachability.
Unknown features and malformed inventories still fail closed.

Managed Naive uses the loaded `singbox_naive_h2_v1` and TLS capabilities plus
the same active Premium gate. Online and cached material require authenticated
Naive on HTTPS 443 with certificate verification and an explicit TLS server name;
QUIC, UDP-over-TCP, detours and custom TLS options are rejected. Native Naive
has no `network` field, and Cronet negotiates H2 without a supplied ALPN list.
Naive participates in ordinary country/Auto selection and reports `naive` in
technical diagnostics. This source support does not establish packaged or
owned-server acceptance; those results belong in cutover readiness.

Cold selection tries one eligible Naive candidate after the first TCP candidate
and its IPv6/IPv4 sibling within the same direct-route group, before repeating
other TCP variants. Existing country, preferred primary, bridge-load ordering
and probe budgets remain in force. Earlier bridge attempts can still exhaust
the shared budget before the direct group is reached.

Ordinary catalogue probes require the additive Core candidate-probe API. Stage
the exact approved artifact and dependencies through the existing
[sync/packaging scripts](../../scripts/README.md), selecting one platform and
its manifest. Source commit, version, size and dependency checks remain required;
copying a library into an ignored slot is not a substitute for those checks.
Missing native probe APIs return unavailable, never a socket-only success.

Android 4180 uses the new AAR from Core `5364537` with
`-RuntimeArtifactsPath E:/POKROV-tools/temp/core-android-mobile-auth/runtime-artifacts.android.json`.
That override is required for repeat Android packaging. The default tracked
manifest was not updated and still retains the Windows Core 1.2.14 / `40356d4`
binding and matching Cronet. Do not apply the Android override to Windows or
restage Android from the older default binding.

The `warp_direct` policy requires local device registration, explicit consent
and `id=warp-direct:<install_id>`; account, license and backend WireGuard
material are rejected. It applies masking to WARP and replaces protected route
and DNS references while preserving explicit Direct rules. Registration keeps
its direct detour; the data endpoint omits it only for a bare Direct outbound,
which sing-box 1.14 cannot use as a detour. Configured Direct options are retained.
This materializer does not add WARP to automatic selection.

## Candidate failure details

The optional closed `probe_error` retains Core's attempted operation, cause,
logical owned target/request, observed HTTP status or OS error number, and
stage/operation/total timing. Android and Windows host cancellation and network replacement,
the selector's probe budget and Diagnostics details preserve that observation
without changing the terminal result. The ordinary D8 outbox keeps all candidate
outcomes and only the latest failure detail within its existing 8 KiB record limit;
local events retain each detail. Missing detail
means no observation; raw exceptions, destinations and response content are rejected.

If primary and reserve both fail, `probe_error.primary_error` keeps one additional flat primary snapshot, including its original stage and completion time. Validators allow exactly two targets and reject deeper nesting or unknown fields. Diagnostics shows the primary cause first and retains both in its existing details section; D8 preserves the pair only on the latest failed candidate, within the same record limit. A successful reserve retains the existing success behavior.
