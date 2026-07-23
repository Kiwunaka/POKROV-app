# POKROV Client Screen And Component Rules

Date: 2026-06-08
Status: implementation-ready UI rules
Decision owner: owner/operator

## Purpose

Turn the `Quiet Emerald` visual direction into practical screen, component, and
review rules for the future POKROV Android/Windows Flutter client.

This document is meant to be used as a build checklist. If an implementation
choice is not covered here, prefer the calmer, simpler, more platform-native
option that keeps technical complexity out of the normal user path.

## Consilium Inputs

OpenCode-go review passes:

- `qwen3.7-max`: screen/component architecture and implementation checklist.
- `deepseek-v4-pro`: contradiction hunting and reject rules.
- `minimax-m3`: motion, responsiveness, loading/error/empty states.
- `kimi-k2.6`: premium taste, Russian wording, human labels.

Local synthesis keeps POKROV canon above external-model opinions.

## Global Product Rules

- The app has four top-level sections: `Защита`, `Локация`, `Режим`,
  `Профиль`.
- New users start in the app and receive the app-first trial.
- Returning users restore with a safe one-time code.
- Telegram and email help recovery, but are never mandatory login walls.
- Raw subscription links are manual/recovery fallback only.
- Normal UI must not expose `sing-box`, `Xray`, protocol names, hostnames,
  ports, JSON, CIDR, regex, raw links, or internal engine labels.
- Bonuses are secondary. They must not make the app feel like a game.
- Unsupported claims are forbidden: absolute anonymity, YouTube ad-free, no
  restrictions, store availability, stable `1.0.0`, trusted Windows signing,
  RU-origin readiness, or support SLA without evidence.

## Visual Rules

Style name: `Quiet Emerald` / `Спокойный изумруд`.

Use:

- calm charcoal/off-white canvases.
- one emerald accent family.
- mint/sage as supporting status colors.
- soft gold only for premium/reward accents.
- Manrope for interface text.
- JetBrains Mono only for compact numeric/debug details.
- thin dividers and spacing instead of nested cards.

Reject:

- neon, outer glow, fire mascots, gamer VPN visuals.
- purple/blue AI gradients.
- pure black `#000000`.
- central `VPN` tab or `VPN` as the main app label.
- card inside card.
- five-tab mobile navigation.
- mobile bottom tabs on Windows.

## Fixed Decisions

These decisions are fixed for the first implementation pass:

- Mobile navigation has exactly four bottom tabs.
- Windows navigation is a left rail/sidebar.
- The connect control is a circular system control with a progress ring.
- Mobile connect control target size: `128dp`, responsive range `112-144dp`.
- Do not show ping in milliseconds on the Protection screen.
- Show connection quality on consumer screens as human text when needed:
  `Отлично`, `Хорошо`, `Медленно`, or equivalent.
- Restore flow starts with in-app code entry. `Получить код в Telegram` is a
  helper path, not the first step.
- Roulette/calendar UI stays behind feature flags until public app endpoints
  exist.
- Paywall implementation waits for approved plan names, prices, and renewal
  wording.

## App Shell

### Mobile

Use a mobile shell with:

- `IndexedStack` or equivalent to preserve tab state.
- lazy tab initialization on first visit.
- bottom navigation with four items:
  - `Защита`
  - `Локации`
  - `Правила`
  - `Профиль`
- safe-area handling for Android gesture navigation.
- no central action tab.

Tab behavior:

- active tab: emerald icon/text plus quiet mint cue.
- inactive tab: muted text/icon.
- tab switch: fade or instant; no hero/shared-element tab animations.
- haptic feedback only where it feels native and does not annoy.

### Windows

Use a desktop shell with:

- left rail/sidebar using the same four sections.
- icon + label at normal widths.
- content column around `720px` for focused screens.
- master-detail for `Локации` and `Правила` on wider windows.
- native title bar behavior unless a separate Windows decision requires custom
  chrome.

Rules:

- no mobile bottom tabs on Windows.
- no stretched phone layout on large desktop windows.
- no admin/cabinet density; this remains a consumer client.
- window resize should change layout without animated stretching.

## Screen Rules

### First Launch

Goal: split new and returning users before route setup.

First-layer content:

```text
Добро пожаловать в POKROV
Вы уже пользовались POKROV?

[Я новый пользователь]
5 дней бесплатно

[У меня уже есть доступ]
Восстановить через код
```

Component structure:

- logo/wordmark
- title
- short question
- two action rows or buttons
- optional inline network warning

States:

- initial
- restoring install state
- offline/network issue

Motion:

- buttons fade/translate in `220ms`.
- tap feedback `scale 0.97`, `80ms in / 120ms out`.

Must not appear:

