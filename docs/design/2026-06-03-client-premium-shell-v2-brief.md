# POKROV Client Premium Shell V2 Brief

Date: 2026-06-03
Status: owner-feedback override / implementation direction
Decision owner: owner/operator

> Owner override (`2026-08-11`): the large logo-led connect disc described below
> is retained as historical design context but is no longer the implementation
> direction. The active control is the compact wide CTA defined in `DESIGN.md`
> and `2026-06-03-client-screen-component-rules.md`.

## Purpose

Record the post-MVP design correction after the owner rejected the first
Flutter MVP shell as too cheap, text-heavy, unpredictable, and not responsive.

This document supersedes the `Quiet Emerald` direction for the next UI pass.
The earlier files remain useful historical context, but the next implementation
must follow this V2 brief when there is a conflict.

## Consilium Inputs

OpenCode-go models used:

- `opencode-go/deepseek-v4-pro`
- `opencode-go/qwen3.7-max`
- `opencode-go/minimax-m3`
- `opencode-go/glm-5.1`
- `opencode-go/mimo-v2.5-pro`
- `opencode-go/kimi-k2.6`

The prompt asked the models to critique the current shell harshly, avoid project
file access, and return practical implementation rules for an Apple-grade,
premium, platform-native Android and Windows client.

Brand/control addendum, later on `2026-06-03`, used the same external-review
role with `opencode-go/deepseek-v4-pro`, `opencode-go/qwen3.7-max`,
`opencode-go/minimax-m3`, `opencode-go/glm-5.1`,
`opencode-go/mimo-v2.5-pro`, and Fireworks Kimi
`fireworks-ai/accounts/fireworks/models/kimi-k2p6`.

The addendum agreed that the next premium lift is not another layout expansion.
It is a real raster brand mark, a single tactile connect disc, and a tighter
state-motion system.

## Verdict

The current MVP fails because it behaves like a mobile onboarding article
stretched onto Windows. The primary action is buried under setup cards,
paragraphs, repeated CTAs, and bottom navigation that does not belong on
desktop.

The next pass should not restyle the current card feed. It should replace it
with a platform-aware shell: one calm home screen, flat lists, predictable
navigation, and copy that does not ask the user to read before connecting.

## New Information Architecture

Top-level product areas:

1. `Connect` / `Protection`
2. `Locations`
3. `Rules`
4. `Account`

Depth rules:

- `Connect` is the default root and covers 90 percent of daily use.
- `Locations` can be a desktop page and a mobile sheet; it should not compete
  with the main connect action.
- `Rules` is for routing mode and app/category exceptions.
- `Account` owns subscription, trial, Telegram bonus, restore code, cabinet,
  devices, support, and advanced entry.
- `Advanced` is never a first-level normal-user surface. It opens behind a
  responsibility warning and confirmation.

First screen content:

- connection status
- one connect/disconnect action
- current location
- current route mode
- at most one short alert line when needed

Everything else moves away from the first screen.

## Desktop Layout

Windows must not use mobile bottom navigation.

Use:

- native title bar behavior or a minimal drag region
- left sidebar or navigation rail
- content stage centered in the remaining area
- default window around `900-960px` wide and `600-640px` high
- minimum width around `800px`
- optional right rail only on wide layouts for account/subscription summary

Reject:

- custom black brand bar
- bottom tab bar on Windows
- one long mobile column stretched inside a desktop window
- giant rounded info cards
- nested cards
- repeated connect buttons

Home desktop structure:

```text
Sidebar       Main stage
Connect       Status
Locations     Connect / Disconnect
Rules         Location chip
Account       Route-mode chip
```

Keyboard rules:

- `Space`: toggle connect when focus is safe
- `Esc`: close modal or sheet
- `Ctrl/Cmd + 1..4`: switch top-level area

## Mobile Layout

Mobile can keep bottom navigation, but it must be small and stable.

Use:

- top identity/status line
- centered connect control
- two chips below it: location and route mode
- bottom navigation with no more than three or four items
- bottom sheets for location and app selection
- full-screen account/settings flows only when the user explicitly enters them

Reject:

- long explanatory scroll on Home
- setup cards after first launch
- text paragraphs near the connect button
- active-looking advanced or WARP controls on Home before runtime proof exists
- more than one primary CTA on the first screen

## First Screen Copy Budget

Target: `10-25` words total, depending on state.

Allowed examples:

- `Подключено`
- `Не подключено`
- `Подключение...`
- `Подключить`
- `Отключить`
- `Нидерланды`
- `Авто`
- `Все, кроме РФ`
- `Триал: 3 дня`

Delete from Home:

- welcome paragraphs
- how-it-works explanations
- Telegram/cabinet CTAs
- restore-code prompts
- bonus copy
- active-looking WARP/enhanced copy
- duplicated status explanations

