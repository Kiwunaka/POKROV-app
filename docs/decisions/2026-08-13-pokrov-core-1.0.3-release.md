# POKROV Core 1.0.3 Runtime Release

Status: accepted as the pinned Android and Windows runtime candidate on
2026-08-13. Client candidate and physical-device gates remain separate.

## Decision

POKROV clients pin the independently versioned custom runtime:

- repository: `Kiwunaka/pokrov-core`;
- public release: `https://github.com/Kiwunaka/pokrov-core/releases/tag/v1.0.3`;
- annotated tag: `v1.0.3`;
- source and release commit: `69a74545101708e56183c92e31f2b4c7b2509884`;
- desktop ABI: `2`;
- Go toolchain: `1.25.12`;
- embedded sing-box: `1.13.0`;
- `sagernet/sing`: `v0.8.0-beta.12`.

The client accepts only the exact published identities below. The backend
remains on Xray; client and server share protocol compatibility, not an
executable or release train.

## Artifact Contract

| Platform | Artifact | Size | SHA-256 | State |
| --- | --- | ---: | --- | --- |
| Android | `pokrov-core.aar` | `106861671` | `6e6f3b688fe415c9392e19aa4f8660885316897cfc369cf8c3ff3d01100ee14f` | four Android ABIs present; exact-client LDPlayer and physical-device proof remain candidate gates |
| Windows x64 | `pokrov-core.dll` | `55134208` | `7cc83854fc4022b759e9de3d0942b90a24c859cfd51e3231d04e7c7a6b7d5054` | repeated core build and exact client 100-cycle raw start/stop test passed; package and clean-machine proof remain candidate gates |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged pinned dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST`: build on macOS, sign, and prove on device |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST`: build on macOS and complete ABI/signing proof |

The machine-readable owner is `config/runtime-artifacts.seed.json`.

## Provenance And Behavior

The AAR and DLL were each built repeatedly from the tagged source with Go
1.25.12 and matched byte-for-byte after the release identity was fixed.
Release builds disable incidental VCS stamping with
`GOFLAGS=-buildvcs=false`. The public release includes the artifacts,
`release.json`, license files, third-party notices, and `SHA256SUMS.txt`.

This patch:

- bounds WARP profile initialization and exposes initialization failures;
- prevents WARP readiness and close paths from racing the materialized endpoint;
- sends current Cloudflare registration headers and rejects malformed replies;
- bounds selected endpoint and selected outbound latency probes;
- returns safe probe and socket-protection diagnostics to the client.

Android package identity, desktop ABI 2, embedded engine versions, and the
pinned Cronet dependency are unchanged.

## Release Gates

Android and Windows promotion still requires:

1. exact source commit, release tag, artifact size, and SHA-256 validation;
2. focused runtime and host tests;
3. package inspection proving the expected Core binary is inside the exact
   candidate artifact;
4. exact-candidate runtime smoke without upgrading emulator evidence into a
   physical-device claim;
5. `git diff --check` and no unintended retained artifact delta.

Physical Android traffic, Wi-Fi/LTE switching, airplane mode, sleep/resume,
permission revocation, Windows clean-machine behavior, trusted signing,
stores, Apple builds, and RU-origin evidence remain separate manual gates.

## Rollback

There is no hidden legacy runtime fallback. Rollback means pinning and
rebuilding an explicitly selected prior POKROV Core release so source,
artifacts, configuration, and evidence remain aligned.