- login/registration wording.
- Telegram as the first required step.
- raw key/manual link entry on the first screen.
- carousel onboarding.

### Country And Route Mode

Goal: choose the routing behavior without technical language.

Country first-layer content:

```text
Ваш основной регион

[Россия]
POKROV настроит российские сервисы, чтобы они работали без перебоев.

[Другая страна]
POKROV включит обычный режим защиты.
```

For Russia, route-mode content:

```text
Режим работы

[Умный режим]
Банки, Госуслуги и маркетплейсы работают без перебоев.
Остальное идет через POKROV.

[Только выбранное]
Вы сами выбираете приложения, которые идут через POKROV.
```

Rules:

- The choice must be editable later in `Правила`.
- For non-Russia, skip detailed route choice in P0 unless product says
  otherwise.
- Presets must be backend-synced and versioned.
- Backend needs a kill-switch for risky rule categories.

Must not appear:

- `split tunneling`, `TUN`, `VpnService`, CIDR, domain rules.
- irreversible language.

### Protection

Goal: one-tap protection control and clear everyday status.

First-layer structure:

1. top status area with POKROV identity and notification/support entry.
2. circular connect control.
3. one status line.
4. location and route-mode chips.
5. service notification when needed.
6. quick actions.

Connect control states:

- disconnected
- connecting
- connected
- enhanced
- error
- expired
- restoring/provisioning

Status copy examples:

- `Не защищено. Нажмите, чтобы включить.`
- `Подключается...`
- `Подключено — Нидерланды`
- `Умный режим — российские сервисы работают без перебоев`
- `Не получилось подключиться`
- `Доступ закончился`

Quick actions:

- `Исключения`
- `Локация`
- `Усиленный режим`
- `Помощь`

Rules:

- `Локация` can deep-link into `Локации`.
- `Помощь` is allowed because consumer users need a visible recovery path.
- Do not show ping in milliseconds.
- Do not show public IP, hostname, protocol, ports, raw profile, or engine name.

Motion:

- tap connect changes UI to `connecting` on the next frame.
- connecting uses a subtle progress ring/sweep, not a spinner.
- status changes crossfade `160-220ms`.
- quick actions fade in with small stagger.

### Locations

Goal: keep auto-location understandable and allow a real manual node choice
when backend data exists.

First-layer content:

- `Автоматически` row first.
- current selected/preferred node state.
- real smart-connect shortlist rows only when returned by backend.
- premium/free pool label where relevant.
- human quality/load label if backed by data.

Location row:

- leading flag or location icon.
- title: country/city.
- subtitle: optional city/provider-friendly label.
- trailing: selected check, lock, or quality label.

Rules:

- Backend returns a short smart-connect shortlist.
- App may measure RTT for shortlist, but backend owns health/load scoring.
- If backend is unavailable, use last cached shortlist.
- Do not switch nodes for tiny wins; keep stickiness.
- Consumer list should not show raw hostnames or IPs.
- Do not show fake countries, fake pings, or demo rows.
- User-selected node is saved through the app-first latency-sample endpoint and
  applied by ordering the next managed profile selector.

States:

- loading skeleton rows.
- list loaded.
- empty/no locations.
- error with retry.
- selected row.

### Rules / Exceptions

Goal: let users choose the device route mode and the apps/processes that use
POKROV.

First-layer content:

- `Режим работы`
- `Что идет через POKROV`
- route choices:
  - `Всё, кроме РФ`
  - `Всё устройство`
  - `Выбранные приложения`
- `Напрямую без POKROV`
- `Выбранные приложения` / Windows `.exe` process picker

Preset row:

- icon
- title
- one-line explanation
- toggle/check state

Rules:

- show the route-mode choice before preset categories.
- keep raw rule editing out of the normal UI.
- ad/tracker blocking stays feature-flagged until rulesets are tested.
- preset catalogue is backend-synced and versioned, but catalog/package
  versions belong in diagnostics/support, not first-layer copy.

Must not appear:

- raw domain/CIDR/regex editor.
- JSON.
- package/process identifiers in normal mobile UI unless user explicitly opens
  app picker.

### Profile

Goal: access, identity, recovery, support, and settings.

Group rows into:

- `Доступ`
  - `Статус`
  - `Подписка`
  - `Оплата`
  - `Кабинет`
- `Привязать доступ`
  - `Код активации`
  - `Telegram +10 дней`
  - `Проверить подписку`
- `Бонусы`
  - `Обновить бонусы`
  - `Бонусы и история`
- `Настройки`
  - `Устройство`
  - `Режим работы`
  - `WARP-защита`
  - `Чат поддержки`
  - `Диагностика`

Rules:

- top access summary shows current access state, paid-until, and bonus-days
  separately.
