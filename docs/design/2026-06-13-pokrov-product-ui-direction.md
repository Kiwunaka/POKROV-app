# POKROV Product UI Direction

Status: active  
Date: 2026-06-13  
Scope: design-system foundation and product UI direction for the Android and
Windows app-shell pass

This note records the owner decisions that govern the app-shell UI pass. It
supersedes older generated variant copy when there is a conflict, while
preserving the selected visual references from
`docs/design/generated/2026-06-09-app-screen-variants/OWNER_SELECTION.md`.

## Owner Decisions

The consumer protection sheet keeps its first layer plain: one refresh, one
bounded reconnect action, and short results. Terms such as runtime,
host-health, bootstrap DNS, and Core belong in diagnostics/evidence rather than
the normal user explanation.

1. Android and Windows are equally important product surfaces. The shared shell
   must support mobile density and Windows resize behavior from the same design
   foundation.
2. POKROV is presented as a VPN. Public app UI may use `VPN` plainly when it
   helps the user understand the action.
3. Home sells one primary action: enable POKROV VPN. The owner-selected
   2026-08-13 mobile composition uses a large centered circular action with a
   thin neutral border, brand mark, in-control status and finite hourglass wait
   motion. It has no glowing perimeter or duplicate instructional button.
   Remaining premium days sit in a compact top pill that opens checkout; two
   quick controls, WARP and an optional remote campaign follow below.
4. WARP is called `WARP` in the product UI. It is explained as additional
   protection, not as a second confusing VPN.
   The default user path is client-local: the app may offer WARP from the
   bundled runtime defaults even when the backend has not returned managed WARP
   material yet. Backend endpoints remain useful for consent, lifecycle events,
   and optional managed material.
5. The one-time Telegram `+5 days` acquisition reward is available before or
   after payment, but it is not a Home competitor. Trial copy keeps that action
   available and gates only roulette, calendar, and referral rewards behind the
   first payment. The tone is soft reward/gold, not casino, urgency, neon, or
   pressure.
6. News and admin promotions exist as backend-owned surfaces, but render only
   when explicitly visible. Home may show one operator-authored remote campaign
   above navigation with image/logo or full-width banner, badge, copy, CTA,
   colors, audience, schedule, whole-card link and optional close action. A
   dismissed campaign is remembered by its slot/content/schedule; a disabled or
   absent campaign leaves no empty placeholder. Third-party ad SDKs remain out.
7. Rewards remain important. The paid roulette is a calm fortnightly loyalty
   feature; calendar remains separately controlled. Neither may look like a
   casino or promise outsized free access.
8. Dark mode is mandatory. Dark tokens must use off-black surfaces and never
   pure black.
9. The visual style is flat, iOS-like, quiet, and consumer-first: grouped
   sections, list rows, thin separators, restrained emerald accent, soft gold
   rewards, no glow/neon/glass, no card-in-card piles.
10. Support is a separate screen, not a fifth tab. Diagnostics opens as a
    bottom sheet from support or relevant error states.
11. Beta status belongs in diagnostics only, not in the first-layer sidebar,
    footer, profile header, or Home UI.
12. First launch starts with two explicit, phone-width-safe actions:
    `Начать бесплатно` and `У меня есть код`. Supporting copy explains the
    current trial length and code-based access restore without truncating the
    primary action labels.

## Design-System Foundation

The shared primitives should keep feature screens visually quiet, flat, and
predictable across Android and Windows.

Required foundation:

- light and dark palette tokens exposed through the design system
- no pure black in app tokens
- calm emerald as the primary action/accent family
- soft gold/reward tokens for Telegram and rewards
- flat shared primitives for grouped app surfaces:
  `PokrovSurface`, `PokrovGroupedSection`, `PokrovListRow`,
  `PokrovPromoCard`, `PokrovStatusPill`, `PokrovInfoBanner`,
  `PokrovTrialBanner`, `PokrovTelegramBonusCard`, and
  `PokrovWarpToggleRow`
- one shared status pill direction instead of per-screen `_StatusPill`
  duplication in future feature-screen phases
- surfaces should group content directly; do not place cards inside cards

## Implemented Surface Direction

The reusable primitives live under `packages/app_shell/lib/src/design_system/`.
The first feature pass applies them to Home, onboarding, Profile, Rewards,
WARP, Support, Locations, Rules, and the shared shell.

Expected first-layer behavior:

- Home presents `POKROV VPN`, remaining premium days, one centered connection
  action, location/routing shortcuts, WARP and at most one remote campaign
  without a pile of competing cards.
- Home keeps WARP visible as a compact control and shows a short confirmation
  after the user enables or disables it.
