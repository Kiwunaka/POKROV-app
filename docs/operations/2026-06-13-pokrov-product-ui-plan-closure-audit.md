# POKROV Product UI Plan Closure Audit

Status: implementation verified locally  
Date: 2026-06-13  
Scope: attached main app product/UI plan for Android and Windows app shell

This audit maps the owner plan to current repository evidence. It is evidence
for implementation closure, not a replacement for owner manual install/connect
review, signing, store review, or public release upload.

## Closure Matrix

| Phase | Requirement | Evidence |
| --- | --- | --- |
| 1 | Light/dark flat iOS-like design foundation, no pure black, shared controls | `packages/app_shell/lib/src/design_system/pokrov_palette.dart`, `pokrov_controls.dart`, `pokrov_motion.dart`; `test/design_system_contract_test.dart` |
| 2 | Four top-level sections, support not fifth tab, lazy tabs, beta hidden from shell | `src/shell/navigation_shell.dart`, `src/shell/seed_shell.dart`; tests `seed shell lazily builds tabs...`, `windows shell hides unavailable enhanced protection`, sidebar tests |
| 3 | First launch new/returning choice, restore by code, no mandatory Telegram login | `src/features/onboarding/onboarding_flow.dart`; tests `first launch choice uses new and returning access copy`, `new user first launch completion is persisted`, `returning first launch restores...` |
| 4 | Home sells VPN action, shows WARP, trial/access, Telegram bonus, no card pile | `src/features/home/home_surface.dart`; tests `renders premium shell v2 with compact first screen`, `home uses raster brand mark...`, `home WARP switch changes consent without opening details` |
| 5 | Connect disc sizes, optimistic state, hot-path motion discipline, reduced motion | `src/shared/shell_widgets.dart`, `src/design_system/pokrov_motion.dart`; `design_system_contract_test.dart`, `preparation screens use geometry-matched motion skeletons` |
| 6 | WARP visible on Home, real Home toggle, client-local default path, public wording, consent sheet, no runtime/policy/fallback words in normal sheet | `src/features/home/home_surface.dart`, `src/features/warp/warp_sheet.dart`, `src/warp/pokrov_warp_lifecycle.dart`; Home WARP toggle, client-local/default consent, consent/revoke tests and lifecycle tests |
| 7 | Telegram bonus as promotional mechanic on Home/Profile/Rewards, non-blocking | `src/features/home/home_surface.dart`, `profile_surface.dart`, `rewards_hub.dart`; Telegram bonus tests |
| 8 | Admin promotion/news is conditional: no dead placeholder, render only visible backend promo | `src/features/home/home_surface.dart` uses `promoSlots.visibleForPlacement('home_banner')`; `seed_shell.dart` loads bonus/promo summary after first frame; test `home renders admin promotion only when backend exposes one` |
| 9 | Rewards hub keeps Telegram/referral/promo/history/wheel/calendar calmly; disabled features hidden | `src/features/rewards/rewards_hub.dart`; tests `disabled rewards stay hidden...`, `rewards hub can run live wheel and calendar actions`, promo slot tests |
| 10 | Profile is Settings-like: access, recovery, support, settings, bonuses, diagnostics; theme selector; beta only diagnostics | `src/features/profile/profile_surface.dart`, `profile_sheets.dart`; profile grouping, theme, sheets, and diagnostics tests |
| 11 | Rules use final route labels, selected-app picker, friendly names, raw ids hidden by default | `src/features/rules/route_labels.dart`, `rules_surface.dart`; `ui_copy_contract_test.dart`; selected app picker tests |
| 12 | Locations starts with automatic selection, human quality labels, no ping/host/IP/node-code leakage | `src/features/locations/locations_surface.dart`, `location_labels.dart`; `ui_copy_contract_test.dart`; location widget tests |
| 13 | Support separate screen, issue chips, chat composer, safe diagnostics bottom sheet and opt-in attach | `src/features/support/support_chat.dart`; support lifecycle, diagnostics, AI helper, polling tests |
| 14 | Copy audit removes normal-UI technical terms and old confusing labels | `test/ui_copy_contract_test.dart`, `test/pokrov_seed_app_test.dart`; focused grep-backed source tests |
| 15 | Performance: lazy tabs, light first frame, picker scans only on picker, stable skeletons, reduced motion | `navigation_shell.dart`, `rules_surface.dart`, design motion primitives; lazy tab, skeleton, responsive, and reduced-motion tests |
| 16 | Required verification commands and breakpoints | `flutter analyze`, `flutter test`, responsive matrix in `pokrov_seed_app_test.dart` covers 360, 493, 700, 900, 1024, 1180, 1440 |

