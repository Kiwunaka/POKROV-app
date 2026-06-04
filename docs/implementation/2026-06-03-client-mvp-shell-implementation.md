# POKROV Client MVP Shell Implementation

Date: 2026-06-03
Status: implemented local MVP shell plus Premium Shell V2 brand/control/support/bonus/routing-staging pass

## What Landed

- Shared Flutter shell now uses the target top-level IA:
  `Защита / Локации / Правила / Профиль`.
- `Защита` originally started with the region and route-mode setup; the active
  Premium Shell V2 Home now keeps route mode as a compact chip and moves rule
  editing to `Правила`.
- The protection screen keeps the one-tap connect/disconnect runtime path and
  adds quick actions for `Исключения`, `Локация`, `Усиленный режим`, and
  `Помощь`.
- Service-news space is present as `Новости и уведомления`, with Telegram
  channel wording kept as an information source rather than a raw feed dump.
- `Правила` now contains consumer-facing presets for Russian banks, Gosuslugi,
  marketplaces, messengers, and app selection without exposing raw rules.
- `Профиль` now appears as a compact account layer: access/payment/cabinet,
  native code entry with Telegram bonus, and device/help rows. Longer restore,
  email, support, and advanced details stay one tap deeper.
- Advanced settings are behind a warning, acknowledgement checkbox, and second
  action before showing recovery/fallback-only details.
- Android build tooling was minimally updated from Android Gradle Plugin
  `8.1.0` to `8.1.1` to satisfy the current Flutter hard gate.

## Premium Shell V2 Update

After owner review, the first MVP shell was rejected as too card-heavy,
text-heavy, mobile-stretched, and not premium enough. The next implementation
pass now follows
`docs/design/2026-06-03-client-premium-shell-v2-brief.md`.

Changes landed in the V2 pass:

- `Windows` now uses a desktop shell with a left sidebar instead of mobile
  bottom navigation.
- `Android` keeps a compact mobile shell with bottom navigation.
- The first `Защита` screen is reduced to a calm Home stage:
  status, one connect/disconnect action, location chip, route-mode chip, and a
  short status line.
- The old Home setup blocks, service-news section, repeated connect CTA,
  restore-account prompt, and `Усиленный режим` Home control were removed from
  the first layer.
- The visual system moved away from beige/mint gradients to neutral system
  surfaces with a sparse emerald accent aligned with the POKROV mark.
- The official raster mark from `external/logogo.png` was cropped into
  transparent package assets under `packages/app_shell/assets/brand/`.
- Android and Windows host apps mirror the same PNGs under their own
  `assets/brand/` folders so release bundles include the mark with the stable
  `assets/brand/pokrov_mark.png` key.
- Home and the desktop sidebar now show a mark + word lockup instead of
  text-only branding.
- The Home primary action is now a single animated connect disc:
  raster mark center, `CustomPainter` rim, press-scale feedback, finite state
  motion, and no separate filled `Подключить` button below it.
- A P0 motion layer is now present:
  shared motion policy/tokens, finite Home boot reveal, status/chip
  micro-interactions, geometry-matched skeletons, and calm recovery banners for
  preparation/connect errors.
- `Профиль` is presented as `Аккаунт` in the active shell; restore, cabinet,
  Telegram, email, bonuses, devices, support, and advanced remain deeper account
  tasks.
- WARP/enhanced privacy is visible on Home only as a disabled future-feature
  tile; it is not product-claimed until it is wired and verified.

## Support Chat, Ticket Adapter, And Text-Density Update

The follow-up Premium Shell V2 pass now follows the `2026-06-03`
support/text-density consilium:

- support opens a full native POKROV chat route before Telegram handoff
- Telegram, feedback, and public-channel links use native Telegram deep links
  with safe `https://t.me/...` fallback
- the chat route includes backend ticket history, composer, local assistant
  intro for empty state, diagnostics preview, and Telegram fallback without
  faking a live operator
