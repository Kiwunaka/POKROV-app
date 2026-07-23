# POKROV Client Quiet Emerald Style Brief

Date: 2026-06-03
Status: visual direction brief
Decision owner: owner/operator

## Purpose

Record the OpenCode-go design consilium for the future POKROV Android and
Windows client visual system.

The owner requested an app that feels strong, beautiful, responsive, pleasant,
fast, smooth, and Apple-grade. This brief defines that as interaction quality,
hierarchy, material discipline, motion taste, and platform-native polish, not as
a literal iOS clone.

## Consilium Inputs

Models:

- `opencode-go/deepseek-v4-pro`
- `opencode-go/qwen3.7-max`
- `opencode-go/minimax-m3`
- `opencode-go/glm-5.1`
- `opencode-go/kimi-k2.6`
- `opencode-go/mimo-v2.5-pro`

Source packet:

- current POKROV product/client canon
- `DESIGN.md`
- `shared/design-tokens.json`
- `docs/decisions/2026-06-03-client-ux-account-rewards-master-brief.md`
- screenshot summary from `C:/Users/kiwun/Documents/ai/VPN/.tmp/design 0306`

Most OpenCode-go models did not support reading the attached JPG screenshots
directly. The packet included a textual screenshot summary, and the local agent
also reviewed the images in the conversation context before synthesizing this
brief.

## Final Direction

Name: `Quiet Emerald` / `Спокойный изумруд`.

POKROV should feel like a quiet system app with one strong emerald accent:
premium, calm, tactile, and fast. It must not feel like a dark gamer VPN, a
proxy utility, or an iOS skin pasted onto Android/Windows.

Use Apple-grade principles:

- one primary task per screen
- clear visual hierarchy
- restrained typography
- precise touch feedback
- reliable loading, error, empty, and disabled states
- smooth transitions that never make the app feel slower
- platform-native navigation on Android and Windows

Do not copy Apple-specific components blindly:

- no Cupertino-only dialogs on Windows
- no iOS-only navigation stack on Android
- no bottom tabs on desktop
- no heavy blur that hurts Android or low-end Windows performance

## Palette And Material

Use the existing token family from `quiet-core-luminous-edge`.

Primary colors:

- light canvas: `#f7f3eb`
- dark canvas: `#111715` / `#151c19`
- primary emerald: `#20674f`
- emerald strong: `#174f3d`
- mint: `#dcefe5`
- sage: `#9cab90`
- soft gold: `#d8c8a8`

Rules:

- one accent family only: emerald/mint/sage.
- soft gold is for premium/reward hints only, not navigation.
- no pure black `#000000`.
- no purple/blue AI gradients.
- no neon, outer glow, or gamer-style lighting.
- content surfaces should be readable and mostly solid.
- translucent/glass surfaces are allowed only for overlays, bottom sheets, and
  navigation chrome, with a low blur ceiling and a solid fallback.

Cards and surfaces:

- one level of cards only; no card inside card.
- use dividers and spacing for simple groups.
- use raised surfaces only when they express hierarchy or overlay.
- prefer subtle borders and inner edge highlights over heavy shadows.

## Typography

Keep current canon unless a separate brand decision changes it:

- Manrope for body and display.
- JetBrains Mono only for numeric/debug details.
- letter spacing `0`.

Guidelines:

- avoid oversized shouting headers.
- use 2-3 hierarchy levels per screen.
- Russian copy must be tested for wrapping; it is longer than English.
- technical names such as `sing-box`, `Xray`, hostnames, ports, JSON, CIDR, and
  protocol names must stay out of normal UI.

## Theme Strategy

Dark and light themes must both be first-class.

Default behavior:

- follow the OS theme by default.
- provide manual theme choice in settings.
- prototype both themes from the beginning.
- never hardcode the app as dark-only, even if early references are dark.

Dark theme may be the strongest visual reference for the client, but the root
POKROV design canon still requires the light canvas and white-surface language
to remain polished and available.

Theme switching:

- avoid dramatic theme-change animation.
- crossfade or instant color swap is enough.
- reduced-motion users get fade-only or no animation.

## Mobile Layout

Top-level tabs:

1. `Protection`
2. `Locations`
3. `Rules`
4. `Profile`

Rules:

- exactly four bottom tabs.
- no center `VPN` tab.
- bottom tab bar respects safe area and Android gesture area.
- active tab uses emerald icon/text and a quiet mint cue.
- inactive tabs use soft text.

Main screen structure:

1. top identity/status area
2. connection control
3. one concise status line
4. route/location/access chips
5. service notification when needed
6. four quick actions

Quick actions:

- `Исключения`
- `Локация`
- `Усиленный режим`
- `Помощь`

The connect control should be dominant but not cartoonish. For mobile, target
roughly `112-144dp` depending on viewport size. It should feel like a system
control, not a mascot, flame, or glowing game button.

## Windows Layout

Windows must not be a stretched phone screen.

Use:

- left sidebar or navigation rail.
- same four main sections.
- content column around `720px` max for focused screens.
- master-detail layouts for locations/rules when width allows.
- native title bar behavior unless there is a strong reason to customize.

