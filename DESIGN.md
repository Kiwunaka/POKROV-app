---
name: POKROV Client Design System
status: active
updated: 2026-08-13
---

# POKROV Client Design System

POKROV client UI should feel calm, premium, and operationally honest.

## Principles

- One-tap connection is the primary app affordance.
- Consumer copy avoids raw transport jargon.
- Diagnostics are available behind details, not first-layer UI.
- Android and Windows availability labels must reflect gate status.
- Motion should be quiet and respect reduced-motion settings.
- Progress, success, disconnect, and error must use distinct status language;
  transitional states stay neutral rather than warning-colored.

## Tokens

Client tokens mirror the platform `shared/design-tokens.json` (`pokrov-clear`, `2026-07-redesign-w01`) until a generated Flutter export exists. The 2026-07 wave-3 alignment landed the values in `packages/app_shell/lib/src/design_system/pokrov_palette.dart`, locked by `design_system_contract_test.dart`:

- light: white surfaces on `#F5F7F6` canvas, ink `#16181D`, emerald accent `#12805A` (pressed `#0F6B47`, tint `#E6F4ED`);
- dark: off-black greens (`#111715` canvas, `#161D1A` surface — never pure black), mint accent `#8AC4AB`, readable muted text `#83908A`, and near-black `#101713` accent-label text; the dark-green raster brand mark is tinted with the mint accent in dark mode so it does not disappear into the canvas;
- `connectedGreen` (`#34C759` / `#30D158`) is the shared iOS `status_green`: connect-disc connected state and switch on-tracks only, never text or generic accents;
- brand family: Golos Text (bundled 400–800, latin+cyrillic, OFL) with system fallbacks.

## Components

- Protection connect surface.
- Location list with beta/fallback states.
- Rules and route-mode picker.
- Profile with subscription, devices, support, and settings (theme choice persists via `PokrovFileThemeModeStore`, default system).
- Warning and blocked-state panels.

## Interaction And Motion Grammar

- Mobile tab selection emits one light selection tick; desktop pointer
  navigation stays silent.
- The compact primary connect action owns the connection ritual: one success
  confirmation at landing and a quiet release at rest. Its small state indicator
  may use the shared connect-arc language, but the action itself stays a wide,
  immediately readable CTA rather than a logo-led disc. Error haptics stay with the error
  surface instead of firing twice.
- First launch hands over to Home through the shared reduced-motion-aware
  reveal; sheets and refresh indicators use the same motion scope.
- Motion is finite or token-bound, and the connect arc is the signature progress
  language inside the primary action and pull-to-refresh rather than a generic
  spinner vocabulary.
- Disabled rows dim, ignore input, and keep a non-click cursor so unavailable
  actions never look live.
- Windows must keep the compact drawer reachable at 700 and 900 logical px.
- Android system chrome may run edge-to-edge only with theme-matched icons and
  safe-area protection.
- Location metadata keeps its honest country, quality, ping, load and freshness
  fields on narrow large-text screens by wrapping secondary rows instead of
  collapsing them into unreadable ellipses.
- The support AI entry always preserves the complete AI-first promise and grows
  with text scale instead of clipping the escalation condition.
- Support exposes one prominent AI-first entry. The AppBar keeps external
  Telegram fallback inside a labelled overflow menu instead of repeating AI
  and handoff actions as unexplained icons.
- Structured assistant replies render `Коротко` and `Что сделать` as native
  visual sections. The response omits a duplicate escalation paragraph because
  the pinned `Написать человеку` action already owns that escape path.
- Each structured section leads with its first actionable sentence. Supporting
  sentences remain available behind `Подробности`, keeping the chat compact
  without deleting information.
- Support history and send failures expose one compact retry each. A failed
  ticket send keeps the draft without leaving an optimistic duplicate bubble;
  a failed AI request keeps one visible question and retries it in place rather
  than presenting a network failure as a knowledge-base answer.
- The assistant composer and human escape action stay above the mobile keyboard.
  Its compact scope names WARP, locations, routes, and system permissions
  before ticket escalation without adding prompt-chip or action-button walls.
- Referral rewards expose one clear `Пригласить` action and one labelled copy
  fallback. Missing server links show an honest refresh state instead of a
  generic `POKROV` pseudo-code and disabled icon cluster.
- The compact Profile bonus summary never exposes the account referral code;
  the code remains an implementation detail of the server-owned invite link.
- Shared status pills and support lifecycle hints flex and wrap bounded labels
  at large text instead of overflowing or silently clipping status truth.

## Do Not

- Do not present Android as public-safe before the physical audit.
- Do not expose raw configs or local control surfaces in consumer UI.
- Do not use generated images as release evidence.
- Do not hide, cloak, or stuff `VPN` wording; visible product wording may say VPN per the `2026-06-13` owner direction and the platform `2026-06-01` rule.