- do not show UUID as first-layer identity.
- short support ID may appear only inside support.
- expired state is calm and actionable, not a red panic banner.

### Enter Code / Restore Access

Goal: restore or apply access with one user-facing code entry.

First-layer content:

```text
Восстановить доступ
Введите код из Telegram, сайта, письма или подарка.

[code input]
[Продолжить]

Получить код в Telegram
Открыть кабинет
Ручной ввод ключа
```

Rules:

- primary action is in-app code entry.
- `Получить код в Telegram` is a helper, not the default flow.
- `Ручной ввод ключа` is a lower-emphasis fallback.
- raw subscription links trigger a warning before import.
- no separate UX per code type.

States:

- empty.
- typing.
- validating.
- success.
- invalid/expired code.
- network error.

### Email And Cabinet

Goal: optional recovery and browser continuation.

First-layer content:

- `Email и кабинет`
- explanation that email helps recovery and opening cabinet.
- email field if not linked.
- `Привязать email`.
- `Открыть кабинет` when linked.

Cabinet token rules:

- token is short-lived and single-use.
- UI should show that the browser session is temporary.
- do not make email mandatory for core app path.

### Telegram Bonus

Goal: optional Telegram link and `+10 days`.

First-layer content:

```text
Подключите Telegram и получите +10 дней.
Telegram помогает восстановить доступ и быстро связаться с поддержкой.
```

States:

- not linked.
- waiting for Telegram.
- linked, membership check needed.
- eligible to claim.
- claimed.
- already linked/no reward available.

Rules:

- use deep links where possible.
- fallback instruction has no more than two steps.
- `Получить +10 дней` is active only after eligibility is verified.
- Telegram is never required for the normal app path.

### Bonuses Hub

Goal: show loyalty benefits without cheap game energy.

P0 content:

- bonus summary.
- referral summary/link.
- promo code entry.
- bonus history.
- Telegram reward state.

Feature-flagged:

- roulette/wheel.
- activity calendar.
- achievements/streaks.

Rules:

- paid days and bonus days are visually separate.
- no casino animation, confetti, sounds, or main-screen roulette.
- do not show dead roulette/calendar UI before public API exists.

### Paywall / Subscription

Goal: sell comfort and access honestly.

Rules:

- implement after approved plan names, prices, renewal terms, and payment
  methods are confirmed.
- show plan rows/cards, one selected plan, price, period, terms, payment CTA.
- clearly separate paid time and bonus days.
- auto-renewal wording must be readable and explicit.
- no countdown timers, fake scarcity, or unsupported premium claims.

Copy:

- `Полный доступ`
- `Оформить`
- `Оплатить`
- `Выгодно` only when business-approved.

### Support And Diagnostics

Goal: help users without exposing secrets.

First-layer content:

- `Поддержка`
- `Написать в поддержку`
- `Частые вопросы`
- `Прикрепить диагностику`
- connection failure card:
  - `Сменить локацию`
  - `Включить усиленный режим`
  - `Написать в поддержку`
  - `Приложить диагностику`

Diagnostics rules:

- show what will be sent before upload.
- redact secrets, raw links, IPs, keys, and tokens.
- diagnostics export belongs in support/advanced, not normal UI.

### Advanced Diagnostics

Goal: give testers and support useful facts without making advanced settings a
normal user task.

First-layer content:

```text
Диагностика
Системные параметры для теста и поддержки.

Версия приложения
Core
Windows-подключение
TUN по приложениям
WARP
Совместимый режим
Логи и диагностика
```

Rules:

- do not show a scary checkbox just to view diagnostics.
- no raw JSON, raw subscription editor, CIDR, hostnames, ports, or protocol
  settings in this sheet.
- dangerous/raw rule editing remains out of the beta normal UI until a separate
  implementation adds validation, second confirmation, and rollback.
- Enhanced protection must stay gated until runtime proof is present. When the
  backend/runtime does not mark it offerable for the current device, Home,
  Profile, and Advanced hide the normal control instead of rendering a `Скоро`
  preview.

## Component Rules

### Connect Control

- circular system control, target `128dp`.
- `RepaintBoundary` required.
- states: disconnected, connecting, connected, enhanced, error, expired,
  restoring.
- connecting uses progress ring/sweep.
- connected uses emerald fill.
- error uses calm danger state.
- expired uses disabled/sage state.
- no flame, mascot, particle, neon, or outer glow.

### Buttons

- primary: emerald fill, white text, `48dp+` height.
- secondary: surface/outline.
- destructive: muted danger text or soft surface, no loud red fill by default.
- loading preserves size.
- pressed state: scale `0.97`, `160ms`.

### Chips

- height around `32dp`.
- use for route mode, location, access status.
- max two chips in the Protection status area.
- active uses emerald/mint.
- inactive uses surface/muted text.

