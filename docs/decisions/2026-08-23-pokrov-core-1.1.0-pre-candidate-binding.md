# POKROV Core 1.1.0 Pre-Candidate Runtime Binding

## Current licensed uTLS and lifecycle binding — 2026-09-11

The development client binds Core `2662f76a3303a0518bb07fbbdc449c066de2f95b`.
The authenticated Psiphon uTLS7a1fc module supplies its own root license;
URL-test lifecycle hook access is synchronized after a native race failure.
Android and Windows each reproduce in two native DE builds. Four Android
ABIs, desktop ABI2, event ABI1 and 15 Windows exports are retained. The Go
module inventory loses Cloudflare CIRCL; other external module identities
remain unchanged. The native notice asset preserves prior license bodies and
adds the exact uTLS root license and MinGW/GCC runtime terms.

[Binding evidence](../operations/evidence/2026-09-11-r12-c05-utls-binding/README.md)
retains failed SBOM/OOM attempts, exact binaries and source identities.
The Windows DLL passes 100 Dart proxy cycles and 300 bounded lifecycle cycles
with 600 cancelled loopback sessions. Core CI passes test, Android, Windows
and Apple jobs; its strict release contract awaits coordinated client binding.
Consumer checks pass 81 runtime and 8 Android Flutter tests plus seed/docs
contracts; all 99 generated Java wrapper files are unchanged. Source promotion
is pending. Installed
device acceptance, complete native licensing/source obligations and public
release are still open for these bytes.

## Previous lifecycle resource binding — 2026-09-11

The development client binds Core `904e440aca98cb6419744c5c04c83223a6d6380e`. Discarded service owners now close
their background observers; live command servers keep restartable stop/reload.
Monitoring cancellation and ticker access are synchronized. Android and Windows
artifacts each reproduce exactly from that source; four Android ABIs, desktop
ABI2, event ABI1 and 15 exports remain unchanged.

[C02 source and artifact evidence](../operations/evidence/2026-09-11-r12-c02-lifecycle/README.md)
retains the initial goroutine and handle failures alongside fixed source race
and bounded default-scheduler DLL observations. New consumer/CI convergence is
pending. Earlier installed and C01 receipts remain tied to their previous
bytes; this binding does not transfer device or public release acceptance.

## Previous lifecycle privacy binding — 2026-09-10

The development client binds Core `c8b0461c1975ef96e32024774300a5829b9fdc43`. A real rejected-profile FFI call
previously exposed raw configuration/error text in its return and stderr,
even with debug disabled. Lifecycle failure logging, status and ABI responses
now expose the catalog code while retaining the typed cause internally.
Structured event classification preserves that code.

Android AAR: 107491758 bytes, SHA-256 `2ddb4c43664763624d47632a7197c4c1f641605d586aaf2c16f5fff9d86265e0`.
Windows DLL: 55449600 bytes, SHA-256 `46e203b5d69267c47ba3f2f11800b28c20c0de48de4dabf7311ce967a14a74ed`.
Two clean builds per platform are byte-identical; four Android ABIs, 15 Windows
exports, desktop ABI 2 and event ABI 1 remain. Exact DLL direct-FFI canary and
100 proxy-only lifecycle checks pass. Cronet and dependency contracts are unchanged.

[Binding evidence](../operations/evidence/2026-09-10-r12-core-privacy-binding/README.md)
retains the original failure and old manifest. Current installed packages still
use earlier Core; no device/route/extended-support acceptance is transferred.
This is a pre-candidate local binding. No tag, public release or signing claim.
81 runtime tests, 8 Android Flutter tests, runtime analyze and exact-source seed/docs checks pass. Coordinated Core/client CI must converge before packaging acceptance.

## Superseded source binding — 2026-09-09

The development client now binds Core `c7a11f7d2fd974726095ad7aa0619c055273dd15`.
Its only changes after `02a091c` are the Apple build's Go-version check and
release documentation. Two fresh local Android builds and two fresh Windows
builds from the clean new revision reproduce all five files of the previous
build trees byte for byte. The client's AAR, DLL and Cronet dependency also
match those bytes. Runtime hashes, ABI, dependencies and capability contracts
are unchanged; the native notice changes only its source reference.

[Binding comparison](../operations/evidence/2026-09-09-r12-core-source-binding/binding.json),
[Android evidence](../operations/evidence/2026-09-09-r12-core-source-binding/android-evidence.json)
and [Windows evidence](../operations/evidence/2026-09-09-r12-core-source-binding/windows-evidence.json)
record the exact new source. The [previous manifest](../operations/evidence/2026-09-09-r12-core-source-binding/previous-runtime-binding.json)
retains rollback identity. Full builds, source SBOMs and logs remain under
`E:/r12-core-rebinding-20260909`. The receipts' CI wording represents local
execution here; no hosted run is attributed to these files. SBOM warnings
remain separate licensing work.

