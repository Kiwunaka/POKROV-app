---
name: POKROV Client Design System
status: active
updated: 2026-07-18
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
- dark: off-black greens (`#111715` canvas, `#161D1A` surface — never pure black), mint accent `#8AC4AB` with near-black `#101713` label text;
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
- The connect disc owns the connection ritual: one success confirmation at
  landing and a quiet release at rest. Error haptics stay with the error
  surface instead of firing twice.
- First launch hands over to Home through the shared reduced-motion-aware
  reveal; sheets and refresh indicators use the same motion scope.
- Motion is finite or token-bound, and the connect arc is the signature
  progress language for connection and pull-to-refresh rather than a generic
  spinner vocabulary.
- Disabled rows dim, ignore input, and keep a non-click cursor so unavailable
  actions never look live.
- Windows must keep the compact drawer reachable at 700 and 900 logical px.
- Android system chrome may run edge-to-edge only with theme-matched icons and
  safe-area protection.

## Do Not

- Do not present Android as public-safe before the physical audit.
- Do not expose raw configs or local control surfaces in consumer UI.
- Do not use generated images as release evidence.
- Do not hide, cloak, or stuff `VPN` wording; visible product wording may say VPN per the `2026-06-13` owner direction and the platform `2026-06-01` rule.
