# POKROV Client UX, Account, And Rewards Master Brief

Date: 2026-06-03
Status: product direction brief
Decision owner: owner/operator

## Purpose

Collect the current product direction for the future POKROV Android and Windows
client after the local Pokrov/Karing/Happ review, screenshot review, and
OpenCode consilium passes.

This is not an implementation plan and does not claim that the new app is built.
It is the shared brief for the client spike and later detailed specs.

## Source Inputs

- Owner direction in the 2026-06-03 discussion.
- Screenshots in `C:/Users/kiwun/Documents/ai/VPN/.tmp/design 0306`.
- Local source/material review:
  - Pokrov as primary base candidate.
  - Karing as feature reference.
  - Happ as UX and packaging reference.
- OpenCode-go consilium passes:
  - `deepseek-v4-pro`
  - `qwen3.7-max`
  - `minimax-m3`
  - `glm-5.1`
  - `kimi-k2.6`
  - `mimo-v2.5-pro`
- Current platform/client canon from the platform docs and `POKROV-app/docs`.

## Reference Feature Sources

Use the reviewed clients with clear roles:

- Pokrov: primary technical base candidate, especially `sing-box` runtime,
  route-rule model, profile parsing, WARP/chain settings, and Flutter
  Android/Windows structure.
- Karing: feature reference for rule groups, DNS behavior, per-app routing,
  diagnostics, novice mode, backup/sync, WARP account surfaces, and network
  checks.
- Happ: UX and packaging reference for a polished consumer mobile/desktop
  product, server/settings/paywall/support completeness, Windows installer
  behavior, Android service surfaces, and platform affordances.

Do not blend source code across projects until a separate provenance/license
decision says what can be copied, forked, or only studied.

## Core Product Rule

The user has one POKROV access state.

The app, Telegram bot, marketing checkout, and web cabinet are different doors
into the same account family, not separate products.

Rules:

- A new user starts from the app and gets the app-first trial.
- A returning user restores existing access with a code or claim flow.
- Buying or receiving access in app, bot, site, cabinet, email, or gift flow must
  resolve to the same managed access state.
- Telegram and email are optional linked identities, not login walls.
- Raw subscription links remain manual or recovery fallback only.
- Bonus days are separate from paid access in UI copy and accounting.

## Primary App IA

Target top-level app shell:

1. `Protection`
2. `Locations`
3. `Rules`
4. `Profile`

Nested under `Profile`:

- `Your access`
- `Activate key`
- `Email and cabinet`
- `Telegram +10 days`
- `Devices`
- `Bonuses`
- `Support`
- `Settings`
- `Advanced` behind a warning gate

`Rewards` / `Bonuses` is an inner hub, not a first-launch wall and not the main
screen.

The screenshot direction is useful for density and hierarchy, but the final
POKROV app should be calmer: one clear protection screen, understandable
location choice, explicit exceptions/rules, and a profile center that hides raw
technical machinery.

## First Launch

The first launch must split new and returning users before route-mode setup.

Screen:

```text
Добро пожаловать в POKROV
Вы раньше пользовались POKROV?

[Я новый пользователь]
5 дней бесплатного доступа

[У меня уже есть доступ]
Восстановить через код из Telegram, кабинета или письма
```

### New User Path

1. Create or reuse `install_id`.
2. Call app-first trial bootstrap.
3. Grant the canonical `5 days` trial.
4. Ask country / Russia-aware routing setup.
5. Ask route-mode choice.
6. Provision managed profile silently.
7. Land on `Protection`.
8. Offer Telegram link for `+10 days` as an optional follow-up, not a wall.

### Returning User Path

The returning-user restore screen offers:

- `Enter code`
- `Get code in Telegram`
- `Open cabinet`
- `Paste key manually`

Safe linking rule:

- one-time claim/link codes may link an existing bot/site/cabinet account to the
  app install/account.
- raw subscription links must not be treated as identity proof.
- if a raw connection link is pasted, handle it only as a compatibility/manual
  import fallback and explain that a one-time code is safer for account linking.