The exact Windows DLL again passed 100 proxy-only start/stop cycles. This
rebinding creates no APK, installer, candidate, tag, signing or publication.
Older device and system-route observations retain their original candidate
identity; this comparison does not create new device or release acceptance.

## Superseded source binding; AWG cross-field behavior retained — 2026-09-08

The development client binds Core `02a091cb0e369192a5ad0909b56ccba8aa1dce17`
for Android and Windows. The validator rejects intersecting H1-H4 ranges,
S1-S4/MTU combinations exceeding the supported message buffer, oversized junk
packets and inconsistent AWG3.1 rekey/reject/receive-refresh timing before
device creation. The managed Android/Windows packet ceiling is 2016 bytes;
this is a buffer bound, not a network path-MTU guarantee. Scalar schema maxima
are necessary but insufficient on their own. ABI and dependency versions stay
unchanged from the previous C05 binding.

- Android AAR: 107490210 bytes, SHA-256 `5e2ea69c044ea461b9be352cb7ce73ddd208898b5a364b6a2642024a6215534a`.
- Windows DLL: 55451648 bytes, SHA-256 `0409da4762c56234c38f7b60ac5fe8b49d4131c4a4debedf3ef313aebe8d0371`.
- Both builds are byte-identical across two runs; four Android ABIs, desktop
  ABI 2, event ABI 1 and 15 exports are retained. The exact DLL passed 100
  proxy-only start/stop cycles. Full Core tests passed.
- The exact source passed six owned Pi userspace AWG2/AWG3.1 cases at client
  MTU 1280/1400/1408 with authenticated TLS/HTTP. These are bounded transport
  checks and do not establish whole-client routing or independent RU-origin.

[Binding receipt](../operations/evidence/2026-09-08-r12-awg-crossfield-binding/binding.json),
[Android builds](../operations/evidence/2026-09-08-r12-awg-crossfield-binding/android-evidence.json),
[Windows builds](../operations/evidence/2026-09-08-r12-awg-crossfield-binding/windows-evidence.json)
and the [previous manifest](../operations/evidence/2026-09-08-r12-awg-crossfield-binding/previous-runtime-binding.json)
retain exact identity and rollback. Local build trees, logs and source SBOMs
are retained under `E:/r12-awg-crossfield-20260908`; the previous binaries remain
under `E:/r12-c05-artifacts`. Native notices only update source references;
module manifests and verbatim license text are unchanged. SBOM license warnings
remain separate from this source/build verification. The evidence helper's CI
label denotes local execution here, with no hosted workflow run.

No new candidate, signing, tag, publication or promotion. Existing installed
phone/VM packages still contain their earlier Core until explicitly replaced
and checked; their acceptance is not transferred to these new bytes. Android
and Windows whole-client, WARP, final package and full-origin gates stay open.

[Consumer backtests](../operations/evidence/2026-09-08-r12-awg-crossfield-binding/client-backtests.json):
80 runtime tests, 8 Android Flutter tests and 376 freshly executed JVM tests
pass. Runtime/Android analyze, explicit-root seed/docs/parity and 16 release
handoff-v2 cases pass. Five compiled Go target module/build records match the
previous binding; the retained DLL/AAR bytes themselves have changed.

## Superseded C05 binding — 2026-09-06

The development client binds Core `8dc57a830bd1487389dd1b7c9190f094c31e13bc`
for Android and Windows. `config/runtime-artifacts.seed.json` owns the identity.
The binding uses Go 1.26.8, x/crypto 0.56.0 and tfo-go 2.3.3, including the
Go 1.26 Psiphon TLS ConnectionState layout correction. It fixes source call
paths to SSH deadlock advisories GO-2026-6354 and GO-2026-6355. Existing managed
log filtering, probe correlation and transport authority are retained.

- Android AAR: 107483275 bytes, SHA-256 `bc5ef7ece6ba6c138589307a7c5e30be32ec01cdd396e23dfdb8840011148b29`.
- Windows DLL: 55449088 bytes, SHA-256 `c679ba5af42939acbc8c6f44af59b4608f6a76c99e0d444cfa4bcc825bcc8e68`.
- Desktop ABI 2, event ABI 1, 15 required exports, four Android ABIs.

Both platform builds are byte-identical across two local builds. Full Core gate,
TLS conversion and 100 component proxy-only cycles passed. Build outputs and
SBOMs remain in `E:/r12-c05-artifacts`. The copied [Android evidence](../operations/evidence/2026-09-06-r12-c05-core-binding/android-evidence.json),
[Windows evidence](../operations/evidence/2026-09-06-r12-c05-core-binding/windows-evidence.json)
and [previous D05 binding](../operations/evidence/2026-09-06-r12-c05-core-binding/previous-runtime-binding.json)
retain exact identity and rollback; previous D05 build trees remain under
`E:/POKROV-tools/builds/core-d05`. This section supersedes the stale N05-current
heading below; the actual immediately preceding binding was D05 Core `94dd310`.

