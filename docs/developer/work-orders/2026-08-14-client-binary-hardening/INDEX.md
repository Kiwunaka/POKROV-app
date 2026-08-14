# POKROV client binary hardening

Status: `PLANNED_SEPARATE_TASK`

This work order records the owner's follow-up request to make the direct Android
and Windows builds harder to reverse, repackage and inspect. It is intentionally
separate from the `1.0.8` product release. The current release is not described
as protected or tamper-proof merely because this plan exists.

## Outcome and threat model

The useful goal is to raise the cost of opportunistic analysis while keeping the
client reproducible, supportable and recoverable. No client binary can be made
unbreakable. The design must cover these concrete threats:

- static inspection of Dart, Kotlin, Java and native symbols;
- extraction of credentials or privileged server material from a public build;
- APK/EXE repackaging and redistribution under the POKROV name;
- runtime hooking, patching and integrity-check bypass attempts;
- update substitution or metadata/artifact mismatch;
- accidental loss of crash symbols, signing recovery or rollback ability.

Out of scope: destructive anti-debug behaviour, malware-like self-protection,
device fingerprinting, collecting installed-app inventory on the server, and a
promise that a determined analyst cannot inspect the client.

## Required discovery before implementation

- [ ] Inventory every secret-like value and endpoint compiled into Android,
  Windows, Flutter assets and native runtime bundles. Prove that authorization,
  signing and provider secrets live server-side.
- [ ] Produce a release dependency/SBOM inventory and scan the exact dependency
  locks, native libraries and public artifacts for known vulnerabilities and
  accidental credentials.
- [ ] Record current APK/EXE symbol visibility, package size, startup time, crash
  readability and reproducibility as the comparison baseline.
- [ ] Confirm the update trust chain: HTTPS origin, exact version, size, SHA-256,
  production Android certificate and rollback behaviour.

## Android hardening

- [ ] Build Flutter release with `--obfuscate` and a candidate-specific
  `--split-debug-info` directory stored outside the public release. Retain the
  source commit, engine/tool versions and symbol archive needed to decode
  crashes.
- [ ] Enable R8/minification and resource shrinking only with reviewed keep rules
  for Flutter, platform channels, VPN service, quick-settings tile, background
  work, notifications and the embedded core. No reflection/JNI path may be
  assumed safe without an exact release regression.
- [ ] Strip distributable native symbols while retaining private symbol files and
  licences/provenance. Verify the embedded core is byte-identical to its pinned
  approved artifact.
- [ ] Add narrow repackaging/tamper detection based on the expected production
  signing certificate and verified update metadata. Failure must be explicit and
  recoverable; it must not lock an account or destroy local data.
- [ ] Keep authentication/session material in the existing secure storage path,
  redact logs and prove logout/revocation/corrupt-state behaviour after
  obfuscation.
- [ ] Do not add Play Integrity as a hard dependency while direct APK is the
  primary channel. Revisit attestation only if a store-backed distribution lane
  is approved.

## Windows hardening

- [ ] Separate/strip release symbols and retain private PDB/native symbol
  material with exact commit and artifact hashes.
- [ ] Verify setup/portable manifest, SHA-256 and update metadata before install
  or replacement. Preserve a clear rollback path.
- [ ] Add trusted Authenticode signing only after the owner provisions the
  certificate and recovery process; until then keep the SmartScreen limitation
  explicit.
- [ ] Avoid anti-debug drivers, process killing, opaque packers and other
  behaviours likely to break antivirus trust or support diagnostics.

## Release and operations controls

- [ ] Create an encrypted offline backup of the Android signing key and recovery
  instructions on owner-controlled external media: `MANUAL_OWNER_TEST` until the
  medium is connected.
- [ ] Keep obfuscation maps, symbols and signing recovery outside Git and public
  GitHub assets. Record only redacted hashes/provenance in release evidence.
- [ ] Add exact artifact secret scans, signer/ABI/debuggable verification and
  checksum/update readback to the normal release gate.
- [ ] Document rollback to the last public stable artifact and prove that a
  hardening failure cannot strand users without a valid update path.

## Acceptance criteria

- [ ] Android and Windows exact-final artifacts contain no client credential that
  grants privileged backend/provider access.
- [ ] Flutter/Dart and releasable native symbols are materially reduced, while a
  retained private symbol package can decode a controlled crash.
- [ ] Repacked Android artifact is rejected with a safe user-facing error; the
  original production-signed artifact still passes install, update, VPN, tile,
  notification, support and background regressions.
- [ ] Update metadata rejects wrong hash/size/version and accepts the exact public
  stable assets.
- [ ] Full Flutter/Android/Windows release checks, LDPlayer and physical Huawei
  critical journeys pass on the hardened exact candidate.
- [ ] Performance and APK/EXE size deltas are measured and accepted rather than
  hidden.
- [ ] Canonical security/release docs, rollback evidence and private symbol/key
  custody instructions are current before promotion.

## Release honesty

Use `PASS` only for the exact hardened artifact. Code-level checks do not prove
runtime tamper resistance, and obfuscation does not protect secrets that were
incorrectly shipped to the client. Operator-only key backup and trusted Windows
signing stay `MANUAL_OWNER_TEST` until executed.
