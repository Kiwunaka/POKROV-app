# POKROV Public Beta Operator Handoff

Date: 2026-06-04

## Scope

This note moves the `0.2.0-beta.1+20260604-rc-local` package from local RC
build evidence into owner/operator review.

RC folder:

`C:/Users/kiwun/Documents/ai/POKROV-app/artifacts/releases/pokrov-app/0.2.0-beta.1+20260604-rc-local/`

## Current Gate State

- Stage 0 local exact-candidate package: `DONE`
- Stage 1 operator artifact review: `READY_FOR_OWNER`
- Stage 2 Android public-beta gate: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`
- Stage 3 Windows public-beta gate: `UNSIGNED_RELEASE_APPROVED_BY_OWNER_MANUAL_TEST_PENDING`
- Stage 4 public artifact upload: `DONE_GITHUB_PRERELEASE_REFRESHED`
- Stage 5 runtime handoff sync: `DONE_URLS_UNCHANGED_BRAIN_SMOKE_PASS`
- Stage 6 live beta smoke: `MANUAL_OWNER_TEST`
- Stage 7 release note and monitoring: `PENDING`

## Local Evidence

- RC inventory exists.
- Checksums rechecked against retained files.
- `release-handoff.json` parses.
- Windows manifest parses.
- Android APK verifies with APK Signature Scheme v2.
- Android APK certificate:
  `C=US, O=Android, CN=Android Debug`.
- Android APK certificate SHA-256:
  `55d2e71b9871459a3d436563f02de5150336201b848f4d9f22d5e247e1520e74`.
- Android AAB is signed by the same Android Debug certificate and lacks a
  trusted public certificate chain.
- Windows setup EXE Authenticode status: `NotSigned`.
- Windows runner EXE Authenticode status: `NotSigned`.
- Windows ZIP contains the expected runner/runtime files.
- GitHub prerelease `v0.2.0-beta.1` was refreshed with canonical public asset
  names:
  - `pokrov-android-universal.apk`
  - `pokrov-windows-setup-x64.exe`
- Current-origin public URL smoke returned `206` for both asset URLs.
- `gh release download` returned files whose SHA-256 values match the local RC.
- Brain-origin `/api/client/apps` smoke passed and returned the same GitHub
  Android APK URL, Windows EXE URL, and install docs URL.
- Public-beta external-access preflight now passes the publication policy,
  runtime smoke, GitHub auth, staged payload, and unsigned Windows risk checks.
  Its overall classification remains `BLOCKED_BY_ACCESS` only because
  `EMAIL_PROBE_TO` and `LAVATOP_PROBE_EMAIL` are not present for live
  email/Lava post-deploy probes.

## Owner Decision

On 2026-06-04, the owner approved the current outside-store beta release
without production Android signing and without trusted Windows signing.

This approval is limited to the current `0.2.0-beta.1` outside-store beta. It
does not authorize Play/App Store claims, trusted Windows signing claims,
SmartScreen reputation claims, or stable release labeling.

## Payload Decision

Recommended gated beta payloads:

- Android:
  `pokrov-android-release-smoke-0.2.0-beta.1+20260604.apk`
- Windows:
  `pokrov-windows-beta-x64-0.2.0-beta.1+20260604-setup.exe`

Operator-only retained payloads:

- Android AAB store-smoke artifact
- Windows portable ZIP unless the operator deliberately promotes it as an
  additional public beta payload
- Windows manifest

## Manual Test Checklist

- Android physical install from the exact APK.
- Android production signing is an accepted skip for this beta; keep the
  outside-store beta label explicit.
- Android start-trial -> managed profile -> connect -> dashboard.
- Android disconnect/reconnect.
- Android localhost/control-surface audit on the exact installed build.
- Windows install from the exact setup EXE.
- Windows trusted signing is an accepted skip for this beta; keep the
  SmartScreen/unknown-publisher warning explicit.
- Windows start-trial -> managed profile -> connect -> dashboard.
- Windows disconnect/reconnect.
- Support chat create/reply with redacted diagnostics.
- Cabinet handoff opens through a short-lived handoff URL.
- Unified redeem accepts a valid access code and rejects raw subscription links.
- Telegram bonus link/check/claim path works.
- Checkout continuation opens the expected browser flow.

## Runtime Handoff Result

Runtime `APP_*` mutation was not required for this refresh because the public
GitHub URLs stayed stable. The brain-origin smoke artifact is:

`C:/Users/kiwun/Documents/ai/VPN/docs/audit-artifacts/runtime-app-download-smoke-brain-2026-06-04-rc-refresh.json`

Before announcement:

- smoke `brain-origin` and `RU-origin` only when those claims are needed;
- verify app, bot, cabinet, and download surfaces show the same version, URLs,
  and beta warnings.
- run email and Lava live probes when `EMAIL_PROBE_TO` and
  `LAVATOP_PROBE_EMAIL` are available, or keep paid/email maturity claims out
  of the release note.

## Release Copy Guardrails

Allowed:

- outside-store Android + Windows beta;
- unsigned Windows beta with warning;
- local RC evidence;
- Android operator/physical test pending until attached.

Forbidden without fresh evidence:

- Play/App Store readiness;
- production Android signing;
- trusted Windows signing;
- SmartScreen reputation;
- raw Android audit proof;
- RU-origin readiness;
- production WARP.
