# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: accepted on 2026-08-23 as the exact Android and Windows runtime bytes
for the local POKROV `1.2.0+30` pre-candidate line.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- clean source commit: `fcb3c8bbc6efdeed284417369aacb522722ebfa2`;
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
`1.1.0`.

## Exact Artifact Contract

| Platform | Artifact | Size | SHA-256 | Local result |
| --- | --- | ---: | --- | --- |
| Android | `pokrov-core.aar` | `107317530` | `26a7b9ebcf05065b33cc40848147a66db5172a9655cb9c77a839fa685145bf93` | two byte-identical builds; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55352320` | `10ee475d04417c4317221a85ca4b043a7489294d654fc4ce7a64ec56dcdcdbff` | two byte-identical builds; 15 required exports present; proxy-only 100-cycle start/stop PASS |
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
| Android build tree | `78cbf8dddd6ce2c3311a2ec2167c803ec122a6973efe50d955f26ec1d07c3b13` |
| Android evidence JSON | `743ac8b5f68a0c779bf6d4043fce9dc45fdcecc7cd610e3b40285aacdd974efc` |
| Windows build tree | `a293a83e1efbd653b7a623b3c832df93f4985a57a50bb693cf4aef75dcfe3b4b` |
| Windows evidence JSON | `917bad838ed91ccf86544a543fe9e7c8daa3d9e54f8e788006f6ec219f16f17a` |
| `pokrov-core.cdx.json` | `18707e43f557d80aceecb112d4907c1295e8a27583af1bf2243d45cf63ba38a0` |
| `sing-box.cdx.json` | `28925d34046ac0f0a7edec40a032938fcbc59c18bd47b9d5d69b6688ebf6637d` |

The Windows build used the pinned MinGW-w64 `13.2.0` archive with SHA-256
`a05578fab9068c678ce761e7b2e284d23fa7416a2f4f36349e05e506c944e2c7`.
The local toolchain directory was added only to the build process `PATH`; no
system compiler installation or persistent environment change was made.

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