### List Row

- height at least `56dp`.
- leading icon/flag.
- title.
- optional one-line subtitle.
- trailing status/chevron/toggle.
- divider or spacing; do not box every row.

### Location Row

- flag or location icon.
- title.
- optional city/subtitle.
- human quality label or subtle line.
- selected check.
- no aggressive signal bars.

### Ruleset Preset

- one row/card, not nested.
- icon, title, subtitle, toggle.
- optimistic toggle with backend reconciliation.
- disabled state when ruleset is unavailable.

### Text Field / Code Input

- input height around `56dp`.
- focus border emerald.
- error under field.
- code input uses grouped formatting.
- paste-from-clipboard action allowed.
- layout must not jump on error.

### Bottom Sheet / Dialog

- mobile: bottom sheet with drag handle.
- Windows: centered dialog or side panel.
- sheet/dialog open `280-320ms`.
- no full-screen modal for simple notices.

### Warning Gate

- icon.
- short warning text.
- checkbox.
- primary disabled until accepted.
- secondary cancel always visible.

### Skeleton / Empty / Error

- skeletons match final layout dimensions.
- no full-screen spinner-only loading state.
- empty state: icon, one text block, one action when useful.
- error state: calm text, retry, optional support action.

## Motion Rules

Durations:

- `160ms`: tap, chip, toggle.
- `220ms`: tab/screen fade, status crossfade.
- `280-320ms`: bottom sheets, larger transitions, connect resolution.

Properties:

- animate transform and opacity in hot paths.
- never animate width, height, top, left, padding, or margin in hot paths.

State rules:

- optimistic UI for connect, location choice, route preset toggles.
- connection feedback must appear immediately.
- no blocking full-screen spinner for connect/disconnect.
- tab state must persist across navigation.
- list scroll position must persist across tab changes.

Reduced motion:

- fade-only or instant state changes.
- no sweep, pulse, scale, slide, shake, or shimmer.

Flutter hints:

- `IndexedStack` for root tabs.
- `AutomaticKeepAlive` for list-heavy tabs.
- `ListView.builder` for lists.
- `RepaintBoundary` around connect control and hot animated surfaces.
- `AnimatedSwitcher` for status swaps.
- `TweenAnimationBuilder`/custom animation only for transform/opacity.
- `MediaQuery.disableAnimations` must be honored.
- `mounted` checks after async work.

## Implementation Phases

### Phase 0: Decisions Before UI Build

- provenance/license decision for Pokrov-based work.
- final runtime gate direction.
- connect-control fixed to circular `128dp` progress-ring control.
- final smart-mode copy.
- approved paywall plan names/prices/renewal text.
- feature flags for roulette, calendar, ad/tracker blocking.

### Phase 1: Foundation And Shell

- typed Flutter theme from tokens.
- light and dark themes.
- mobile shell with four tabs.
- Windows rail/sidebar shell.
- shared screen scaffolds.
- base components: buttons, chips, rows, skeleton, banners.

### Phase 2: Core User Path

- First Launch.
- Enter Code / Restore Access.
- Country and Route Mode.
- Protection with all connection states.
- Profile access summary.

### Phase 3: Daily Use Screens

- Locations.
- Rules / Exceptions.
- Telegram bonus.
- Email and cabinet.
- support entry and connection failure card.

### Phase 4: Monetization And Advanced

- Paywall after plan approval.
- Support diagnostics upload.
- Advanced warning gate.
- reset to recommended.
- validation and rollback UX.

### Phase 5: Loyalty And Polish

- Bonuses hub summary/referral/promo/history.
- roulette/calendar only after public API and feature flags.
- Windows master-detail.
- reduced-motion pass.
- accessibility and Russian text overflow audit.

## Review Checklist

Reject a design or PR if it contains:

- technical transport names in normal UI.
- raw subscription links as normal account proof.
- Telegram/email as mandatory first step.
- generic dark VPN aesthetics.
- gamer/neon/glow/flame visuals.
- unsupported claims.
- central `VPN` tab.
- more than four mobile tabs.
- bottom tabs on Windows.
- nested cards.
- full-screen spinner-only loading.
- layout jumps across states.
- layout-property animations in hot paths.
- ping in milliseconds on the Protection screen.
- roulette/calendar visible without public API and feature flag.
- paywall copy without approved plan/renewal facts.
- unredacted diagnostics.
- Russian text overflow.

## Build-Ready Summary

Start with tokens, shell, and connect state. Then implement restore, route setup,
Protection, Locations, Rules, Profile, and support. Keep every screen calm,
stateful, and honest. The UI should feel fast because it responds immediately,
not because it hides complexity behind animation.