- Support opens as a separate screen; diagnostics is a safe bottom sheet.
  Ticket history, ticket-send failure, and AI request failure each use one
  compact status/retry surface. Retry must not duplicate a user bubble or turn
  a network error into an assistant answer. The pinned composers and human
  escape action remain reachable above the mobile keyboard.
- Profile is grouped like Settings: access, recovery, support, settings,
  bonuses, and diagnostics.
- Rewards keeps Telegram reward, referral, promo, history, roulette and
  achievements as calm loyalty mechanics; trial can claim Telegram `+5 days`,
  sees an explicit paid gate on the remaining mechanics, and disabled backend
  features do not render dead cards.
- Rules uses consumer labels and hides raw app/process identifiers by default.
- Locations starts with automatic selection and uses human quality labels.
- A city with one available server variant remains one tap. A city with
  multiple variants opens a compact bottom sheet with `Обычный` and safe
  backend labels such as `Белые списки`; unavailable choices are visibly
  disabled and raw hosts, keys, tags, and configuration never enter the sheet.
- Locations refresh owns one progress indicator in the `Обновить` action. The
  Auto card does not duplicate that spinner, preserving the full
  `Автоматически` title on narrow Huawei-class layouts.
- The shell keeps four top-level sections and lazy-builds non-Home tabs.
- DNS, LAN, custom routes, trusted Wi-Fi, and Windows transport compatibility
  controls stay behind the single `Дополнительно` disclosure in Rules. The
  Windows default is named in consumer language; `System`, `Mixed`, `gVisor`,
  and `Системный прокси` appear only after that deliberate expansion.
- The default Windows connect stays full-device VPN/TUN. In an unelevated
  process, one focused sheet explains the Windows permission request and keeps
  the recommended full-VPN action primary. `Продолжить без администратора` is
  an explicit secondary fallback with a visible warning that system proxy is
  limited to compatible applications; a cancelled UAC returns to this choice.

The first contract coverage lives in
`packages/app_shell/test/design_system_contract_test.dart` and checks the
light/dark token contract, no-pure-black rule, and the existence of the shared
flat controls. Additional widget and copy contracts live in
`packages/app_shell/test/pokrov_seed_app_test.dart` and
`packages/app_shell/test/ui_copy_contract_test.dart`.

## 2026-07 Implementation Reconciliation

The completed motion/HIG pass is retained as implementation evidence in
`docs/design/2026-07-13-agent-uiux-backlog.md`; it is not a second active
design owner. The current implementation keeps:

- one status dialect: `Подключаемся…`, `Подключено`, `Отключаем…`,
  `Не защищено`;
- directional busy copy while preserving the shared connect-disc handoff and
  reduced-motion behavior;
- one mobile navigation haptic and silent desktop pointer navigation;
- Windows compact/drawer behavior at 700 and 900 px;
- Android adaptive launcher/splash assets and edge-to-edge system chrome tied
  to the existing POKROV brand source.

## 2026-07 Protection And Competitor-Parity Surfaces

The selected feature pass extends `pokrov-clear` without introducing a second
visual language:

- the Protection center is an 86%-height iOS-like sheet with one grouped list
  for tunnel, DNS, HTTPS, and route ownership, followed by measured stats,
  user shortcuts, local history, and one full-width repair action;
- healthy, warning, danger, and unknown states use the existing palette and
  status-pill dialect; unknown data is never decorated as success;
- Locations keeps automatic selection first, then compact Favorites and Recent
  groups, with ping/load/health and freshness in secondary text;
- stale, future-dated, or invalid location measurements use a neutral signal
  treatment and do not keep showing old ping/load or qualitative health values
  as if they were current; missing or out-of-range health scores stay neutral;
- before Smart Connect exists, location rows show a lock and no press surface,
  while search and the independent favorite action remain available; one
  explanatory card tells the user to complete the first connection;
- Rules uses grouped settings rows for purpose routes, explicit overrides,
  DNS, LAN, and trusted Wi-Fi. Advanced values stay behind focused sheets;
- compound switch rows expose one accessibility action, not a tappable parent
  plus a duplicate native switch; picker rows expose their selected state;
- the primary connect disc supports focus plus Enter/Space activation, and
  location/app picker rows expose their selected state without leaking raw
  package identifiers;
- Rewards keeps referral metrics, achievements, quests, discounts, and history
  in flat grouped sections. It must not use flashing, countdown pressure,
  oversized jackpot treatment, or casino copy;
- guides are one clear external action under Support/Profile and open the
  canonical searchable guide registry rather than duplicating long articles in
  the app;
- tray actions mirror the main connection state and never invent their own
  success state. Quick Settings resolves the live TUN and the app-owned VPN
  service on tap, refreshes its simple on/off state after committed transitions,
  and leaves country, route and speed detail to the notification.

The same mobile composition must remain usable in the Windows compact lane;
desktop may widen content but must not replace the grouped hierarchy with an
operator dashboard.
