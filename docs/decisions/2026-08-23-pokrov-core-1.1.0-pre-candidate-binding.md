# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

Status: refreshed on 2026-08-29 as a security-fixed, single-source
Android/Windows pre-candidate binding for POKROV `1.2.0+4046`. Both active
platform artifacts now carry the Core egress, AWG allocated-port binding,
default-off Hysteria2 lane and the `GO-2026-6303` dependency correction from
one exact revision.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- Android and Windows source commit: `547f09670fad1eeffa94897fb36b12ec5e7818cd`;
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
scoped release line until its own owner-solo promotion evidence is recorded.

## Exact Artifact Contract

| Platform | Artifact | Size | SHA-256 | Local result |
| --- | --- | ---: | --- | --- |
| Android | `pokrov-core.aar` | `107414253` | `7895b2f7d6e5fe00cc74d3ff85b961f4110b551eb2cf9860fba5e1337ef01a63` | two byte-identical local builds from `547f096`; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55424000` | `6bf2243ffd907244bc70b1afdcc82a87c805fdc98804d4efd2bfaa1dc5a64c45` | two byte-identical local builds from `547f096`; 15 required exports present; 100 proxy-only start/stop cycles pass |
| Windows dependency | `libcronet.dll` | `8596992` | `8ef1f8bbde77f954af1ae47bee1819ac8dc2354bb0e1d4baba3dad9e58d7a6f7` | unchanged retained dependency |
| iOS | `PokrovCore.xcframework` | — | — | `MANUAL_OWNER_TEST` |
| macOS | `pokrov-core.dylib` | — | — | `MANUAL_OWNER_TEST` |

Android is bound by package `space.pokrov.core`, its exact source commit and AAR
digest. Windows is bound by the same source commit, desktop ABI `2`, exact DLL
digest and exact Cronet dependency. This closes the local platform-source
convergence prerequisite. A later exact physical Android slice is recorded
below; candidate and complete platform matrices remain open.

## Reproducibility, SBOM And Provenance

Fresh Android and Windows two-build evidence and deterministic source SBOMs
bind the same Core source. Packaged-client candidate provenance remains open:

| Evidence | Result / SHA-256 |
| --- | --- |
| Android build tree | `b4232070b36c698309e4b8887054306b65928e09e2fdb740592ff54d09b98650` |
| Android evidence JSON | `c26c3b71a85cd7d5538930dc6eccc73820be928c10a9c353837f6a57cb974e5a` |
| Windows build tree | `ce531a4b7b667973d570019214db17aefd7ffa6c1441834e37a966cce4e5d0bf` |
| Windows evidence JSON | `f1dd3b4f03a2b2fb1f9bddc2c402dd681caedec448f913f883c20b4f9bc9e465` |
| `pokrov-core.cdx.json` | `13910fb7d84170f785370d78f93588c4c9db0c6fd4007566f83fae63c013d451` |
| `sing-box.cdx.json` | `127b185ad24218f5e8eb11a47388237698a3b77826160dbe725261632af06d2e` |

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

The exact source updates `golang.org/x/crypto` to `v0.55.0`, the first fixed
version for `GO-2026-6303`, together with the minimum compatible Go module
closure in both Core module roots. Root and embedded sing-box module
verification, focused SSH/libbox/config tests, full Core tests, `go vet` and
both reachable-vulnerability scans pass locally with zero reachable findings.

## Evidence Ceiling

The strongest claim from this decision is
`clean_reproducible_pre_candidate_local`:

- exact Android and Windows runtime bytes from one source commit are bound;
- Android four-ABI presence and Windows ABI exports are proved locally;
- the Windows proxy-only harness passed 100 start/stop cycles without changing
  system routes;
- Windows TUN, DNS capture and leak protection were not exercised by that
  host-safe harness;
- exact production-signed ARM64 APK `7d1d4093…58ee5`, size `101364310`, binds
  client `064fcd0...` and Core `547f096...`, installs/readbacks byte-identically
  as release/non-debuggable `1.2.0+4046` on physical Huawei/Android 12;
- ordinary Frankfurt reaches verified green on that APK and Beeline path;
- AWG2 and AWG3.1 each complete a fresh authenticated handshake and exchange
  bidirectional TCP/UDP payload, while the Android selected-endpoint URL test
  still fails `EGRESS-001`; transport/crypto passes but full egress verification
  does not;
- exact `547f096...` operator Core interop against the same owned material
  passes authenticated TLS/HTTP for both profiles, narrowing the remaining
  defect to the Android/Core endpoint-probe runtime path;
- Core hosted CI run `33227157016` passes all five jobs; the client hosted run
  for `064fcd0...` executes zero steps and remains `BLOCKED_BY_ACCESS`;
- no artifact is tagged, uploaded, published or promoted;
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
2. retain exact local gate evidence and record hosted CI as `PASS`,
   `BLOCKED_BY_ACCESS` or the owner-solo exception without converting a skip
   into a pass;
3. correct and prove the Android selected-endpoint `EGRESS-001` path without
   weakening fail-closed verified state, then complete the remaining Android
   physical-device and Windows clean-host TUN/DNS/egress/recovery gates;
4. complete production signing, provenance review and public-index binding;
5. keep publication, runtime synchronization and promotion blocked until the
   separately authorized go/no-go step.

## Rollback

There is no hidden runtime fallback. Before candidate promotion, rollback means
restoring the exact retained public Core `1.0.3` contract and rebuilding the
client from an explicitly selected clean source revision. After a candidate is
created, rollback must use the versioned release catalog and same-byte evidence;
it must not rewrite these `1.1.0` bytes under an older identity.