## Component Rules

Primary button:

- one per screen
- stable size
- `56-64px` height or equivalent circular control
- filled accent state
- press state via `transform` and opacity only

Status:

- one word plus color dot or subtle ring
- no large status card
- no glow or constant pulse in idle state

Chips:

- location and route mode only on Home
- tap opens sheet/modal
- short labels, no subtitles

Lists:

- locations, rules, account, and settings are rows with dividers
- one icon, one label, optional value/toggle/chevron
- no paragraph text inside normal rows

Cards:

- not a layout primitive for the shell
- allowed only for one subscription/account summary or a modal body
- never card inside card

Advanced warning:

- appears before advanced settings
- states that these settings can break stability/security
- requires explicit user confirmation
- xray fallback, custom keys, debug, logs, and experimental privacy options live
  only behind this gate

## Visual System

The next pass should move away from the beige/mint `Quiet Emerald` feel.

Preferred direction:

- neutral system canvas, dark and light both possible
- dark: `#0E0F12` or Apple-like `#1C1C1E`
- light: `#FFFFFF` or `#FAFAFA`
- surface: subtle neutral contrast, not tinted page backgrounds
- accent: deep emerald aligned with the POKROV mark, used sparingly for primary
  actions and active states
- semantic colors only for actual state: green connected, amber warning, red
  error/disconnect risk

Typography:

- system font stack: `-apple-system`, `Segoe UI`, `Roboto`, `Inter`, sans-serif
- no decorative or tech font for normal UI
- at most three sizes per screen
- no viewport-scaled font sizes
- Russian labels must be tested for wrapping

Shape and depth:

- structural desktop surfaces may be square or lightly rounded
- panels/inputs: `8-12px`
- main button: pill or circle
- no large blob-like card radii as the default
- internal content mostly uses dividers and spacing, not shadows
- shadows only for modals, sheets, and popovers

Motion:

- `150-220ms` for state changes
- `250-280ms` for sheets/modals
- transform and opacity only
- no bounce, parallax, decorative particles, or long breathing effects
- connecting state can show a restrained ring fill/sweep
- idle/connected micro-motion must be finite or reduced-motion guarded; no
  permanent ticker is allowed on the Home screen

## Brand Mark And Connect Disc

Brand assets:

- Use the official raster master `C:/Users/kiwun/Documents/ai/VPN/external/logogo.png`
  as the current source for the client mark.
- The runtime asset must be a cropped transparent PNG, not the original white
  canvas and not an SVG placeholder.
- Current client package assets live under `packages/app_shell/assets/brand/`.
- Generated/imagegen variants may be explored, but they do not replace the
  official mark unless a separate owner-approved brand decision says so.

Header/sidebar:

- Use the raster mark with the `POKROV` word as a tight lockup.
- The mark should be visible on Home and desktop sidebar; the app must not read
  as text-only branding.

Primary connect control:

- The circular connect surface is the tap target.
- Do not place a separate filled `Подключить` button below the disc.
- The center of the disc uses the raster POKROV mark.
- Do not use SVG or stock Material status icons as the primary center mark.
- State is expressed by color, opacity, press scale, and a `CustomPainter` rim
  sweep/arc.
- Label below the disc stays one short action string such as `Подключить`,
  `Отключить`, `Готовим`, or `Пока недоступно`.
- Use `RepaintBoundary` around the control and keep animations finite enough for
  tests, battery, and low-end Android devices.

The rules in this subsection were superseded by the `2026-08-11` owner override
at the top of this document.

## Motion Richness Layer

The motion addendum from `2026-06-03` keeps the Home structure minimal and adds
richness through state rituals, not decorative motion.

P0 motion rules:

- All durations and curves must go through a shared motion policy/tokens layer.
- Respect `MediaQuery.disableAnimations` and platform accessibility settings.
- Home boot reveal is finite: brand, status, connect disc, chips, and summary
  appear with a short transform/opacity sequence.
- Status labels crossfade/slide; long summary copy must not keep old text in the
  widget tree longer than needed.
- Connect disc motion is finite: press scale, ring sweep, connected/error
  settle. No permanent spinner or idle ticker.
- Locations, Rules, Account, bonus, and cabinet loading use geometry-matched
  skeleton placeholders before real content. Skeletons must match final row/card
  dimensions and avoid layout shift.
- Recovery states use calm inline banners and color/ring changes. Do not shake
  the main Home surface or show panic-red states for ordinary retryable errors.
- Desktop hover/cursor feedback is allowed on Windows. Android keeps touch-first
  press feedback and can later add haptics.

P1 motion candidates:

- Android haptics on connect/disconnect/success.
- Pull-to-refresh for Locations.
- Bonus/redeem count-up and checkmark draw.
- Real latency/traffic micro-indicators only when backed by live data.
- Desktop-only hover polish on chips, rows, and location/rule selectors.

