# POKROV 1.0.0-beta.4 — internal tester build

Exact client candidate: `POKROV-app@7bc561ffecef01c2d6bd58e80782bb00c1557015`.

This prerelease is for manual testing. It does not replace the current public
`v1.0.0-beta`, does not switch production download pointers, and is not a
stable, store-ready, or trusted-signing release.

## What changed since beta.3 tester

- first-launch onboarding remains native and Apple-like, while completion is
  synchronized to the account-scoped server state;
- the first-connection milestone completes only after the runtime reaches its
  real running phase;
- a failed connection keeps the milestone pending instead of producing a false
  success;
- the client reports runtime statistics and onboarding completion through the
  authenticated app session on a best-effort path that cannot block connect.

The matching platform candidate `portal@b250b39a38e82a5502824f800bb3e2ab11fc65ec`
is deployed and verified on production.

## Downloads

- `pokrov-android-arm64-v8a-1.0.0-beta.4-test.apk` — modern Android devices;
- `pokrov-android-armeabi-v7a-1.0.0-beta.4-test.apk` — legacy ARMv7 devices;
- `pokrov-windows-setup-x64-1.0.0-beta.4-test.exe` — Windows x64 installer;
- `pokrov-windows-portable-x64-1.0.0-beta.4-test.zip` — portable Windows build.

No AAB is included. The first AAB attempt ended in a local Flutter compiler
access violation, and it was not retried to avoid unnecessary host load. AAB is
not needed for tester installation and remains a later signed store handoff.

## Signing truth

- Android is release-mode code signed with `CN=Android Debug`; APK Signature
  Scheme v2 verification passes. Production Android signing is not configured.
- Windows setup is unsigned; SmartScreen or an unknown-publisher warning is
  expected. Trusted Windows signing is not configured.
- These skips apply only to this internal tester candidate.

## Automated checks

- 127 focused onboarding/runtime/shell tests: `PASS`;
- app-shell Flutter analyze: `PASS`;
- Android ARM64 and ARMv7 release APK builds: `PASS`;
- Android package/version check: `PASS` (`1.0.0-beta.4`, codes `2004`/`1004`);
- APK v2 signature verification: `PASS`, debug certificate disclosed above;
- Windows release build, setup, portable ZIP, and manifest: `PASS`;
- Windows Authenticode: `NotSigned` as expected for this tester candidate.

## Manual tester route

1. Verify the matching SHA-256 from `SHA256SUMS.txt`.
2. Install or update the exact downloaded artifact.
3. Test first launch, login/trial, onboarding resume and completion.
4. Confirm a failed connection does not dismiss the first-connect hint.
5. Confirm a successful real connection dismisses it and stays completed after
   restart and on another surface for the same account.
6. Test connect/disconnect, `Full tunnel`, `All except RU`, selected apps,
   support chat, wheel/calendar rewards, cabinet handoff, and session recovery.

Physical Android, clean Windows, DNS/leak, WARP, real network routing, store,
and trusted-signing checks remain `MANUAL_OWNER_TEST` or blocked by signing.
