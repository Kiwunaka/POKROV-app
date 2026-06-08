# Client Chat, Responsive Shell, WARP, And Motion Brief

Date: 2026-06-03
Status: implementation-ready direction

## Priority

Build in this order:

1. Windows responsive shell and sidebar collapse.
2. Account/Profile IA regroup.
3. Embedded support chat shell with local AI/mock and diagnostics preview.
4. Honest WARP/enhanced privacy Home tile.
5. Restrained motion/premium pass.
6. Real support API integration and operator escalation.

The order matters. If layout is still broken on Windows, new surfaces will look
broken too.

## Windows Responsive Shell

Breakpoints:

- `>= 1180px`: expanded sidebar, `224-240px`, labels visible.
- `900-1179px`: collapsed icon rail, `64-72px`, labels hidden, hover tooltips.
- `700-899px`: sidebar as drawer/overlay opened by hamburger in the top bar.
- `< 700px`: single-column mobile-like stack; no persistent sidebar.

Rules:

- The sidebar collapses before the content can shrink into unreadable rows.
- Effective content reading width should not fall below `360px`.
- Account and settings rows must never wrap one character per line.
- At compact widths, row layout switches from horizontal
  `icon / title / value / chevron` to stacked `icon + title`, value below.
- Text values use `maxLines: 1`, ellipsis, or disappear behind a detail screen
  when the row is too narrow.
- Card/page padding reduces at compact widths:
  - page: `24px -> 16px`
  - card: `18px -> 12-14px`
- Add responsive review widths: `360`, `700`, `900`, `1024`, `1180`, `1440`.

## Account/Profile IA

Avoid one long flat row list.

Use grouped sections:

- `План и доступ`
  - tariff/access state
  - trial or expiry
  - renew/upgrade action
  - Telegram bonus state
- `Синхронизация`
  - email
  - Telegram link state
  - redeem/restore code
- `Приложение`
  - language/theme/notifications when implemented
  - diagnostics
  - version
- `Поддержка`
  - embedded chat
  - feedback
  - Telegram fallback
- `Расширенные`
  - raw key/subscription recovery
  - xray fallback
  - reset to recommended settings

Account must not duplicate Home connection status or node selection except as
short diagnostic context behind a detail action.

## Embedded Support Chat

Target UI:

- full route or stable side pane, not a temporary Telegram handoff sheet
- header with support state:
  - `AI помощник`
  - `В очереди`
  - `Оператор на связи`
  - `Нет соединения`
- message list:
  - user bubbles on the right
  - AI/operator bubbles on the left
  - system events centered and muted
- composer:
  - text field
  - attach button
  - send button
- attach menu:
  - `Диагностика приложения`
  - `Журнал подключения`
  - optional screenshot later

Diagnostics rules:

- User must see what will be included before sending.
- Allowed fields:
  - app version
  - platform and OS
  - route mode
  - connection status
  - recent error category
  - selected region/node country when safe
  - entitlement state such as trial/premium/free
- Forbidden fields:
  - raw config
  - keys
  - subscription URLs
  - panel URLs
  - server topology
  - full node list
  - raw IP lists unless explicitly redacted

Mock rules:

- Local canned AI replies are allowed.
- Local history and offline queue are allowed.
- Do not fake live operator responses.
- Do not show fake ticket IDs, SLA timers, or cross-device sync.
- Telegram fallback appears as a secondary footer/header action.

## Support API Direction

Target app-facing endpoints:

- `POST /api/support/sessions`
- `GET /api/support/sessions/{id}/messages?cursor=...`
- `POST /api/support/sessions/{id}/messages`
- `POST /api/support/sessions/{id}/attachments`
- `POST /api/support/sessions/{id}/escalate`
- `GET /api/support/sessions/{id}/status`
- optional `GET /api/support/sessions/{id}/messages/stream`

Bridge to existing ticketing only after the app session is created and the user
asks for operator escalation or the AI helper cannot answer.

## WARP / Enhanced Privacy On Home

Home may show an enhanced privacy tile before runtime support exists only if it
is visibly not active:

```text
WARP · Расширенная защита
Готовится / Доступна / Включится при подключении
```

Rules:

- no active-looking state until backend policy is runtime-ready and the user has
  explicitly consented
- no anonymity, no-restrictions, or ad-free claims
- tap opens a bottom sheet:
  - what the feature is intended to do
  - current state: preparing / not active in this build
  - explicit consent only when runtime-ready material exists

When runtime is wired and verified on Android and Windows, this can become a
real control with a one-line tradeoff:

```text
Может снизить скорость и повлиять на совместимость сервисов.
```

## Motion / Premium Layer

Use motion after layout and IA are stable.

Allowed:

- sidebar collapse: `200-220ms`, ease out
- page/tab transition: `180-240ms`, fade plus `8-12px` translate
- row/card tap: `scale 0.97-0.98`, `100-140ms`
- chat send button feedback: short scale or opacity response
- skeletons for chat history and async panels
- subtle status pulse only when connected and reduced motion is off

Rules:

- transform and opacity only for hot paths
- respect reduced motion
- no particles, confetti, neon, animated gradients, parallax, or heavy bounce
- do not animate layout while fixing responsive bugs
