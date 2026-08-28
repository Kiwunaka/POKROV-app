# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: refreshed on 2026-08-28 as a single-source Android/Windows
pre-candidate binding for POKROV `1.2.0+4046`. Both active platform artifacts
now carry the Core egress, AWG and default-off Hysteria2 corrections from one
exact revision.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- Android and Windows source commit: `e8eb7721fc6eaac6813d3a888ac90d0da1f541a1`;
- source state: `PRE_CANDIDATE_LOCAL`;
- candidate created: `false`;
- desktop ABI: `2`;
- capability descriptor schema: `1`;
- structured event ABI: `1`;
- Go toolchain: `go1.25.13`;
- gomobile: `0.1.11`;
- embedded sing-box: `1.13.0`;
- `sagernet/sing`: `v0.8.0-beta.12`.

`config/runtime-artifacts.seed.json` is the machine-readable owner. It keeps
the retained public Core `1.0.3` identity separate from the new local bytes.
The retained release remains rollback/history truth and is not relabelled as
`1.1.0`. Core PR `#2` records the earlier binding; this refresh remains on the
scoped release branch until its own owner-solo promotion evidence is recorded.

## Exact Artifact Contract

| Platform | Artifact | Size | SHA-256 | Local result |
| --- | --- | ---: | --- | --- |
| Android | `pokrov-core.aar` | `107390782` | `7c392883ee8a09c15e414a0e9d70a4d4d3cb259032e51c5481cd14a571950745` | two byte-identical local builds from `e8eb772`; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55403008` | `73aacd2ccbb3414573284c0c2a253f29c6ed4a56ddf2ff8bb6cc9ae7ca371488` | two byte-identical local builds from `e8eb772`; 15 required exports present |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged retained dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST` |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST` |

Android is bound by package `space.pokrov.core`, its exact source commit and AAR
digest. Windows is bound by the same source commit, desktop ABI `2`, exact DLL
digest and exact Cronet dependency. This closes the local platform-source
convergence prerequisite; candidate and physical-platform gates remain open.

## Reproducibility, SBOM And Provenance

Fresh Android and Windows two-build evidence and deterministic source SBOMs
bind the same Core source. Packaged-client candidate provenance remains open:

| Evidence | Result / SHA-256 |
| --- | --- |
| Android build tree | `aafd5f0eb2a83f7c438affb32c946af17b77593e9e0f5105b7f7b1d293e2f8f3` |
| Android evidence JSON | `37926b9c4101fd7b69580b7e184c764fc0e365be22dab6c87b7620bf855789eb` |
| Windows build tree | `25405fd108405f56c08c5a24f88a2b45a6936ff14eae4f113b2e7e71f08eb78c` |
| Windows evidence JSON | `4f5c33fd252dd21a52813cf227a2c4c2b4e0e228d9410dd3a40f651e83b773d5` |
| `pokrov-core.cdx.json` | `d40547fa3ba28c84bf377e6cb8d174546ea75f41287028ca2e97931cd7ebfb9b` |
| `sing-box.cdx.json` | `83bc11b4b90e267346647670f6ce4003d9586ed4519b7bca076e84c3127ce542` |

The Windows refresh used the local LLVM-MinGW `20260616` UCRT toolchain already
present in the isolated build directory. The toolchain directory was passed
only to the build process; no system compiler installation or persistent
environment change was made. Final candidate provenance must additionally pin
the compiler archive identity rather than promote this local statement to a
supply-chain `PASS`.

CycloneDX generation completed with declared warnings where local forks or
standard-library modules had no detected license metadata. The SBOMs and their
hashes are provenance inputs; they are not legal clearance. Every warning must
still be resolved or explicitly accepted before promotion.

## Evidence Ceiling

The strongest claim from this decision is
`clean_reproducible_pre_candidate_local`:

- exact Android and Windows runtime bytes from one source commit are bound;
- Android four-ABI presence and Windows ABI exports are proved locally;
- the Windows proxy-only harness passed 100 start/stop cycles without changing
  system routes;
- Windows TUN, DNS capture and leak protection were not exercised by that
  host-safe harness;
- no artifact is signed, tagged, uploaded, published or promoted;
- no physical Android, clean Windows VM, Apple, current-origin, brain-origin or
  RU-origin gate is closed.

## Superseded Android Binding Evidence

The previous exact Android AAR from Core `f234bb6…c171`, size `107392318` and
SHA-256 `ce11d3d…51b8`, remains retained evidence for builds 4041/4042. It is no
longer the active binding. Production-signed build 4042 used that AAR with an
app-side global interface-auto-detection experiment; LDPlayer failed at Core
service start with no owned-server AWG packet. Build 4042 is rejected, not a
candidate or pass. The active 4044 source keeps global auto-detection disabled
and moves the exception into the Core-owned AWG outer socket.

## Remaining Candidate Gates

Before these bytes may become a release candidate:

1. inspect the resulting Android and Windows packages and bind their Core
   digests into strict-v2 metadata;
2. run hosted CI on every frozen revision;
3. complete exact-candidate Android physical-device and Windows clean-host
   TUN/DNS/egress/recovery gates;
4. complete production signing, provenance review and public-index binding;
5. keep publication, runtime synchronization and promotion blocked until the
   separately authorized go/no-go step.

## Rollback

There is no hidden runtime fallback. Before candidate promotion, rollback means
restoring the exact retained public Core `1.0.3` contract and rebuilding the
client from an explicitly selected clean source revision. After a candidate is
created, rollback must use the versioned release catalog and same-byte evidence;
it must not rewrite these `1.1.0` bytes under an older identity.
