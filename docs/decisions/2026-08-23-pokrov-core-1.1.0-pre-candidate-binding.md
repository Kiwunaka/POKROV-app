# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: refreshed on 2026-08-27 as the exact Android and Windows runtime bytes
for the local POKROV `1.2.0+33` pre-candidate line with bounded AWG 2 and
default-off AWG 3.1 lab support.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- clean verified and GitHub-signed source commit: `344b317a7a09eca7943a93866b193553538bd8f6`;
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
| Android | `pokrov-core.aar` | `107388169` | `da3ea37834b688abac5c276f4ca9c2cdcc8e32b97edf5062913fc4f3fea6aba9` | two byte-identical Windows-host builds; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55401472` | `60fe3fad7835ec4d00c1f7168bb0ba01dd6b7ca5d883583340e5e2a86b8b3981` | two byte-identical builds; 15 required exports present; exact-DLL proxy-only 100-cycle start/stop PASS |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged retained dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST` |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST` |

Android is bound by package `space.pokrov.core` and the exact AAR digest.
Windows is bound by desktop ABI `2`, the capability/event contract, the exact
DLL digest and the exact Cronet dependency. The client sync helper accepts only
these identities from the clean Core revision.

## Reproducibility, SBOM And Provenance

Both Android and Windows were built twice from the same clean source commit
with VCS stamping disabled. Complete build trees matched byte-for-byte:

| Evidence | SHA-256 |
| --- | --- |
| Android build tree | `38a855e8e59d72966964168ea87394a1d98a892eeeac1feec23a13987fc3550c` |
| Android evidence JSON | `5bbb3ef7082da83abf5d9823765257af3edcc36d4b13dd12d5ab1bb4d12db575` |
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
`clean_reproducible_pre_candidate_local`:

- exact Core source and exact Android/Windows runtime bytes are bound;
- Android four-ABI presence and Windows ABI exports are proved locally;
- the Windows proxy-only harness passed 100 start/stop cycles without changing
  system routes;
- Windows TUN, DNS capture and leak protection were not exercised by that
  host-safe harness;
- no artifact is signed, tagged, uploaded, published or promoted;
- no physical Android, clean Windows VM, Apple, current-origin, brain-origin or
  RU-origin gate is closed.

## Remaining Candidate Gates

Before these bytes may become a release candidate:

1. commit and re-run the clean client gate with the exact AAR/DLL embedded;
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
