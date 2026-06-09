# POKROV App Screen Variants

Generated: 2026-06-09

Purpose: visual exploration for the next POKROV client redesign pass after the
current Windows/mobile UI felt overloaded, unclear, and not premium enough.

These are imagegen concept renders, not implementation screenshots. Use them
for layout, density, hierarchy, mood, WARP placement, account grouping, and
desktop responsiveness. Do not copy generated text verbatim when it is garbled,
too specific, date-like, or claim-heavy.

## Review First

- `_all-screens-contact-sheet.png` - all generated screens in one long overview.

## Directions

- `*-a-*`: light Apple-calm direction, white/silver canvas, emerald accent.
- `*-b-*`: dark premium direction, graphite surfaces, emerald active state.
- `*-c-*`: compact/native direction, usually denser and more implementation-led.

## Screens

- `onboarding/` - first launch, country/mode choice, returning-user restore.
- `home/` - main connect screen with trial, WARP, Telegram bonus, nav.
- `locations/` - auto/manual location selection.
- `rules/` - route mode and selected-app picker.
- `account-settings/` - profile, access, account linking, settings grouping.
- `support-chat/` - embedded AI/support chat and log attachment.
- `rewards/` - Telegram bonus, wheel, calendar, referrals, history.
- `warp-sheet/` - WARP consent/detail states.
- `windows-shell/` - desktop layout, sidebar/collapse, right panels.

## Strong Candidates

- Home: `home-a-light-calm.png`, `home-b-dark-premium.png`
- Locations: `locations-b-dark-premium.png`, `locations-c-compact-picker.png`
- Rules: `rules-b-dark-premium.png`, `rules-c-selected-apps-picker.png`
- Profile: `account-c-settings-hub.png`
- Support: `support-a-light-chat.png`, `support-c-bottom-sheet.png`
- Rewards: `rewards-b-dark-premium.png`
- WARP: `warp-a-light-sheet.png`, `warp-b-dark-active.png`
- Windows: `windows-b-dark-premium.png`, `windows-c-compact-sidepanel.png`

## Product Notes

- The Home screen should keep one obvious connect action.
- WARP belongs on Home as a real, consent-gated feature; avoid "soon" styling.
- Profile should stop being a dump of every action. Split access, account,
  bonuses, support, and settings into predictable groups.
- Rules should ask a human question: what goes through POKROV?
- Locations should allow manual choice when access allows it; auto-select must
  not feel like the only option.
- Support should be in-app chat with AI help and optional diagnostics, not just
  a browser/Telegram handoff.
- Windows needs a desktop-native layout, not a stretched mobile feed.

## Claims Guardrail

Do not copy generated claims about anonymity, speed, dates, version, exact
premium status, or technical readiness. Current product truth still comes from
the app docs and backend contracts.