Supported one-time or redeemable code families:

- Telegram link code
- cabinet claim token
- email magic code
- recovery code
- access key
- gift code
- promo code

For current Telegram users, the preferred path is:

1. App asks `Вы раньше пользовались POKROV?`.
2. User chooses `У меня уже есть доступ`.
3. User gets a one-time code from the Telegram bot, cabinet, or email.
4. App submits the code through unified redeem.
5. Backend links the app install/account to the existing account family.
6. App, bot, and cabinet refresh the same access state.

## Country And Route-Mode Setup

After account/trial/restore is resolved, ask the route question.

Country screen:

```text
Где вы чаще всего пользуетесь POKROV?

[Россия]
POKROV настроит российские сервисы напрямую.

[Другая страна]
POKROV включит обычный безопасный режим.
```

For `Россия`, show the route-mode screen:

```text
Как этому устройству работать?

[Умный режим]
Банки, Госуслуги и маркетплейсы работают напрямую.
Остальное - через POKROV.

[Только выбранное]
Вы сами выбираете приложения, которые идут через POKROV.
```

Internal mapping:

- `Умный режим` maps to the device-wide default with Russia-aware direct rules.
- `Только выбранное` maps to selected-apps split tunneling.
- `Full tunnel` remains available later as an advanced or secondary route mode.
- The choice must round-trip through backend-owned route-mode state.

## Protection Screen

The main screen should be simple and alive, not a technical dashboard.

Required states:

- disconnected
- connecting
- connected
- connected with enhanced mode
- error
- subscription expired
- restoring/provisioning

First-layer content:

- large connect/disconnect button
- clear status line
- current route mode
- current auto location
- access/trial summary
- service status or important notification
- quick actions:
  - `Exceptions`
  - `Location`
  - `Enhanced mode`
  - `Help`

Top utility actions from the screenshot direction:

- support/chat
- Telegram/channel entry
- bonuses or loyalty entry
- notifications

Avoid:

- raw profile links
- public IP
- ports
- protocol names
- hostnames
- JSON editors
- CIDR/regex rule editors
- technical engine names in normal UI

Preferred copy examples:

- `Не защищено. Нажмите, чтобы включить.`
- `Подключено - Нидерланды - 42 мс`
- `Умный режим - российские сервисы напрямую`
- `Есть проблема с подключением`

## Locations

Locations should support:

- auto-select as the default
- clear current location
- free/premium availability
- human load or speed labels
- manual selection as an understandable override

Smart-connect should be backend-first:

- backend builds shortlist
- app measures RTT
- scoring combines RTT, health, backend penalty, CPU/load penalty, and stickiness
- do not switch nodes for tiny wins
- avoid overloading a single node

This gives the product the desired behavior: if many users are on one node, new
users can be steered to a healthier node without making the client feel random.

## Rules

Normal users should see presets, not a raw routing editor.

Preferred labels:

- `Исключения`
- `Что идет напрямую`
- `Без POKROV работают: N приложений`

Presets:

- Russian banks
- Gosuslugi and official services
- marketplaces
- games
- video
- messengers
- add app
- ad/tracker blocking, only when backed by maintained rulesets and tested
  behavior

Advanced-only:

- raw rule editor
- package/process identifiers
- domains
- CIDR
- regex
- low-level routing logic

The ruleset catalogue should be backend-synced and versioned.

## Enhanced Mode

Pokrov WARP/chain capabilities should be exposed as a human feature.

Preferred label:

- `Усиленный режим`

Copy:

```text
Может помочь, если сайт не открывается.
Меняет выходной IP, но иногда снижает скорость.
```

Do not claim absolute anonymity.

Architecture note:

- Prefer integration inside the `sing-box` routing/chain model.
- Do not create a second system VPN tunnel that conflicts with Android
  `VpnService` or Windows tunnel behavior.

## Profile

Profile is the access and identity center, not a reward dumping ground.

Recommended sections:

- `Your access`
  - current access state
  - paid until
  - bonus days, separately labelled
  - source when useful: app, Telegram, site, gift, promo
