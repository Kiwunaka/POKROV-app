# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: refreshed on 2026-08-28 as a mixed exact-platform pre-candidate binding
for POKROV `1.2.0+4044`. Android carries the Core egress-event, AWG endpoint DNS
and bounded outer-socket protection corrections; Windows retains the previous
exact DLL until rebuilt.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- Android source commit: `54e76bbb61f79bd0eb0cdbddb71f52e12645fa13`;
- retained Windows source commit: `344b317a7a09eca7943a93866b193553538bd8f6`;
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
| Android | `pokrov-core.aar` | `107394593` | `ca391059b6676de5a2cfbf582395fd7ab0b0b5979c8a0c40faaa7208b79178e5` | two byte-identical local builds from `54e76bb`; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present; focused AWG/dialer tests and the full Core gate pass |
| Windows x64 | `pokrov-core.dll` | `55401472` | `60fe3fad7835ec4d00c1f7168bb0ba01dd6b7ca5d883583340e5e2a86b8b3981` | retained exact bytes from `344b317`; two byte-identical builds; 15 required exports present; exact-DLL proxy-only 100-cycle start/stop PASS |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged retained dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST` |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST` |

Android is bound by package `space.pokrov.core`, its exact source commit and AAR
digest. Windows is bound separately by its retained source commit, desktop ABI
`2`, exact DLL digest and exact Cronet dependency. Candidate promotion remains
blocked until both active platform artifacts converge on one Core source.

## Reproducibility, SBOM And Provenance

The retained Windows artifact keeps its earlier two-build reproducibility
evidence. The corrected Android AAR also has two byte-identical local builds;
replacement SBOM and packaged-client provenance remain pending:

| Evidence | Result / SHA-256 |
| --- | --- |
| Android build comparison | `PASS_BYTE_IDENTICAL_TWO_BUILDS`; AAR SHA-256 `ca391059b6676de5a2cfbf582395fd7ab0b0b5979c8a0c40faaa7208b79178e5` |
| Android evidence JSON | `NOT_GENERATED_SEPARATELY` |
| Windows build tree | `e12123eb9d6c7bd83a3c95ac4f864583219c37d6b98dfd283fc6f4deda099516` |
| Windows evidence JSON | `0a4eab998c3a28b61949c4e5739b7c21e6301cd0ccde0084c9a325dc742438a6` |
| `pokrov-core.cdx.json` | `8a3bc377285104a1cf9170e55fa25150a03e431582ef3f44d857d18241ec7a95` |
| `sing-box.cdx.json` | `bc92db83e96ba285838a82a2887474ced36eece5b4a2f95aa0cdbb77764cec62` |

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
`clean_mixed_platform_pre_candidate_local`:

- exact Android and Windows runtime bytes and their separate source commits are bound;
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

1. rebuild Windows from `54e76bb` and prove byte-identical active artifacts from one Core source;
2. inspect the resulting Android and Windows packages and bind their Core
   digests into strict-v2 metadata;
3. run hosted CI on every frozen revision;
4. complete exact-candidate Android physical-device and Windows clean-host
   TUN/DNS/egress/recovery gates;
5. complete production signing, provenance review and public-index binding;
6. keep publication, runtime synchronization and promotion blocked until the
   separately authorized go/no-go step.

## Rollback

There is no hidden runtime fallback. Before candidate promotion, rollback means
restoring the exact retained public Core `1.0.3` contract and rebuilding the
client from an explicitly selected clean source revision. After a candidate is
created, rollback must use the versioned release catalog and same-byte evidence;
it must not rewrite these `1.1.0` bytes under an older identity.