The scanner extracts no symbols from these stripped DLL/SO, so its nine
remaining advisory IDs have module precision. Bounded source analysis is not
full reachability proof. Source SBOM license warnings and final APK/EXE notices
remain open; no broad security or license clearance is claimed. Reproducibility
receipts were generated after the source commit, from code-identical builds
compiled before commit; their helper CI label is local evidence, not a hosted run.
No new release tag, candidate, signing, publication or promotion is created.
Candidate.33, public releases and the D05 Win11 component lab retain their
original bytes and evidence. Physical Android, Windows SCM/TUN/DNS, WARP and
independent-origin acceptance remain open for this binding.

Consumer [backtests](../operations/evidence/2026-09-06-r12-c05-core-binding/client-backtests.json): 80 runtime tests, 8 Android Flutter tests and 372 fresh JVM tests pass; the default opt-in skip is covered by a separate 100-cycle run on the synced Windows DLL. Runtime/Android analyze and the seed/docs/parity gates pass. These are host/component checks, not device or final-package acceptance.

## Superseded N05 local binding — 2026-09-06

The local N05 client binds Core `6bc36034c86528972488fc203a98512686ac4db9`. Observed DNS, UDP timeout,
TLS-handshake timeout and response stall retain separate diagnostic codes.
An unqualified timeout stays generic. URL probes propagate cancellation after
dial instead of reporting success. These observations do not establish censorship
or change fallback authority. The desktop ABI remains 2, event ABI 1, 15 exports.
Both Android (four ABIs) and Windows were built twice with byte-identical results.
The exact Windows DLL passed 100 proxy-only start/stop cycles; full and race Core
tests passed. The machine owner is `config/runtime-artifacts.seed.json`.

- android: `pokrov-core.aar`, 107465916 bytes, SHA-256 `9f99134528e8309f60b2fb20bfed9df9db7f5fa978ec1f13b7d329e2a70cf19b`.
- windows: `pokrov-core.dll`, 55440384 bytes, SHA-256 `148453156b61bf22c18d987cbf0cd8a47c0bf99636b2650c016310e92bc3384b`.

Evidence and the previous runtime binding are retained in
`docs/operations/evidence/2026-09-06-r12-n05-core-binding/`. Build trees and SBOMs:
`E:/POKROV-tools/builds/core-6bc3603-n05/`. SBOM license/version warnings remain
unresolved; this is not license clearance or hosted provenance. The former local
binaries remain in `E:/r12-artifacts/final/` and candidate.33 is unchanged.
No new candidate, release tag, signing, publication or promotion is created.
Physical Android, Windows TUN/DNS/clean-VM and independent-origin checks remain
open for these bytes. Prior receipts below are not transferred to this binding.

## Superseded local binding — 2026-09-05

The local R12 client now binds Core `3f52efd4635218967cc84d58cb06b2fa593fd563` for Android and Windows.
This adds per-call Android `ProbeEndpoint` and `ProbeSelectedOutbound` results
used by the endpoint and group egress verifier. Group proof captures the selected
proxy leaf and rejects a changed route/runtime, timeout, direct or cyclic route.
The desktop ABI remains 2, event ABI 1, with 15 exports. The AAR contains all
four ABIs and both methods; its consumer rules preserve them under R8.
Both platform outputs were built twice and compared byte for byte. The exact
Windows DLL passed 100 proxy-only start/stop cycles. Full Core tests passed.

- android: `pokrov-core.aar`, 107450158 bytes, SHA-256 `c02bc2fcc25f925f9062520f85667c324999b091eb2251a9cf26b8a1f66b0302`.
- windows: `pokrov-core.dll`, 55434240 bytes, SHA-256 `94acf541893be21341255fe2fce66116fab48d68c80e84f3a820dc2fcfc40366`.

The machine owner is `config/runtime-artifacts.seed.json`. Retained build
evidence is under `docs/operations/evidence/2026-09-05-r12-core-binding/final/`;
`previous-runtime-binding.json` preserves the superseded local binding. Full
SBOMs and both build trees remain in `E:/r12-artifacts/final`. SBOM generation reported
missing license/version metadata for local replacements; this is not a
license-clearance pass. Evidence was generated locally, with no hosted run.

New APK/installer, physical Android, clean Windows VM, signing, hosted CI and
RU-origin checks have no transferred PASS. Candidate.33 and public release
metadata remain retained. No candidate, tag, promotion or publication is created.

## Superseded binding and historical evidence — 2026-08-30

The remainder records earlier bytes and their evidence; it is not the current
artifact identity and does not establish device proof for the R12 replacement.