- `Activate key`
  - unified code entry
  - paste from clipboard
  - support fallback
- `Email and cabinet`
  - email link/recovery
  - open cabinet through short-lived session token
- `Telegram`
  - link status
  - `+10 days` claim path
- `Devices`
  - count and management
- `Bonuses`
  - entry to rewards hub
- `Support`
  - app ticket and Telegram fallback

The profile should not show UUID as the first thing. A short public ID may exist
for support, but access state and recovery actions matter more.

## Rewards Hub

Rewards are a secondary loyalty layer.

Required distinction:

- paid access
- bonus days
- points
- promo benefits

Potential sections:

- Telegram bonus `+10 days`
- roulette / wheel
- activity calendar
- daily streak / achievements when backed by a server ledger
- referral link
- promo codes
- points
- bonus history

MVP should not turn the app into a noisy game surface.

## Telegram Bonus

Current canon:

- Telegram is optional.
- Telegram reward is `+10 days`.
- The channel bonus is server-verified and explicitly claimed.

Flow:

1. App requests a Telegram link start code.
2. User opens the bot with that code.
3. Bot links Telegram identity to the app-first account.
4. App checks channel membership.
5. User explicitly claims `+10 days`.
6. Backend grants the bonus and syncs access.
7. App, bot, and cabinet refresh from the same access state.

Copy:

```text
Подключите Telegram и получите +10 дней.
Telegram помогает восстановить доступ и быстро связаться с поддержкой.
```

## Email And Cabinet

Email is for recovery and browser continuation.

Cabinet is a continuation surface, not a second landing page.

Required backend capability:

- app requests a short-lived cabinet session token
- token is single-use
- token expires quickly, target `60-120 seconds`
- cabinet exchanges the token for a normal browser session

Copy:

```text
Привяжите email, чтобы открыть кабинет в браузере и восстановить доступ,
если потеряете устройство.
```

## Unified Redeem

The future app should have one user-facing code entry.

User copy:

```text
Введите код из Telegram, сайта, письма или подарка.
Доступ обновится в этом аккаунте.
```

Target endpoint:

```text
POST /api/redeem
```

Accepted code families:

- activation key
- paid access key
- gift code
- promo code
- Telegram link code
- cabinet claim token
- email magic code
- recovery code

The backend may route to existing services internally, but the app should not
need separate UX for every code type.

Security rule:

- link codes link identities.
- access keys grant or extend access.
- promo/gift codes apply their own benefits.
- raw subscription links do not prove account ownership.
- third-party/custom subscription links become manual local profiles in
  advanced/recovery mode, not POKROV account proof and not a bonus/payment
  source.

## Bonus API

The API should be shaped before the app promises bonus surfaces.

Recommended public app contract:

- `GET /api/bonuses/summary`
- `POST /api/bonuses/channel/check`
- `POST /api/bonuses/channel/claim`
- `GET /api/bonuses/wheel/state`
- `POST /api/bonuses/wheel/spin`
- `GET /api/bonuses/calendar`
- `POST /api/bonuses/calendar/checkin`
- `GET /api/bonuses/referral/summary`
- `POST /api/bonuses/promo/redeem`

Current reality:

- bot wheel exists
- admin wheel config exists
- user payload exposes `last_wheel_spin`
- a public app wheel-spin endpoint still needs to be added before app roulette
  can be claimed as live

Priority rule:

- define the bonus API contract in P0 even if only summary/channel/referral
  status is live at first.
- keep roulette and calendar UI behind feature flags until public app endpoints
  for spin/check-in exist.

## Bot Parity

The Telegram bot becomes another interface to the same account.

It should show:

- subscription/access status from the same account family
- purchases from app/site/bot
- redeem result
- bonus state
- roulette cooldown if shared
- referral state
- support entry
- cabinet/app links

If a user buys in app:

```text
Доступ активен до 15 июня.
Источник: приложение.
```

If a user buys in bot:

```text
Доступ активен до 15 июня.
Источник: Telegram.
```

## Target API Surface

The detailed implementation plan should map current backend routes to these
future app capabilities:

