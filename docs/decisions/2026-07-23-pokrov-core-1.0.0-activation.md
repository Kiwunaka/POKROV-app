# POKROV Core 1.0.0 Runtime Activation

Status: accepted for the Android and Windows client lanes on 2026-07-23.

## Decision

POKROV clients use the independently versioned `POKROV Core` repository:

- repository: `Kiwunaka/POKROV-core`;
- release: `v1.0.0`;
- source commit: `3720cb052e56ccd68f0120cc9efaf5804ec84e0b`;
- desktop ABI: `2`;
- Go toolchain: `1.25.12`;
- embedded sing-box: `1.13.0`;
- `sagernet/sing`: `v0.8.0-beta.12`.

The runtime is now a POKROV-owned source tree, build pipeline, package namespace,
ABI, artifact set, and release line. The client does not download or accept an
unverified substitute at runtime.

The server remains on Xray. Client and server share protocol compatibility, not
an executable or release train.

## Runtime Scope

POKROV Core owns:

- raw sing-box configuration startup and restart;
- Android and desktop bindings;
- WARP/WireGuard support;
- lifecycle, resolver, routing, and host callbacks;
- Reality/TCP TLS fragmentation support;
- private runtime-config handling;
- the desktop ABI marker and caller-owned string lifecycle.

The client owns profile retrieval, route-mode and WARP policy materialization,
host VPN permissions, platform lifecycle, and user-facing state.

## Included Fixes

Version 1.0.0 includes the fixes already backtested in the migration branch:

- cached-connection close race fixed by `sagernet/sing v0.8.0-beta.12`;
- WireGuard shutdown ordering prevents the endpoint callback race;
- TLS fragmentation wraps standard TLS, uTLS, and Reality client handshakes;
- desktop strings are caller-owned and released through `freeString`;
- staged raw configuration is not duplicated or logged in full;
- private config files use restricted permissions, including Windows ACLs;
- non-raw option handling rejects an absent options object cleanly;
- `ipv4_only` is enforced instead of silently ignored.

Future reference updates are reviewed as individual changes. Public reports and
other implementations are research inputs, not an automatic upstream merge.
Each imported fix needs a local reproducer, focused test, and exact-artifact
backtest.

## Artifact Contract

| Platform | Artifact | SHA-256 | State |
| --- | --- | --- | --- |
| Android | `pokrov-core.aar` | `ca3ee922ff10897545da86ea3aa6df942ecf36d7f687b2782b0bc285e9a15cb3` | local build and host contract pass; physical-device proof pending |
| Windows x64 | `pokrov-core.dll` | `4587448c7eec4bf9ec70508f698764a71dfa7318baeebc9598a41b79f7dc4e2d` | local build, ABI/export probe, and host contract pass |
| Windows dependency | `libcronet.dll` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | pinned with the Windows runtime |
| iOS | `PokrovCore.xcframework` | — | `MANUAL_OWNER_TEST`: build on macOS, sign, and prove on device |
| macOS | `pokrov-core.dylib` | — | `MANUAL_OWNER_TEST`: build on macOS and complete ABI/signing proof |

The machine-readable owner is `config/runtime-artifacts.seed.json`.

## Release Gates

Android and Windows activation requires:

1. exact source commit, version, artifact size, and SHA-256 validation;
2. focused runtime, Android host, and Windows contract tests;
3. the exact Windows DLL 100-cycle start/stop backtest;
4. no obsolete branded identifier in the promotion tree or native payloads;
5. `git diff --check` and no unintended `artifacts/releases/**` delta.

Physical Android traffic, Wi-Fi/LTE switching, airplane mode, sleep/resume,
permission revocation, blocked UDP/53 with DoH, and RU-origin Reality/TCP
fragmentation remain manual exact-candidate checks. They are not converted into
local passes.

Apple activation is not claimed by this decision.

## Rollback

There is no hidden legacy runtime fallback. Rollback means reverting the client
activation commit and rebuilding an explicitly selected prior POKROV candidate.
That keeps the executable, configuration contract, and evidence from silently
drifting apart.
