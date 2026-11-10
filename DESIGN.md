---
name: POKROV Client Design System
status: active
---

# POKROV Client Design System

The shared screens, plain «ты» copy, colors and motion live in
`packages/app_ui`. Fonts are shared with the cabinet and site: Onest for text
and Unbounded for titles and the wordmark; titles grow with system text up to
140% so single words stay whole. Feature-local adapters in `app_shell` supply
real view data and existing callbacks. The UI package has no runtime, network
or storage access; fake data and simulated connections belong to its example
and tests only. Android and Windows share a centered column up to 480 logical
pixels wide, including pushed screens. System/light/dark choice is persisted.

## Screens and actions

- The tab bar always shows four tabs named by task: «Защита», «Доступ»,
  «Помощь», «Настройки». There is no Simple/Advanced switch. Home keeps one
  connection action, the status line and sheet, the notification bell, the
  channel-bonus next step and the widgets the person chose (default: country,
  route, bypass, WARP; the choice and order are saved in
  `pokrov-home-tiles.txt`). WARP switches in place; other widgets open their
  existing screen or sheet. Country and route open as full pages over the tab
  they came from, with a back button and system back. The first-connect scope
  sheet is gone: the saved route is confirmed and changed in Settings.
- «Доступ» holds the access card and renewal, the next useful step, devices,
  «Код для входа», «Код активации», Telegram and mail, bonuses, the Telegram
  proxy and sharing. «Помощь» starts with the connection check, then topics
  for the AI helper, a person, the report, history and feedback. «Настройки»
  has one search over every entry; expert entries open the route page with
  «Для опытных» expanded.
- Locations shows Auto and API countries, with an explicit refresh. Country
  selection retains existing admission, manual pin and bridge policies.
  Missing measurements never become fabricated ping or speed labels.
- Rules keeps its route choice in a local draft until Apply invokes the existing
  handler. App selection, Selective services and presets use their existing
  editors. DNS, custom routes, trusted Wi-Fi and Windows stack stay under
  «Для опытных», with the existing saved draft and single apply action.
  Direct DoH remains opt-in and affects resolver traffic only.
- Account linking, device management and activation live on «Доступ»; theme
  and holiday decoration, notifications, WARP, platform settings, home widgets,
  About and legal links live on «Настройки». Devices uses the real existing
  service; the mock «2 из 5» counter is absent.
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
  Empty slots are hidden. Home uses 84-pixel slots below the widgets (358
  pixels wide at a 390-pixel viewport); «Доступ» uses the full card.
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

The connect CTA and status semantics expose their existing tap callbacks;
an unavailable connect action stays disabled for assistive activation too.
At 200% text the home widgets stack in one column, the connect label shrinks
instead of breaking, the wordmark yields to the mark and tab labels shrink
instead of clipping. Every row, widget and switch is one keyboard-focusable
control with a spoken label and state. Segmented choices keep keyboard focus
and activate the same callback with Tab/Enter.

## Holiday decoration

The app shell picks a holiday from the device's local date, with no network:
Halloween 25 Oct–1 Nov, New Year 15 Dec–5 Jan (fireworks after a confirmed
connection on the night of 31 Dec 18:00–1 Jan 06:00), Christmas 6–8 Jan,
13–14 Feb, 22–23 Feb, 7–8 Mar, 1 Apr, 12 Apr, Orthodox Easter and the next
day, and 8–9 May. Overlaps resolve as 9 May, Easter, 12 April, then the rest.
`PokrovSeasonTheme` carries the season into `app_ui`, which tints only the
accent tokens (never warning or status tokens) and draws a `CustomPaint`
backdrop behind Home plus decoration around the connect circle. The status
text, the verified-only «Защищено» and the error look never change; an error
hides the decoration. Motion runs at about 30 frames a second, stops under
reduced motion, while the app is inactive and a minute after the last touch.
«Праздничное оформление» in the theme sheet is on by default and persisted.
`--dart-define=POKROV_SEASON=<id>` (or `newYearNight`) previews a holiday;
the UI example has a holiday picker in the theme row.

## Boundaries

The redesign must not change tunnel/WARP lifecycle, route policy, auth,
activation, payments or update ownership. Release-critical update behavior
stays in `src/features/update/client_update.dart`. Raw configs, profiles and
local control surfaces never appear in consumer screens. UI examples and
screenshots are not release or connection evidence.