## Product Slice Matrix

This maps the broader product slices in the attached owner plan, not only the
implementation-phase list.

| Slice | Closure evidence |
| --- | --- |
| Final product frame | `docs/design/2026-06-13-pokrov-product-ui-direction.md` records POKROV as a VPN app, Android/Windows parity, app-first access, WARP on Home, Telegram reward, hidden admin promo by default, dark mode, and beta-only diagnostics. |
| First launch | `onboarding_flow.dart`; tests `first launch choice uses new and returning access copy`, `new user first launch completion is persisted`, `returning first launch restores through unified redeem`, and raw subscription link rejection. |
| Home / Protection | `home_surface.dart`; tests cover one primary VPN action, raster logo, compact Home, no dead news card, safe admin promo, responsive widths, WARP control, Telegram bonus, and connection-details separation. |
| WARP UX | `warp_sheet.dart`, `pokrov_warp_lifecycle.dart`, `runtime_engine.dart`, Android `RuntimeHostBridge.kt`; tests cover client-local WARP without server material, consent/revoke, safe diagnostics, desktop/mobile runtime option mapping, and no stale placeholder copy. |
| Telegram bonus | `home_surface.dart`, `profile_surface.dart`, `rewards_hub.dart`, `seed_shell.dart`; tests cover Home/Profile/Rewards bonus paths, check/claim APIs, non-blocking flow, and hidden Home bonus after claim. |
| Admin news / ad slot | `AppFirstPromoSlots` rendering in `home_surface.dart` and `rewards_hub.dart`; tests prove Home renders no promo without visible backend data, renders one visible promo, and ignores unsafe CTA schemes. |
| Rewards / loyalty | `rewards_hub.dart`; tests cover live wheel/calendar actions, preview states, hidden disabled rewards, referral share, promo slots, and no heavy haptic reward feedback. |
| Profile / Account | `profile_surface.dart`, `profile_sheets.dart`; tests cover compact grouped access, restore code, Telegram bonus, subscription/email sheets, handoffs, theme selector, and advanced diagnostics moved off the first layer. |
| Support | `support_chat.dart`; tests cover separate support screen, issue chips, composer, AI helper suggestions, polling/operator reply lifecycle, offline hint, and opt-in diagnostics attachment. |
| Rules / selected apps | `rules_surface.dart`, `route_labels.dart`; tests cover final route labels, Android app picker, Windows process picker/manual entry, hidden raw identifiers, and no normal split-tunnel/CIDR/rule-set prose. |
| Locations | `locations_surface.dart`, `location_labels.dart`; tests cover one logical automatic location, human quality labels, and hidden ping/host/IP/node-code details. |
| Paywall / renewal | `profile_surface.dart`, `seed_context.dart`; tests cover `profile-checkout-action`, `subscription-checkout-primary`, canonical checkout handoff, and scan checks show no unsupported auto-renewal/forever/best/guaranteed/privacy claims in app copy. |
| Dark mode | `seed_shell.dart`, `pokrov_palette.dart`; tests cover light/dark tokens with no pure black and Profile theme switching through system/light/dark. |
| Flat iOS-like visual system | `pokrov_controls.dart`, `pokrov_palette.dart`, `DESIGN.md`; contract tests cover shared grouped rows, promo/trial/Telegram/WARP controls, touch target sizing, no pure black, and stable skeleton geometry. |
| Performance / motion | `navigation_shell.dart`, `pokrov_connect_disc.dart`, `pokrov_motion.dart`; tests cover lazy tab initialization, RepaintBoundary use, reduced-motion collapse, connect-disc phases, stable micro controls, no full-screen spinner, and responsive breakpoints. |
| Copy system | `ui_copy_contract_test.dart`; source-backed tests forbid dead placeholders, old WARP placeholder labels, technical route/location text, raw package/process labels, and unsafe support/diagnostic wording in normal UI. |
| Build handoff | Windows portable release bundle rebuilt from the current tree; command and SHA are recorded below. Android/manual install/connect, signing, store, and public release upload remain owner/manual gates by design. |

