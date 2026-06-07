# Final Beta Closure Except Manual Tests And Signing

Date: 2026-06-05

## Scope

This note closes the remaining repo-side and authenticated-release-handoff work
for the `POKROV-app/main` `1.0.0-beta` Android + Windows outside-store beta
lane.

The owner instruction for this pass was to close everything except local/manual
tests and signing. This document therefore separates closed repo/handoff work
from the gates that intentionally remain outside local agent control.

## Closed In This Pass

- GitHub prerelease `v1.0.0-beta` is present and not draft.
- Android split APKs, Windows setup EXE, Windows portable ZIP, Windows
  manifest, and `SHA256SUMS.txt` are uploaded under canonical asset names.
- Public release-only repository `Kiwunaka/pokrov` now hosts the current
  `v1.0.0-beta` assets.
- Unauthenticated range smoke returns `206` for Android split APKs, Windows
  setup EXE, Windows portable ZIP, Windows manifest, and `SHA256SUMS.txt`.
- Brain-local signed `/api/client/apps` smoke returns the current split APK
  variants, hashes, sizes, Windows EXE, and docs URL. Real-user Telegram
  WebApp opening remains a manual owner test.
- Authenticated `gh release download` of all private-source release assets also
  passed before public republishing.
- Downloaded release assets match the retained SHA-256 values:
  - Android ARM64 APK:
    `9D5AB665378F563021A6FB50F9E996FB6DA1A4269D9FBC959C8E33561A4EA523`
  - Android ARMv7 APK:
    `28882CA1E2F57695D31658A16AF32DE901FCE2163EBA9E0469C1136CA4E52DF9`
  - Windows setup EXE:
    `B4CC0BF82DCFF7F021F7325E513226856B8E1D0686242744888D64D26FB82EBB`
  - Windows portable ZIP:
    `6D854D5F6C75B4F048C8481B07BF62D35D97536DA15EDC585DAEA982BA224FEF`
  - Windows manifest:
    `3E20F410AEC23C18403C51FCEA2C7F015A230B63EB5C1428326820E04BC22AA0`
- Android build-tool future-support warnings are closed for the current host
  lane: Gradle `8.11.1`, Android Gradle Plugin `8.9.1`, Kotlin `2.1.0`.
- `artifacts/releases/release-handoff.json`,
  `config/release-handoff.seed.json`, and
  `config/cutover-readiness.seed.json` are aligned to the refreshed Android
  split APK assets and current beta state.
- P4/P5/P6 implementation map items are closed for beta scope:
  selected-app picker, support polling lifecycle, rewards flags, WARP guarded
  beta lifecycle, responsive widget matrix, and premium motion foundation.
- The previous Stage 7 `PENDING` release-note item is reduced to recorded
  guardrails plus post-announcement operator monitoring. It is not a repo/code
  blocker.

## Remaining Gates

Only these categories remain open after this pass:

- Local/manual owner or operator tests:
  - Android physical release-build install and localhost/control-surface audit
    replacement evidence if the owner wants raw proof instead of the retained
    operator attestation.
  - Android and Windows exact-artifact install -> start-trial -> managed
    profile -> connect/disconnect -> dashboard smoke.
  - Real-user Telegram/WebApp, cabinet handoff, checkout, redeem, Telegram
    bonus, support chat, and `/api/client/apps` app-session smoke.
  - DNS split/leak, route-mode runtime, reconnect/recovery, and production
    WARP runtime proof on Android and Windows release builds.
  - RU-origin probe only if a public claim needs RU-origin readiness.
- Signing/trust/store work:
  - Android production signing and Play/store readiness.
  - Trusted Windows signing, SmartScreen reputation, Microsoft Store, WinGet,
    or broad stable distribution.
  - Apple signing, notarization, TestFlight, App Store, and Mac App Store work,
    which remain readiness-only outside this Android + Windows beta wave.

## Safe State

Safe to treat as closed for the current beta:

- repo-side implementation scope through P6;
- authenticated GitHub prerelease upload and checksum proof;
- Android build-tool refresh;
- documentation and handoff metadata alignment;
- public GitHub release-only download surface and anonymous range smoke;
- guarded WARP beta contracts without production WARP claims.

Not safe to claim until the remaining gates above are completed:

- stable `1.0.0`;
- store availability;
- trusted Windows signing;
- raw Android audit proof;
- production WARP;
- RU-origin readiness.