- the support adapter can list tickets, load a ticket thread, create the first
  app-first ticket, and send follow-up messages to
  `/api/tickets/{ticket_id}/messages`
- diagnostics are attached only during first ticket creation; normal follow-up
  messages are body-only
- support diagnostics are sent as `app_diagnostics` through a conservative
  allowlist; raw configs, subscription URLs, keys, server addresses, and
  protocol links are filtered out before request payload construction
- Profile/Account collapsed long explanatory cards into settings-style rows
  with short values and chevrons
- Windows now has responsive sidebar breakpoints: expanded desktop sidebar,
  collapsed icon rail, and hamburger drawer before content becomes unreadable
- Rules keeps mode selection and compact rule categories visible while moving
  mode explanations behind `Как выбрать`
- Locations removed inline node-selection explanations from the first layer and
  moved them behind `Как выбирается`
- Advanced copy is shorter and keeps manual settings gated behind explicit user
  responsibility
- no user-facing copy claims a real operator is present in the local MVP state

## Telegram Bonus Link/Check/Claim Update

The next production slice wires the profile Telegram reward to the existing
backend contract instead of adding a duplicate summary endpoint:

- runtime adapter exposes `createTelegramLink`, `checkChannelBonus`, and
  `claimChannelBonus`
- the adapter calls the live app-first endpoints:
  `/api/client/telegram/link`, `/api/channel/subscriber/check`, and
  `/api/bonuses/channel/claim`
- Profile/Account keeps the native code field and adds stateful Telegram bonus
  rows for link, check, and claim
- the Telegram bot URL and channel URL come from the backend response rather
  than hardcoded UI guesses
- successful claim marks the managed profile dirty so the next connect/profile
  refresh can pick up the updated access state
- wheel, roulette, and activity calendar UI remain absent from the MVP widget
  tree until real public APIs and feature flags exist
- no `/api/client/bonuses/summary` endpoint was added in this slice; the
  consilium decision was to use the existing endpoint family and later add a
  dashboard adapter only if repeated aggregation becomes necessary

## Routing, Smart Connect, And WARP Staging Update

The Task 7 consilium aligned on a beta-honest staging cut:

- public route choices are now only `Все, кроме РФ` and `Все устройство`
- Android/Windows still keep `supportsSelectedAppsMode` as a technical
  capability, but `RouteMode.selectedApps` is not included in public
  `supportedRouteModes` until package/process picker, persistence, and OS-level
  enforcement are proven per platform
- `Правила` keeps `Приложения · Скоро` as a teaser row, but does not expose a
  selectable `Выбранные приложения` route card
- managed-profile bootstrap now parses backend `smart_connect` metadata into
  `ManagedProfilePayload.smartConnect`
- the client does not use `smart_connect` for node switching and does not send
  RTT samples yet, because there is no verified client-side RTT measurement
  loop in this slice
- Home WARP/enhanced privacy remains a disabled/info-only tile with regression
  coverage proving there is no active toggle

## Deliberate MVP Limits

- `Усиленный режим` is a UI state only until the sing-box chain/WARP runtime
  behavior is proved safe for Android and Windows.
- In the V2 shell, that state is no longer exposed on Home. It remains a future
  advanced/runtime task.
- Unified code entry uses the app-facing `/api/redeem` contract for native
  activation.
- Cabinet opening uses the short-lived `/api/client/cabinet-token` handoff when
  available and degrades to the canonical cabinet URL when the adapter fails.
- Support is thread-aware through existing `/api/tickets*` endpoints. Continuous
  background polling, SSE, read receipts, typing indicators, and response-time
  promises are still intentionally absent.
- Telegram bonus link/check/claim is native in the app shell, but it remains
  explicit user action only. The app does not poll Telegram membership, does not
  require Telegram for normal use, and does not deep-link back from Telegram in
  the MVP.
- Selected-app routing is staged only. The backend route-policy plumbing remains
  available for future proof work, but the public app does not let users pick it
  yet.
