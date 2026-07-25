# POKROV Core 1.0.1 Runtime Release

Status: accepted for the Android and Windows client lanes on 2026-07-25.

## Decision

POKROV clients pin the independently versioned custom runtime:

- repository: `Kiwunaka/POKROV-core`;
- public release: `https://github.com/Kiwunaka/pokrov-core/releases/tag/v1.0.1`;
- annotated tag: `v1.0.1`;
- source and release commit: `3c256e5560220f2b4233d72ed057d1b72e8d3ad5`;
- desktop ABI: `2`;
- Go toolchain: `1.25.12`;
- embedded sing-box: `1.13.0`;
- `sagernet/sing`: `v0.8.0-beta.12`.

The client accepts only the exact published artifact identities below. It does
not download an unverified substitute at runtime. The backend remains on Xray;
client and server share protocol compatibility, not an executable or release
train.

## Artifact Contract

| Platform | Artifact | Size | SHA-256 | State |
| --- | --- | ---: | --- | --- |
| Android | `pokrov-core.aar` | `106831626` | `25b96622f9ef6e648e1167847ef4205c63bad88c7c897e862bf36249830114e3` | four Android ABIs present; ARM64/ARMv7 tester APK and AAB carry the exact published ELF identities; physical-device proof pending |
| Windows x64 | `pokrov-core.dll` | `55117824` | `8f4aa233054b78ac2e6dbcef7634b6f4829a9f27f4cd65674de80f6f3b299f9e` | exports, ABI probe, and 100-cycle raw start/stop test passed |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | pinned with the Windows runtime |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST`: build on macOS, sign, and prove on device |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST`: build on macOS and complete ABI/signing proof |

The machine-readable owner is `config/runtime-artifacts.seed.json`.

## Provenance

The AAR and DLL were rebuilt repeatedly from the tagged source and remained
byte-identical. Release builds disable incidental Go VCS stamping with
`GOFLAGS=-buildvcs=false`; source identity is the annotated tag and the GitHub
release commit. `go version -m` reports Go 1.25.12 without a drifting `vcs.*`
payload.

The Android AAR contains `armeabi-v7a`, `arm64-v8a`, `x86`, and `x86_64`.
The client release packaging preserves `libpokrov-core.so` without Gradle
section-table rewriting, so the ARM64 and ARMv7 ELF size and SHA-256 values
inside the tester APK/AAB match the AAR entries byte-for-byte.
The Windows DLL exports `freeString`, `pokrovCoreAbiVersion`, and
`pokrovSecureFile`. Core tests and the exact DLL 100-cycle raw start/stop test
passed before publication.

This removes the dirty-build provenance exception attached to the superseded
1.0.0 client candidate.

## Client Release Gates

Android and Windows activation requires:

1. exact source commit, release tag, artifact size, and SHA-256 validation;
2. focused runtime, Android host, and Windows contract tests;
3. package inspection proving that the expected Core binary is inside the
   exact tester artifact;
4. no obsolete branded identifier in the promotion tree or native payloads;
5. `git diff --check` and no unintended release-artifact delta.

Physical Android traffic, Wi-Fi/LTE switching, airplane mode, sleep/resume,
permission revocation, blocked UDP/53 with DoH, and RU-origin Reality/TCP
fragmentation remain manual exact-candidate checks. Internal debug signing may
be used only for an explicitly labeled tester prerelease; it is not a
production or store-signing claim.

Apple activation is not claimed by this decision.

## Rollback

There is no hidden legacy runtime fallback. Rollback means reverting the client
pin and rebuilding an explicitly selected prior POKROV candidate. This keeps
the executable, configuration contract, and evidence aligned.