Status: refreshed on 2026-08-30 as a security-fixed, single-source
Android/Windows pre-candidate binding for POKROV `1.2.0+4047`. Both active
platform artifacts carry the Core egress, AWG allocated-port binding,
default-resolver propagation for AWG endpoint FQDNs, default-off Hysteria2 lane,
the `GO-2026-6303` dependency correction and the secret-safe legacy logging
boundary from one exact revision. AWG2 and AWG 3.1 also retain an explicit
start/close lifecycle test on the same source.

This is not a Core release, client candidate, signing pass, publication or
promotion decision. No `v1.1.0` Git tag or public Core release was created.

## Decision

The client binds the separately versioned Core target as follows:

- repository: `Kiwunaka/POKROV-core`;
- version-derived target label: `v1.1.0`;
- tag created: `false`;
- Android and Windows source commit: `cd8f0f4169d570d693992a959d81d17c2c44884d`;
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
| Android | `pokrov-core.aar` | `107419397` | `2a9677d9e24ed7ef66d4e98f90e7033eb5450c9a2755f0fe6b8bba58036c6a69` | two byte-identical local builds from `cd8f0f4`; `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64` present |
| Windows x64 | `pokrov-core.dll` | `55426048` | `f284fa8841f1a45271874a7a05ed6093fb0e3efbdd03e00001edd046be708204` | two byte-identical local builds from `cd8f0f4`; 15 required exports present; 100 proxy-only start/stop cycles pass |
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
| Android build tree | `881567c8bbeb1ac093f69dc72643fdcd1d22369bc488367900c5c62f19c14922` |
| Android evidence JSON | `0c737c9086905167bc2e0f524aefe00925f5f8a17b10c162ac647e6ac297cd22` |
| Windows build tree | `8678bae1cea86bf992bc1299661ee5d620130f8e8506dff3a4074e07bf7d53ca` |
| Windows evidence JSON | `bdbde9aee7a05ba1ace6bbc2c031caf3ab393110570201414516360ad186dd8a` |
| `pokrov-core.cdx.json` | `cc8d93fc6b602b3d1c080b4f3d32367b231536a54c9bfa71272b0e1bd055e88e` |
| `sing-box.cdx.json` | `04c0972025e3ade1e74294cf7adb5cb79e616ea03899bc131aadc1bb30d6ce51` |

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

The same source also makes the Core-owned AWG endpoint inherit the configured
default domain-resolver transport and strategy when resolving its inner FQDN.
This matches ordinary dialer behavior, preserves TLS authentication against the
hostname, introduces no pinned provider IP, and keeps resolver/probe failure
fail-closed. Focused AWG tests and the full Core suite pass locally.

The `cd8f0f4` refresh removes a legacy debug call that could format the stored
`PokrovSettingsJson` value, whose historical schema may contain WARP key or
token material. It also stops the desktop FFI from mirroring arbitrary raw
errors into the process logger and removes a whole settings-table debug call.
The local caller-owned ABI error return is unchanged, while the Windows host
continues to map it to fixed public failure categories. The observability
contract check now rejects reintroduction of those three raw-log paths.

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
- later production-signed diagnostic client `f078625...` with the same
  `547f096...` Core retained the exact safe terminal category
  `egress_probe_dns_lookup` for both AWG2 and AWG3.1 on physical Beeline;
- corrected Core `a45d69e...` is reproducibly bound for Android and Windows;
  exact production-signed client `68779c4...` installs/readbacks byte-identically
  and reaches retained green selected-endpoint state for AWG2 and AWG3.1 on
  physical Beeline, with the prior DNS failure category absent;
- successor Core `cd8f0f4...` is reproducibly bound for Android and Windows,
  passes the full local Core suite and the exact DLL's 100-cycle proxy-only
  harness, but has no transferred phone, emulator, signed package or clean-VM
  claim; those remain new-candidate gates for `1.2.0+4047`;
- clean client documentation head `f500728...` produces unsigned pre-candidate
  Windows setup `81268d7e...723c`, whose eight-file manifest readback contains
  exact DLL `53b5e82a...4652`; Windows Sandbox/Hyper-V is unavailable on the
  build host, so no install or live TUN/DNS/AWG claim is made;
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
3. complete the remaining Android WARP/per-app/OEM/lifecycle/endurance and
   Windows clean-host TUN/DNS/egress/recovery gates on exact current bytes;
4. complete production signing, provenance review and public-index binding;
5. keep publication, runtime synchronization and promotion blocked until the
   separately authorized go/no-go step.

## Rollback

There is no hidden runtime fallback. Before candidate promotion, rollback means
restoring the exact retained public Core `1.0.3` contract and rebuilding the
client from an explicitly selected clean source revision. After a candidate is
created, rollback must use the versioned release catalog and same-byte evidence;
it must not rewrite these `1.1.0` bytes under an older identity.
