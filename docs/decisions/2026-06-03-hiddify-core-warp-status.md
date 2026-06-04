# Hiddify Core And WARP Status

Date: 2026-06-03
Status: implementation fact / product-claim guard
Decision owner: owner/operator

## Summary

The active client lane is based on pinned `hiddify-core v3.1.8` artifacts, but
WARP is not a product-ready POKROV feature yet.

The runtime currently contains Hiddify-style options with `warp` and `warp2`
configuration blocks, both disabled by default. The app shell must not present
WARP or an enhanced privacy mode as working until UI wiring, account/config
inputs, runtime start behavior, and live platform verification are complete.

## Current Runtime Base

The pinned runtime artifact contract lives in:

- `config/runtime-artifacts.seed.json`

Current contract:

- repository: `hiddify/hiddify-core`
- release tag: `v3.1.8`
- Android asset: `hiddify-core-android.tar.gz`
- Android entry: `libcore.aar`
- Windows asset: `hiddify-core-windows-amd64.tar.gz`
- Windows entry: `libcore.dll`

The Windows release contract is `libcore` only. It does not expect or bundle a
Windows `HiddifyCli.exe` helper in the current lane.

## Platform State

Android:

- host shell uses `libcore.aar`
- Android runtime lane can initialize libcore and stage a managed profile
- physical release-build localhost/control-surface verification remains a
  release gate, not proof to skip forever

Windows:

- host shell uses `libcore.dll`
- desktop lane applies Hiddify-style runtime options before `libcore start`
- current seed prefers system proxy mode:
  - `set-system-proxy: true`
  - `enable-tun: false`
- Windows package verification expects `pokrov_windows_beta.exe` and
  `libcore.dll`

## WARP Runtime Options

The shared runtime options builder currently includes:

- `warp`
- `warp2`
- default mode: `proxy_over_warp`
- default `enable: false`
- empty WireGuard/account/license fields by default

The client now has the first guarded WARP policy bridge:

- public `client_policy.warp_policy` is sanitized metadata only;
- authenticated managed profiles may carry backend-provisioned
  `warp_policy.wireguard_config` and `warp_policy.account` material only when
  `runtime_ready=true`;
- `ManagedProfilePayload.warpPolicy` carries that policy to the runtime layer;
- the Home tile can load readiness and show a separate consent sheet only when
  the managed policy is runtime-ready;
- desktop runtime options map a runtime-ready policy into Hiddify `warp`
  options only when local `userConsented=true`; without consent, or with an
  incomplete policy, `enable=false`.

This means the runtime options surface can accept WARP-like settings, but it
still does not mean the POKROV app has a working WARP product flow.

Missing before product-ready support:

- live backend provisioning policy for real WARP account/config material
- safe storage and rotation policy for any license/account/access-token fields
- platform-specific runtime verification on Android and Windows
- compatibility rules for route mode and Russian-service bypass
- speed and failure-mode tests
- honest copy and support documentation

## Product Claim Rule

Allowed now:

- internal implementation note: `hiddify-core` has disabled WARP option blocks
- UI future/disabled note behind Advanced, if needed

Forbidden now:

- showing WARP/enhanced as an active Home control
- claiming WARP is supported by POKROV
- claiming additional anonymity or stronger privacy from WARP
- marketing WARP until live proof exists

When implemented and verified, the normal UI should use product wording such as
`Расширенная защита` or `Дополнительная приватность`. The literal `WARP` brand
should stay in advanced/support documentation only when needed for technical
clarity.
