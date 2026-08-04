# POKROV Core 1.0.2 Runtime Release

Status: accepted for the Android and Windows client lanes on 2026-08-04.

## Decision

POKROV clients pin the independently versioned custom runtime:

- repository: `Kiwunaka/pokrov-core`;
- public release: `https://github.com/Kiwunaka/pokrov-core/releases/tag/v1.0.2`;
- annotated tag: `v1.0.2`;
- source and release commit: `a469240dc3e1e1736ff73348b113f164c277492a`;
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
| Android | `pokrov-core.aar` | `106832036` | `e98861ec0b658304515c04af6ab98a60f3664f8b5eb7660b57e6f0baa0df385f` | four Android ABIs present; LDPlayer exact-runtime smoke passed; physical-device proof remains manual |
| Windows x64 | `pokrov-core.dll` | `55122944` | `b6d4e28b5fb9d475acc623fed84d2009137a55972a841216a81ae6ac45f98305` | required exports and exact client 100-cycle gate passed; exact release bundle remains required before public promotion |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged pinned dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST`: build on macOS, sign, and prove on device |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST`: build on macOS and complete ABI/signing proof |

The machine-readable owner is `config/runtime-artifacts.seed.json`.

## Provenance And Behavior

The AAR and DLL were each built twice from the tagged source with Go 1.25.12
and matched byte-for-byte. Release builds disable incidental VCS stamping with
`GOFLAGS=-buildvcs=false`.

This patch replaces the inherited public default URL-test target with
`https://api.pokrov.space/api/public/authenticated-egress-probe`. Explicit
caller-provided targets remain unchanged. Android package identity, desktop
ABI 2, embedded engine versions, and the pinned Cronet dependency are
unchanged.

The Android AAR contains `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64`.
The Windows DLL exports `pokrovCoreAbiVersion` and `pokrovSecureFile`.

## Release Gates

Android and Windows activation requires:

1. exact source commit, release tag, artifact size, and SHA-256 validation;
2. focused runtime and host tests;
3. package inspection proving the expected Core binary is inside the exact
   candidate artifact;
4. exact-candidate runtime smoke without upgrading emulator evidence into a
   physical-device claim;
5. `git diff --check` and no unintended artifact delta.

Physical Android traffic, Wi-Fi/LTE switching, airplane mode, sleep/resume,
permission revocation, signing, stores, Apple builds, and RU-origin evidence
remain separate manual gates.

## Rollback

There is no hidden legacy runtime fallback. Rollback means pinning and
rebuilding an explicitly selected prior POKROV Core release so source,
artifacts, configuration, and evidence remain aligned.