- Smart-connect metadata is parsed as passive backend-owned profile data. It is
  not a visible mode, balancer, or manual node list in the MVP.
- Roulette and activity calendar are not active UI. They remain hidden until
  public app APIs and feature flags exist.
- Raw subscription import and Xray fallback remain advanced/recovery-only.
- The imagegen concept mark explored during the brand pass was not promoted into
  the app because it diverged from the current official POKROV mark.
- Motion remains deliberately finite. The Home screen must not use permanent
  idle tickers, infinite spinners, decorative breathing, confetti, neon glow, or
  layout-property animation.

## Verification

Fresh Task 8 verification run on `2026-06-03` after the routing/WARP staging
slice:

- `python -m pytest portal_bot/tests/test_app_first_api.py -q` in the root
  platform repo: `18 passed`
- `python -m pytest tests/test_api_auth_and_tickets.py -q` in the root platform
  repo: `65 passed`
- `flutter analyze` in `packages/app_shell`: no issues
- `flutter test` in `packages/app_shell`: `49 passed`
- `flutter analyze` in `apps/android_shell`: no issues
- `flutter test` in `apps/android_shell`: `4 passed`
- `flutter analyze` in `apps/windows_shell`: no issues
- `flutter test` in `apps/windows_shell`: `2 passed`
- `flutter analyze` in `packages/runtime_engine`: no issues
- `flutter test` in `packages/runtime_engine`: `11 passed`
- `dart analyze` in `packages/core_domain`: no issues
- `flutter build apk --debug` in `apps/android_shell`: built
  `build/app/outputs/flutter-apk/app-debug.apk`
- `flutter build windows --release` in `apps/windows_shell`: built
  `build/windows/x64/runner/Release/pokrov_windows_beta.exe`

Build artifacts verified locally:

- `apps/android_shell/build/app/outputs/flutter-apk/app-debug.apk`
- `apps/windows_shell/build/windows/x64/runner/Release/pokrov_windows_beta.exe`
- `apps/windows_shell/build/windows/x64/runner/Release/libcore.dll`

Final local handoff pack:

- `artifacts/releases/pokrov-app/0.2.0-beta.1+20260603-local-mvp/`
- includes Android debug APK smoke artifact, Windows unsigned setup EXE,
  Windows portable ZIP, Windows manifest, `SHA256SUMS.txt`, `README.md`, and
  `release-handoff.json`
- checksum verification passed against every file listed in `SHA256SUMS.txt`
- `release-handoff.json` parses successfully and keeps
  `release_state=local_engineering_handoff_not_public_release`

Notes from the same run:

- Android debug build emitted Flutter deprecation warnings for Gradle `8.3.0`,
  Android Gradle Plugin `8.1.1`, Kotlin `1.8.22`, and an SDK XML version
  mismatch. They did not block the debug APK build, but remain Android
  toolchain follow-up work before stronger release claims.
- `pytest` finished with exit code `0`; on Windows it printed a pytest atexit
  temp-cleanup `PermissionError` for `%TEMP%\pytest-of-kiwun\pytest-current`
  after `test_app_first_api.py`.

## Follow-Up Gates

- Upgrade Android Gradle Plugin, Gradle wrapper, and Kotlin to the future
  Flutter-supported range after a dedicated Android toolchain pass.
- Broaden `/api/redeem` beyond access keys only when backend support for new
  code kinds is verified.
- Keep cabinet handoff exchange covered by backend/webapp/client regression
  tests because tokens are short-lived and one-time.
- Add lifecycle-safe periodic support polling or SSE only after the MVP ticket
  adapter is exercised in real operator flow.
- Add real service notifications and a dashboard-backed bonus summary only if
  later product work needs a richer account overview than the current
  link/check/claim rows.
- Keep Telegram reward UI covered by adapter and widget regression tests when
  the dashboard/account model is expanded.
- Prove enhanced mode runtime behavior before making it a default support
  recommendation.