Avoid:

- mobile bottom tabs on Windows.
- giant empty mobile center layout on large desktop windows.
- a dense admin/cabinet layout; this is still a consumer client.

## Components

Buttons:

- primary: emerald fill, white text, `44dp+` touch target.
- secondary: surface or outline.
- destructive: quiet danger text/surface, not loud red fill by default.
- pressed state: slight scale down or opacity change.
- loading state preserves button size.

Chips and segmented controls:

- use chips for route mode, location, access state, and small status labels.
- segmented controls for mode choice and paywall tabs.
- active state should move smoothly without layout shift.

Lists:

- locations and settings should be rows with dividers, not every row boxed.
- use section headers for grouping.
- server quality should be human labels or a subtle line, not aggressive signal
  bars.
- preserve list scroll position across tabs.

Modals:

- Android/mobile: bottom sheets with drag handle.
- Windows: centered dialogs or side panels.
- advanced settings require warning, checkbox, and second confirmation.

Rewards:

- rewards belong under Profile/Bonuses, not the main protection screen.
- Telegram bonus can be a calm prompt.
- roulette/calendar must not become a loud game surface.
- roulette/calendar UI stays feature-flagged until public app endpoints exist.

## Motion

Motion is a product feature only when it makes the app feel faster and clearer.

Use:

- 160ms for tap feedback and small state changes.
- 220ms for tab/screen fade or short slide.
- 280-320ms for bottom sheets and larger state transitions.
- easing: `cubic-bezier(0.22, 1, 0.36, 1)` or Flutter equivalent.
- transform and opacity only for frequent animations.
- optimistic connection state immediately after tap.
- subtle progress ring/sweep for connecting.
- skeletons that match final layout dimensions.
- haptic feedback on primary actions where platform-appropriate.

Avoid:

- spinner soup.
- full-screen blocking spinners for connect/disconnect.
- animating width, height, top, left, padding, or margin in hot paths.
- perpetual background motion.
- bounce-heavy iOS animation on Windows.
- re-mounting tab screens on every tab switch.

Reduced motion:

- no pulse, sweep, scale, or slide.
- use fade-only or instant state changes.

## Flutter / Pokrov Implementation Notes

UI architecture:

- replace first-layer Pokrov UI with POKROV widgets and themes.
- keep core runtime boundaries intact until the runtime gate is proven.
- model tokens through a typed Flutter theme or `ThemeExtension`.
- no scattered hex values in widgets.
- keep Android and Windows shell adapters separate from shared content widgets.

Performance:

- `RepaintBoundary` around the connect control and animated status surfaces.
- `IndexedStack` or equivalent to preserve top-level tab state.
- `AutomaticKeepAlive` where screen state must persist.
- `ListView.builder` for locations/rules/settings lists.
- avoid `BackdropFilter` in scrolling content.
- blur/glass has solid fallback.

State design:

- every screen needs loading, empty, error, disabled, and success states.
- connection flow needs disconnected, connecting, connected, enhanced, error,
  expired, and provisioning/restoring states.
- layout dimensions must stay stable across these states.

Accessibility:

- `44dp` minimum touch target.
- semantic labels for connect, route mode, location, enhanced mode, and toggles.
- WCAG AA contrast.
- dynamic text should not break layout.

## Copy Direction

Use human, calm labels:

- `Защита`
- `Локации`
- `Правила`
- `Профиль`
- `Исключения`
- `Локация`
- `Усиленный режим`
- `Помощь`
- `Ввести код`
- `Восстановить доступ`

Avoid:

- `VPN` as a central UI label.
- `Активировать ключ` as first-layer wording when `Ввести код` or
  `Восстановить доступ` is clearer.
- `YouTube без рекламы` unless a separate evidence-backed product decision
  authorizes that claim.
- scary red trial banners.

## Hard Rejections

Reject these during design and implementation review:

1. gamer neon, flame mascots, outer glows, purple/blue gradients.
2. literal iOS clone controls on Android/Windows.
3. central `VPN` tab.
4. five-tab mobile navigation.
5. mobile bottom tabs on Windows.
6. nested cards.
7. raw technical names in normal UI.
8. server lists that look like generic VPN clones.
9. roulette/bonus gamification on the main screen.
10. spinner-only loading screens.
11. layout jumps between states.
12. animation of layout properties in hot paths.
13. pure black backgrounds.
14. unsupported ad-free, unlimited, anonymity, store, or release-maturity
    claims.

## Open Questions For Next Design Pass

- final connect-control form: circular system control, large pill, or hybrid
  ring-button.
- exact mobile size scale for small phones versus large phones.
- whether the first prototype defaults to OS theme or dark theme while still
  supporting light.
- final server-quality display: text label, thin quality line, or compact ping.
- how much of Rewards appears in Profile before the bonus API is implemented.

## One-Line Summary

Build POKROV as `Quiet Emerald`: a calm, premium, system-feeling Android/Windows
client with one emerald accent, fast tactile motion, honest states, and no
generic dark VPN noise.
