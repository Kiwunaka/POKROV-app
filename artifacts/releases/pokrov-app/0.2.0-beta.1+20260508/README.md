# POKROV App Outside-Store Beta `0.2.0-beta.1+20260508`

Status: staged GitHub prerelease handoff; runtime sync pending.

This folder records the active `POKROV-app/main` release metadata for the outside-store Android and Windows beta candidate. It does not by itself authorize public launch, runtime `APP_*` sync, Telegram announcement, or paid checkout.

## Scope

- Android: GitHub prerelease APK staged after operator-attested physical-device audit.
- Windows: GitHub prerelease unsigned EXE staged; unknown-publisher warning is expected.
- Distribution model: outside app stores through guarded cabinet/runtime links only after explicit operator GO.
- Version line: `0.2.0-beta.1`.

## Staged Artifacts

- Android APK: `https://github.com/Kiwunaka/POKROV-app/releases/download/v0.2.0-beta.1/pokrov-android-universal.apk`
- Windows EXE: `https://github.com/Kiwunaka/POKROV-app/releases/download/v0.2.0-beta.1/pokrov-windows-setup-x64.exe`
- Install docs: `https://pokrov.space/install/`

## Cutover State

- `runtime_sync_allowed`: `false`
- `public_announcement_allowed`: `false`
- `paid_checkout_allowed`: `false`

Runtime links stay blocked until the platform repo receives explicit runtime-link sync authorization and the live `/api/client/apps` smoke passes.

## Evidence Notes

- Android audit posture: `OPERATOR_ATTESTED` for this beta wave.
- Windows signing posture: `UNSIGNED_BETA_RISK_ACCEPTED` for this outside-store beta wave.
- RU-origin posture: platform handoff records `SKIPPED_BY_OPERATOR`; do not claim RU-origin readiness.
- Paid checkout remains closed until Lava.top and paid access-key email evidence are green.