Motion bans:

- no permanent tickers on Home
- no infinite spinners or decorative breathing on idle Home
- no particle/confetti/neon/glow effects
- no layout-property animation in hot paths
- no shimmer everywhere; if shimmer is used, it must be finite and test-safe

## Support And Text Density Addendum

The support/text-density consilium on `2026-06-03` keeps support honest and
reduces the remaining document-like UI.

Support rules:

- The target support surface is an embedded POKROV chat, not a Telegram link
  hub.
- The chat needs a real message list, composer, safe diagnostics attachment,
  AI-first helper state, offline/error states, and operator escalation state.
- Until app-facing chat/ticket APIs exist, a local mock may show canned AI
  helper replies and redacted diagnostics preview, but it must not fake live
  operator responses, ticket history, cross-device sync, or SLA timers.
- Telegram remains fallback/continuation, not the primary support feel.
- The temporary support hub is a P0 bridge only.
- Do not show raw URLs on the primary surface.

Text-density rules:

- Main screens show state, value, and action. They do not explain the product
  like documentation.
- `Account` should read like an iOS Settings page: rows, values, chevrons, and
  explicit actions.
- `Rules` should keep mode selection and compact rule categories on the primary
  surface. Mode explanations move behind `i` / bottom-sheet help.
- `Locations` should not explain node logic inline; keep the selected behavior
  visible and move details behind help.
- Hard first-layer copy budgets:
  - Home: one status line and chips only.
  - Account rows: title plus short trailing value.
  - Rules mode cards: name plus one short subtitle.
  - Support hub rows: label plus one short subtitle.
  - Bottom sheets: short scannable copy only.

## WARP / Enhanced Privacy Rule

If not implemented and live-tested:

- do not expose an enabled toggle
- do not imply that the feature works
- a Home tile is allowed only as an honest disabled/upcoming signal, such as
  `Расширенная приватность` with `Скоро` / `Готовится`
- keep `WARP` as a secondary technical label, not the main product promise

When implemented:

- place it behind `Advanced` or a clearly marked advanced route mode
- use functional product wording such as `Расширенная защита` or
  `Дополнительная приватность`
- explain the tradeoff in one line:
  `Может снизить скорость и повлиять на совместимость сервисов.`
- show a small Home chip only when the feature is actually enabled

## What To Delete From The MVP

- Windows bottom navigation
- custom black POKROV top bar
- beige/mint full-screen tint
- giant rounded setup cards
- nested cards
- news feed on Home
- restore-account prompt on Home
- Telegram/cabinet/email CTAs on Home
- repeated connect buttons
- enabled or active-looking WARP/enhanced placeholder on Home before runtime
  proof exists
- long explanatory paragraphs in Rules/Profile
- support buttons that directly throw the user into a browser without a native
  POKROV support hub
- category cards for banks/Gosuslugi/marketplaces on first-level UI

## Implementation Checklist

1. Add platform-aware shell: desktop sidebar, mobile tab shell.
2. Rebuild Home around status, one primary connect action, location chip, and
   route-mode chip.
3. Remove Windows bottom navigation and black brand bar.
4. Replace beige/mint theme with neutral system palette plus one sparse accent.
5. Replace card-feed layout with flat rows and restrained panels.
6. Add cropped transparent raster brand assets from the official mark.
7. Replace the separate Home button stack with a single brand-marked connect
   disc.
8. Add shared motion policy/tokens and finite Home boot reveal.
9. Add skeleton placeholders for Locations, Account, and future loading states.
10. Add calm recovery banners for preparation/connect errors.
11. Move restore code, Telegram, cabinet, email, bonuses, and devices to Account.
12. Move WARP/enhanced and xray fallback behind Advanced.
13. Add explicit Advanced warning gate with user responsibility confirmation.
14. Redesign Locations as rows with search only when useful.
15. Redesign Rules as presets plus rows/toggles, not explanatory cards.
16. Add responsive Windows sidebar collapse and content minimum-width behavior.
17. Rework Account/Profile into grouped sections instead of a flat row list.
18. Replace temporary support hub with embedded support chat shell and safe
    diagnostics attachment.
19. Add honest WARP/enhanced privacy Home tile only as disabled/upcoming until
    runtime proof exists.
20. Enforce Home, Account, Locations, Rules, and Support copy budgets in tests
    or golden review notes.
21. Add desktop keyboard shortcuts and focus states.
22. Add responsive checks for `360`, `700`, `900`, `1024`, `1180`, and `1440px`
    widths.
23. Verify Windows resize, native title behavior, and Android safe areas.
24. Add restrained motion/premium pass after layout and IA are stable.
25. Keep beta/WARP/store/signing claims honest across UI copy.
