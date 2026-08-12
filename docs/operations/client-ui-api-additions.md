# POKROV Client UI API Additions

Date: 2026-06-22
Status: P0/P1 implementation landed locally; owner/manual live checks still separate.

This document tracks the API and runtime additions needed by the new POKROV client UI. It replaces the earlier proposal state: backend endpoints, client service methods, runtime WARP proof, Android bridge methods, and the first locations UI wiring now exist.

## P0

### Locations catalog and search

Backend:

- `GET /api/client/locations?platform=<android|windows>&q=<query>`
- Uses the app-first bearer session.
- Builds a real catalog from enabled premium nodes. Expired users receive no delivery node; legacy free roles remain cleanup/rollback-only and never fall back to premium nodes.
- Returns `auto`, `countries[].cities[]`, `freePoolCode`, `profileRevision`, `transportProfile`, and query metadata.

Client:

- `AppFirstRuntimeBootstrapper.fetchLocationsCatalog(...)`
- `AppFirstClientDataService.fetchLocationsCatalog(...)`
- `Locations` screen requests the catalog when the tab opens.
- If backend catalog cities are present, the screen renders them as selectable rows and keeps shortlist as fallback.
- Selection still goes through the existing preferred-node flow.

Verification:

- Root backend: `python -m pytest tests\test_client_ui_api_additions.py -q`
- Client service: `flutter test test\app_first_runtime_bootstrap_test.dart --plain-name "client P0/P1 API additions use the app-first session"`
- Client UI: `flutter test test\pokrov_seed_app_test.dart --plain-name "locations screen renders backend catalog cities"`

### WARP runtime proof

Runtime:

- `PokrovRuntimeEngine.applyWarp({required bool enabled})`
- `DesktopRuntimeEngine` applies WARP through runtime options after a profile is staged.
- `MobileArtifactRuntimeEngine` forwards `runtimeEngine.applyWarp` to the host bridge.
- Android host bridge rewrites staged runtime config from stored base config + runtime options.

Client:

- The WARP consent flow now calls `runtimeEngine.applyWarp` after backend consent/revoke.
- Runtime apply result is reported through `POST /api/client/warp/events`.
- If no staged profile exists, consent is kept and WARP is applied on next connect instead of showing a fake active state.

Verification:

- Runtime: `flutter test test\runtime_engine_test.dart`
- Android bridge: `.\gradlew.bat testDebugUnitTest`
- Client UI: `flutter test test\pokrov_seed_app_test.dart --plain-name "enhanced protection asks for explicit consent before activation"`

## P1

### Live connection stats

Runtime:

- `PokrovRuntimeEngine.liveStats()`
- `RuntimeLiveStats` exposes `available`, optional traffic/latency fields, `since`, `serverCode`, `serverCountry`, and `protocol`.
- Current implementation is intentionally honest: it does not invent bandwidth or latency when the runtime cannot measure them.
- Android bridge exposes `runtimeEngine.liveStats`.

Next UI step:

- Home can now consume `RuntimeLiveStats`; do not display fake speed/ping.

### Notifications and push

Backend:

- `GET /api/client/notifications`
- `POST /api/client/notifications/read`
- `POST /api/client/push/register`

Client:

- `fetchClientNotifications(...)`
- `markClientNotificationsRead(...)`
- `registerClientPushToken(...)`
- Runtime exposes `pushToken()` with poll fallback when no native push token exists.

### Support assistant

Backend:

- `POST /api/client/support/assistant`
- Existing ticket rows now include operator presence fields.

Client:

- `askSupportAssistant(...)`
- Uses app-first session auth.
- Sends `ticketId`, message, scope, and safe diagnostics.

Verification:

- `flutter test test\app_first_runtime_bootstrap_test.dart --plain-name "client support assistant uses app-session auth"`

### Devices

Backend:

- `GET /api/client/devices`
- `DELETE /api/client/devices/{device_id}`

Client:

- `fetchClientDevices(...)`
- `revokeClientDevice(...)`

### Subscription

Backend:

- `GET /api/client/subscription`

Client:

- `fetchClientSubscription(...)`
- Returns lane, expiration, days left, renew URL, traffic policy, and plans.

## Honesty rules

- Do not claim silent auto-update, store readiness, signing, RU-origin readiness, or trusted Windows status from these changes.
- Do not render arbitrary remote HTML/JS from notifications or promo surfaces.
- Do not show fake speed, latency, or WARP active state.
- Owner/manual live checks remain separate from local automated verification.
