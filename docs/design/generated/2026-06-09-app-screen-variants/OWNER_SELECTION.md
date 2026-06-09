# Owner Selection

Date: 2026-06-10

Use these variants as the current visual direction shortlist for the next app
redesign pass.

## Selected Variants

| Surface | Selected files |
| --- | --- |
| Account / Settings | `account-settings/account-c-settings-hub.png` |
| Home | `home/home-c-compact-ios.png` |
| Locations | `locations/locations-a-light-calm.png` |
| Onboarding | `onboarding/onboarding-c-returning-user.png`, `onboarding/onboarding-a-light-setup.png` |
| Rewards | `rewards/rewards-a-light-calm.png`, `rewards/rewards-b-dark-premium.png` |
| Rules | `rules/rules-b-dark-premium.png`, `rules/rules-c-selected-apps-picker.png` |
| Support | `support-chat/support-a-light-chat.png`, `support-chat/support-c-bottom-sheet.png` |
| WARP | `warp-sheet/warp-a-light-sheet.png`, `warp-sheet/warp-b-dark-active.png` |
| Windows | `windows-shell/windows-a-light-dashboard.png`, `windows-shell/windows-b-dark-premium.png` |

## Implementation Bias

- Use the selected files for layout, hierarchy, grouping, WARP placement, and
  density.
- Do not copy generated text, fake dates, fake metrics, or readiness claims
  verbatim.
- Treat `home-c`, `account-c`, `locations-a`, and `windows-a/b` as the main
  structure references.
- Treat the paired variants as state/style references where the product needs
  both a light/default and a premium/dark or focused-flow interpretation.
