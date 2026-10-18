---
name: POKROV Client Design System
status: active
updated: 2026-10-18
---

# POKROV Client Design System

The approved 18 October screens, plain «ты» copy, Golos Text font, colors and
motion live in `packages/app_ui`. Feature-local adapters in `app_shell` supply
real view data and existing callbacks. The UI package has no runtime, network
or storage access; fake data and simulated connections belong to its example
and tests only. Android and Windows share a centered column up to 480 logical
pixels wide, including pushed screens. System/light/dark choice is persisted.

## Screens and actions

- Protection, Locations and Profile are always in the tab bar. Rules appears
  only in Advanced mode; Profile owns the persisted Simple/Advanced switch.
  Home keeps one connection action, a status sheet, the first connection scope
  sheet, the notification bell and the real next step for the channel bonus.
- Locations shows Auto and API countries, with an explicit refresh. Country
  selection retains existing admission, manual pin and bridge policies.
  Missing measurements never become fabricated ping or speed labels.
- Rules keeps its route choice in a local draft until Apply invokes the existing
  handler. App selection, Selective services and presets use their existing
  editors. DNS, custom routes, trusted Wi-Fi and Windows stack stay under
  «Для опытных», with the existing saved draft and single apply action.
  Direct DoH remains opt-in and affects resolver traffic only.
- Profile retains account linking, device management and activation, theme,
  notifications, WARP, platform settings, sharing, About and legal links.
  Devices uses the real existing service; the mock «2 из 5» counter is absent.
- Renewal shows only platform catalog plans and prices, opens the existing
  checkout URL unchanged and asks the user to confirm the term there. No
  introductory price or device quota is invented by the view.
- Support opens the existing AI conversation and exposes «Позвать человека».
  Safe assistant sections and allowlisted actions come from the existing
  response parser. Human chat retains history, retry, draft retention, polling,
  feedback and diagnostics attachment consent. A failed send keeps its draft;
  a failed AI question is retried in place.
- Bonuses uses server history, achievements, channel, referral, wheel and
  calendar state. Actions retain their existing eligibility and callbacks.
  Missing achievements, prices and offers stay absent.
- Real promo slots retain impression/click events, expiry, dismissal and media.
  Empty slots are hidden. Home uses 132-pixel slots in Simple mode and 84-pixel
  slots in Advanced mode (358 pixels wide at a 390-pixel viewport).
  Unavailable optional actions have no visible placeholder.

## Status and diagnostics

Only the existing verified connection presentation may show protection as on.
Staged, missing and failed evidence must never become a successful connection.
Consumer screens use plain status language. Diagnostics opens a plain summary;
raw checks, runtime fields, phase history and support-transfer details are under
«Технические детали». The support code is masked before `DiagnosticsViewData`
is created and in the technical preview; copying the full code remains an
explicit action. Encrypted report delivery retains the existing authority and
availability gates. No UI code creates connection proofs or support authority.

## Motion and accessibility

The connection circle uses a rotating arc while connecting and soft repeating
waves when connected. Reduced motion stops both; idle and error states remain
still. Existing connection coordination owns outcome haptics. App inactivity
mutes animation tickers, and inactive tabs keep `TickerMode` and their state.
Host scrolling, switches and route transitions retain platform behavior;
Windows also retains keyboard navigation.

Primary actions, state truth, onboarding, Locations and Support must remain
reachable at 200% text scale. Text may wrap and screens may scroll; labels must
not be clipped into ambiguity. Nullable callbacks hide unavailable actions.
The connect CTA and status action have separate semantics. Widget checks and
emulator screenshots establish layout and callback behavior only; TalkBack,
Narrator, physical devices and real VPN connectivity require their own checks.

## Boundaries

The redesign must not change tunnel/WARP lifecycle, route policy, auth,
activation, payments or update ownership. Release-critical update behavior
stays in `src/features/update/client_update.dart`. Raw configs, profiles and
local control surfaces never appear in consumer screens. UI examples and
screenshots are not release or connection evidence.
