# Client Best MVP Build Brief

Date: 2026-06-03
Status: ready for owner review

## Goal

Build the smallest POKROV client MVP that feels premium, understandable, and
credible enough for owner approval before full production build-out.

The first approval build should answer one user promise:

> Open POKROV, connect, understand what mode is active, and get help inside the
> app without seeing protocol or account machinery.

## Screens In MVP

### Home / Protection

Must show:

- brand mark and POKROV wordmark.
- status dot and short label.
- one primary connect disc.
- location chip.
- route-mode chip.
- optional calm recovery banner.
- disabled WARP tile.

Must not show:

- welcome paragraphs.
- Telegram/cabinet/email CTAs.
- restore prompts.
- bonus copy.
- news feed.
- fake ping charts.
- protocol names, raw hostnames, raw config links, or engine labels.

Home copy budget: `10-25` visible words in normal state.

WARP tile:

```text
Расширенная приватность
WARP · готовится
```

Tap opens a short bottom sheet explaining that the feature is being prepared
and is not active in this build.

### Locations

MVP keeps the list simple:

- auto location row.
- current shortlist/region rows when profile data is present.
- clear loading skeleton.
- empty state if profile is not ready.
- no fake country catalogue.

### Rules

MVP shows only consumer-safe routing choices:

- `Все, кроме РФ`.
- `Все устройство`.
- `Выбранные приложения` with honest beta/limited wording where OS-level
  selection is not complete.

No raw ruleset editor in first layer.

### Profile

Use grouped settings sections:

1. `План и доступ`
2. `Синхронизация`
3. `Приложение`
4. `Поддержка`
5. `Расширенные`

Rows should be title + short value + chevron/toggle. Long explanatory text goes
to detail sheets, not the main list.

### Support Chat

Support is a full route or stable pane, not a bottom-sheet link hub.

Must include:

- header state: `AI помощник`, `В очереди`, `Оператор на связи`, or
  `Нет соединения`.
- message list.
- composer.
- send button.
- attach diagnostics action.
- Telegram fallback footer.

MVP local/mock mode is allowed only when clearly labelled. Do not fake live
operator activity.

Diagnostics preview allowlist:

- app version.
- platform and OS.
- route mode.
- connection status.
- entitlement state.
- recent error category.
- selected region/country when safe.
- DNS/uplink health summary when available.

Diagnostics forbidden fields:

- raw config.
- subscription URLs.
- access keys.
- private links.
- panel URLs.
- server topology.
- raw IP lists.
- WireGuard/WARP account material.

## Windows Responsiveness

Breakpoints:

- `>= 1180px`: expanded sidebar, `224-240px`, labels visible.
- `900-1179px`: collapsed icon rail, `64-72px`, labels hidden.
- `700-899px`: drawer/overlay sidebar opened from hamburger.
- `< 700px`: single-column mobile-like stack.

Rules:

- content reading width must stay at least `360px`.
- sidebar collapses before content becomes unreadable.
- settings rows stack before long Russian strings wrap into one-letter columns.
- compact values use ellipsis or move into detail sheets.
- review widths: `360`, `700`, `900`, `1024`, `1180`, `1440`.

## Motion

Motion is polish after layout stability.

Allowed in MVP:

- connect disc press scale `0.97`.
- finite ring sweep during connecting.
- status crossfade.
- sidebar collapse `200-220ms`.
- page/tab fade plus small translate.
- row/chip press feedback.
- geometry-matched skeletons.

Rules:

- transform and opacity only for hot paths.
- respect `MediaQuery.disableAnimations`.
- no permanent idle spinners.
- no neon, particles, confetti, animated gradients, parallax, or heavy bounce.

## Runtime And WARP

Hiddify WARP support is treated as a runtime primitive.

MVP does not activate it. Real activation requires:

- Android and Windows proof.
- backend managed-profile policy.
- WARP account/config provisioning path.
- fallback behavior.
- support diagnostics.
- owner-approved copy.

## Support API Strategy

Create client code around a `SupportService` abstraction.

Implementation may initially map to existing `/api/tickets*` endpoints because
app-session ticket creation already works.

If backend time allows, add a thin `/api/client/support/*` facade over the
ticket repo. The UI should not care which path is active.

## Build Order

1. Fix Windows responsive shell.
2. Regroup Profile.
3. Simplify Home and add disabled WARP tile.
4. Build support chat UI with local mock state.
5. Add diagnostics preview model.
6. Wire support through adapter.
7. Add motion pass and skeletons.
8. Run responsive and widget test review.

## Owner Approval Checklist

- Home is simple enough to understand in five seconds.
- Windows layout no longer breaks at narrow widths.
- Profile no longer feels like a long technical list.
- Support feels like an app-native chat, not a browser/Telegram redirect.
- WARP is visible as a future feature without claiming it works.
- No fake data, fake operators, fake timers, or unsupported claims.
