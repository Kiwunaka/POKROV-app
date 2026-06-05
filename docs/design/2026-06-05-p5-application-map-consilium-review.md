# P5 Application Map Consilium Review

Date: 2026-06-05
Status: external visual-review synthesis / feeds approved P5 spec
Owner: POKROV-app/main

## Purpose

This note records the second-pass review of the generated P5 application map:

- [P5 WARP Application Map](2026-06-05-p5-warp-application-map.md)
- [Application map PNG](assets/2026-06-05-p5-warp-application-map.png)

The review used Product Design / Image-to-Code style extraction: treat the
image as a selected visual target, extract implementation rules, reject
generated copy artifacts, and identify missing detail renders before coding.

## Model Capability Check

OpenCode PNG input support was not consistent across the consilium lane:

| Model | PNG input result | Review source |
| --- | --- | --- |
| `opencode-go/minimax-m3` | Visual-capable | Attached PNG plus visual packet |
| `opencode-go/kimi-k2.6` | Visual-capable | Attached PNG plus visual packet |
| `opencode-go/qwen3.7-max` | Not reliable for PNG | Visual packet |
| `opencode-go/mimo-v2.5-pro` | Text-only | Visual packet |
| `opencode-go/glm-5.1` | Text-only | Visual packet |
| `opencode-go/deepseek-v4-pro` | Text-only | Visual packet |

Raw outputs are retained under `.tmp/p5-map-review-*.txt` as local scratch, not
canonical documentation.

## Verdict

Adopt the generated map as the P5 visual direction with corrections.

The map is a strong step up from the first MVP because it has one connect
focus, neutral premium surfaces, emerald active states, row-based settings,
desktop-specific navigation, and a coherent motion vocabulary.

It must not be treated as product copy or final implementation detail. Several
visible labels and simulated values are Image Gen artifacts.

## Keep

- Central tactile connect disc as the Home focus.
- Idle, connecting, connected, and error-capable disc state system.
- Neutral light canvas with emerald used only for active/selected states.
- iOS Settings-like row grouping for Account, Rules, Locations, and Support.
- Bottom-sheet pattern for gated features.
- Windows sidebar plus centered main stage instead of stretched mobile bottom
  navigation.
- Motion language: finite ring sweep, press scale, status crossfade,
  geometry-matched skeletons, row feedback, and calm muted states.
- Token direction: emerald trio, off-black text, muted gray, light neutral
  surfaces, radii `8/12/16/20/24`, elevation `0-3`, SF Pro-like type scale.

## Refine

- Public `WARP` labels become `Расширенная защита` or
  `Расширенная приватность`; literal `WARP` remains advanced/support/internal.
- The generated `POKROV VPN Client` heading is not product copy. Normal product
  UI should say `POKROV`.
- Rewards wheel/calendar/balance must render muted or hidden until backend flags
  and ledgers are live.
- Location pings, signal bars, server load, device counts, renewal dates, and
  timers must be live data or skeletons, never hardcoded decorative values.
- Windows right panel should default to consumer-readable information only.
  Protocol/load/uptime/raw metrics move behind details or Advanced.
- Support chat must not imply fake operator presence, typing, read receipts, or
  SLA.
- `NL-free` is useful internally, but normal UI needs a clearer label or an
  explanatory first-run hint.
- Third-party app icons in app-picker renders are references only; production
  must use OS-provided icons or safe generic/source-owned icons.

## Reject

- Copying generated labels such as `POKROV VPN Client`, `Beta draft`, or
  `Secure by design` into public UI without canon review.
- Showing WARP as a normal active Home/sidebar feature before proof.
- Active-looking rewards when the feature is off.
- Fake ping/load/country/device values.
- Fake support operator presence.
- Any visual or copy implication of stable `1.0.0`, store release, trusted
  signing, RU-origin readiness, anonymity, faster internet, ad-free behavior,
  or unrestricted access.

## Component Rules To Promote

Connect disc:

- Mobile diameter target: `160dp`; Windows target: `240-280dp`.
- Idle: white inner disc, soft emerald/muted ring haze, lightning icon.
- Connecting: finite ring sweep, one loop per connection attempt.
- Connected: solid emerald ring, check icon, timer when live.
- Error: muted/red-safe settle without alarmist glow.
- Press: `scale 0.95-0.98`, `100-150ms`, transform only.
- Settle: subtle once-only pulse, no infinite glow in steady state.

Rows:

- Standard height `56dp`; two-line height `72dp`.
- Leading icon `24dp`; title `16`, subtitle/caption `13`.
- Pressed state via subtle surface tint, no layout movement.
- Dividers are hairline and may be indented after the leading icon.

Chips:

- Height `32dp`, radius `16dp`, horizontal padding `12dp`.
- Max two chips on Home. Overflow goes to detail sheet rather than wrapping.
- Labels must be user-readable.

Bottom sheets:

- Top radius `20-24dp`.
- Drag handle around `36-40dp x 4dp`.
- Default detent around `60%`, expanded around `85-92%`.
- Scrim around `32-40%`.
- Tablet/desktop sheets use max width instead of full viewport.

Windows sidebar:

- Expanded width around `240-260dp`; collapsed icon rail around `64dp`.
- Active state uses emerald indicator or pill, not a loud glow.
- WARP/extended protection stays muted or moved under Settings until proof.
- Status at the bottom may show connected state, but not a fake cellular-style
  signal indicator.

Muted/gated states:

- Use desaturated icon, muted text, short reason, and no active CTA.
- A disabled future feature should never look like a failed live feature.

## Dedicated Renders Needed Before Code

The board is too compressed to code from directly. Generate or capture
screen-specific references before implementation:

- Home idle, connecting, connected, reconnecting, error.
- Connect disc component states at 1:1 scale.
- Extended protection gate sheet and ready-to-consent sheet using product
  wording, not literal WARP as the primary label.
- Rules app picker with search, long list, empty state, and selected-app tab.
- Locations with search, skeleton/loading, offline/error, and long list.
- Account subscription/details/session-limit states.
- Rewards muted/locked state and live-flag state.
- Support empty state, message sent state, attachment picker, send error.
- Windows shell at `1280x720`, `1440x900`, and `1920x1080`, with sidebar
  collapsed/expanded and right panel collapsed/expanded.
- Motion sheet with timings, easing, and frame states.
- Dark mode only if the release scope explicitly includes it.

## Spec Changes Applied

The approved P5 spec should carry forward:

- WARP naming rule.
- Gated-feature pattern.
- No-fake-data rule.
- Windows progressive disclosure.
- Component architecture for disc, rows, chips, bottom sheets, sidebar,
  skeletons, and muted states.
- Dedicated render backlog.
- Visual regression and copy guard tests.