- app-first bootstrap and trial state
- route-mode read/update
- managed profile delivery
- unified redeem
- Telegram link/start/check/claim
- email link/recovery
- short-lived cabinet session token
- bonus summary, wheel, calendar, referral, promo
- service notification feed
- support ticket plus redacted diagnostics upload
- node shortlist and health/load-aware smart-connect metadata

## Advanced Settings

Advanced settings are allowed, but behind a clear gate.

Entry warning:

```text
Расширенные настройки могут нарушить подключение.
Если не уверены, лучше напишите в поддержку.
```

Checkbox:

```text
Я понимаю, что неправильные настройки могут сломать подключение.
```

Second confirmation:

```text
Открыть расширенные настройки?
[Отмена]
[Да, открыть]
```

Advanced contents:

- custom subscription/key
- DNS
- Xray fallback
- raw rules
- logs
- diagnostics export
- reset to recommended settings

Mandatory control:

- `Reset to recommended`
- validation before apply
- automatic rollback if the new config fails

## Paywall And Subscription

Paywall should sell comfort and access, not raw technical plans.

Recommended:

- `Full access` / `Полный доступ`
- highlight a mid-term plan such as `3 months` when business-approved
- show payment methods before checkout
- clearly separate paid time and bonus days
- do not surface UUID/account ID in the first layer
- keep auto-renewal copy honest and readable
- do not promise `YouTube без рекламы`, `без ограничений`, support SLA, or
  other premium claims unless the backend, rulesets, support process, and legal
  copy can support them

## Service Notifications And Support

The app should have service-status messaging, not a raw Telegram feed dump.

Types:

- incident
- maintenance
- tip
- payment/support notice

Connection failure card:

```text
Не получилось подключиться

[Сменить локацию]
[Включить усиленный режим]
[Написать в поддержку]
[Приложить диагностику]
```

Diagnostics should be redacted and support-safe.

## Claims And Compatibility Guardrails

- Do not make Telegram or email mandatory for the core app path.
- Do not use raw subscription links as account-ownership proof.
- Do not expose raw links, ports, hostnames, JSON, CIDR, protocols, or engine
  names in normal UI.
- Do not claim absolute anonymity.
- Do not claim stable `1.0.0`, store availability, trusted Windows signing, or
  RU-origin readiness without current evidence.
- Do not let bot, app, and cabinet drift into separate subscription stories.
- Do not make Happ's Xray/TUN architecture the default POKROV architecture.
- Keep Xray fallback advanced-only; normal runtime remains `sing-box`.

## Priority Plan

### P0

- Pokrov-based spike base decision and runtime gate.
- First-launch `new / returning` split.
- Returning-user restore screen.
- Unified redeem API contract.
- Safe one-time claim/link code semantics.
- App profile basics:
  - access state
  - activate key
  - Telegram link
  - email/cabinet entry
  - support
- Telegram `+10 days` link/check/claim in app.
- Bot parity for subscription/access status.
- Short-lived cabinet token.
- Bonus API contract and MVP endpoints for summary, channel status/claim,
  referral status, and promo/redeem status.
- Smart-connect shortlist and route-mode sync remain aligned with current canon.
- Claims guardrails for ad-blocking, YouTube, anonymity, support, and release
  maturity.

### P1

- Rewards Hub light:
  - bonus summary
  - referral summary
  - points summary
  - wheel state if API exists
- App-facing wheel spin endpoint and roulette UI.
- App-facing calendar check-in endpoint and activity calendar summary.
- Support diagnostics flow.
- Paywall/subscription UX cleanup.
- Rules presets UI.
- Email recovery polish.

### P2

- Full activity calendar.
- Achievements in app.
- Rich referral UI.
- Promo slots in app.
- Advanced raw rule editor.
- More detailed cabinet/account management.
- Windows-specific process picker and advanced support tooling.

## One-Line Product Summary

New users start in the app; returning users restore with a safe code; purchases
and bonuses sync across app, bot, site, and cabinet; Telegram and email help but
never block the core POKROV experience.
