# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: refreshed on 2026-08-29 as a single-source Android/Windows
pre-candidate binding for POKROV `1.2.0+4046`. Both active platform artifacts
now carry the Core egress, AWG allocated-port binding and default-off
Hysteria2 corrections from one exact revision.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- Android and Windows source commit: `3c2b1147c1b42e39026231525c08558a50bc3d0f`;
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
| Android | `pokrov-core.aar` | `107408874` | `b42a548910b7369f64fcd484c5acf74180583d77299629ce4d2f9156fc598007` | two byte-identical local builds from `3c2b114`; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55417856` | `58e329eaddb2dd1f40c1663b380a03a0c7c34c5a3e8506eb2c692611234ac082` | two byte-identical local builds from `3c2b114`; 15 required exports present; 100 proxy-only start/stop cycles pass |
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
| Android build tree | `c0860173aa4a18d2e1864ecb8595ed809e38d6f394b781a6572299534e893d30` |
| Android evidence JSON | `077e0dd9b1c0349ae065434e38b0110cc17ea547cd251623fcd743ed15ee39e5` |
| Windows build tree | `25feb38570f049d4053f8632826fb8b2a254665db3b771a84878b7e013312dde` |
| Windows evidence JSON | `98b984109a3df227262179d1c3cbf46c8f0abbde0049187fb83db088a444e9c6` |
| `pokrov-core.cdx.json` | `d6847ac8ba97675d62b7021a8d2d89ce5dc6a38a58c0c1afb82321fca121d30a` |
| `sing-box.cdx.json` | `338c18be688ee0892851b93e2a5c659b79660d868af4a1f0070a80d0fc23096b` |

The Windows refresh used the isolated portable MinGW-w64 GCC `13.2.0`
toolchain already present in the build directory. The toolchain directory was passed
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
- the production-signed replacement Android APK embeds the exact `3c2b114`
  arm64 library and passed fresh AWG2 and AWG3.1 handshakes on one physical
  Beeline path; this is `PASS_PHYSICAL_PRE_CANDIDATE`, not candidate proof;
- exact current-origin Core interop passes AWG2 and AWG3.1 after the owned
  server reply-source correction;
- clean Windows VM, Windows app/service/TUN/DNS, Apple, brain-origin and
  RU-origin gates remain open.

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