## Notes

- This pass included five high-focus implementation reviewers for Home/WARP,
  Profile/Support, Rules/Locations, performance/reduced motion, and
  Rewards/promo safety. Their findings were merged into the local
  implementation rather than treated as separate product authority.
- Home promo is intentionally data-driven from `AppFirstPromoSlots`; when no
  `home_banner`/home placement is visible, Home renders no news or ad block.
- Promo CTA is limited to safe handoff links (`pokrov.space`, `t.me`, and
  GitHub release URLs) before it is passed to the shared handoff launcher.
- Bonus/promo summary is fetched after the first frame to avoid blocking Home
  first paint.
- Home WARP is a real switch now; tapping the text/info opens details, while
  toggling the switch changes local WARP consent without pretending the sheet is
  the control.
- WARP no longer depends on backend-managed WARP material for the first user
  path. `WarpRuntimePolicy.withClientLocalDefaults()` keeps the Home control
  offerable, `seed_shell.dart` records consent/events, and
  `home WARP uses client-local defaults without server material` proves the
  app can show and enable WARP when the backend returns no WARP config.
- After WARP changes, Home shows a compact confirmation such as `WARP включится
  при следующем подключении.` instead of hiding feedback in diagnostics.
- If WARP is not available from the current runtime state, the sheet no longer
  exposes an active switch; it shows a calm explanation and a single close
  action.
- The Profile first layer was reduced to Settings-like access/recovery/bonus/
  settings rows, with fake progress and duplicate diagnostics removed.
- Locations and Rules now avoid node-code, host, ping, package/process, and
  other raw identifiers on the normal first layer.
- Support diagnostics are opt-in per message and include only the safe summary
  shown in the sheet: app version, platform, route mode, connection status, and
  WARP status.
- Runtime diagnostics no longer use the old dead placeholder wording for
  artifact-ready mobile states; the runtime test now locks that down.
- Reduced-motion mode now disables connect-disc scale/sweep-style motion and
  the shell wraps hot navigation/lazy tab areas in repaint boundaries.
- Manual owner checks still remain outside this audit: real install/connect
  feel, real WARP proof on target devices, signing, store/trusted claims, and
  release upload.

## Verification Commands

Fresh local verification on 2026-06-13:

- `packages/app_shell`: `flutter analyze` - no issues
- `packages/app_shell`: `flutter test --reporter compact` - 119 tests passed
- `packages/runtime_engine`: `flutter analyze` - no issues
- `packages/runtime_engine`: `flutter test --reporter compact` - 19 tests passed
- `apps/windows_shell`: `flutter analyze` - no issues
- `apps/android_shell/android`: `.\gradlew.bat :app:compileDebugKotlin --no-daemon --console=plain --stacktrace` - build successful; the broader `testDebugUnitTest` task was attempted first and timed out locally after 5 minutes without useful output
- Windows portable build: `apps/windows_shell/build/release_bundle/pokrov-windows-beta-x64-1.0.0-beta.3.zip`
  - Size: `28,581,870` bytes
  - SHA256: `6258D70FC26915F8C4DB42133BE44BDD8201CE015382DBDF2CD0C44FD2D814C5`
  - Portable EXE SHA256: `0080AB268AF92C4621FE5D3580D86537AF4AA400BD5A8A50AEF8E55F403C38AE`

Re-run from `C:\Users\kiwun\Documents\ai\POKROV-app`:

```powershell
cd packages\app_shell
flutter analyze
flutter test

cd ..\runtime_engine
flutter analyze
flutter test

cd ..\..\apps\windows_shell
flutter analyze
```
