# P6 Overload Correction Plan

Date: 2026-06-05
Status: P2 implemented locally
Owner: POKROV-app/main

## Goal

Apply the P6 overload consilium correction so the app feels like a premium
consumer connect client instead of a feature panel.

Primary user rule:

> The first thing a normal user understands is: tap the center disc to connect.

## Sources

- `docs/design/2026-06-05-p6-overload-ux-consilium.md`
- `docs/design/2026-06-05-p5-application-map-consilium-review.md`
- `docs/design/2026-06-03-client-premium-shell-v2-brief.md`
- `docs/architecture/app-first-onboarding-flow.md`
- platform app-first contract in
  `C:/Users/kiwun/Documents/ai/VPN/docs/architecture/app-first-and-bonus-flows.md`

## P0 Scope

### 1. Home First Layer

Keep:

- compact brand/status;
- central connect disc;
- location chip;
- route-mode chip.

Move or hide:

- platform/device chip -> Account/Device;
- enhanced-protection full tile -> quiet chip or deeper sheet;
- status summary paragraph -> details/support surfaces;
- recovery, Telegram, cabinet, email, bonuses -> Account.

Acceptance:

- Home renders no paragraph-style status summary;
- Home has no more than two first-layer value chips;
- no full-width enhanced-protection tile competes with the connect disc;
- the connect disc remains the only large primary action.

### 2. Home-First Onboarding

Replace the blocking first-launch gate with a soft Home-first state.

Keep returning-user recovery discoverable through a compact banner or sheet,
but do not hide Home and the connect disc behind a question.

Acceptance:

- first render shows the app shell and connect disc;
- returning-user restore remains accessible;
- restore has one input and one primary action;
- no clipped title at narrow Windows widths.

### 3. Responsive Baseline

Stabilize the first screen at:

- `360`;
- `493`;
- `700`;
- `900`;
- `1024`;
- `1180`;
- `1440`.

Acceptance:

- no horizontal clipping on first launch;
- Home stage remains centered;
- desktop drawer/sidebar does not push the connect stage off-screen.

## P1 Follow-Up

- Rebuild Account/Settings as grouped iOS Settings-like rows.
- Move dangerous/manual controls behind Advanced.
- Add connection-details sheet for secondary runtime details.
- Add calmer support/restore/account entrypoints.

## P2 Follow-Up

- Motion polish after layout is quiet:
  finite connect ritual, status crossfade, row/chip feedback, skeletons, and
  reduced-motion compliance.

## Implementation Order

1. Update tests to encode the new Home-first and Home-minimal rules.
2. Simplify Home composition.
3. Replace full-screen first-launch gate with a compact overlay/banner.
4. Fix responsive constraints for narrow widths.
5. Run focused Flutter tests and analyze/build smoke.

## P0 Implementation Notes

Implemented locally on 2026-06-05:

- Home now keeps only the primary connect disc, one status layer, location chip,
  and route-mode chip.
- Home no longer renders the platform chip, enhanced-protection full tile, or
  status summary paragraph.
- First launch now renders the normal shell immediately and shows a compact
  recovery/start overlay instead of a blocking full-screen question.
- Tapping the Home connect disc during first launch marks first launch complete
  and continues through the normal connect path.
- Returning-user restore is a compact panel with one input and one primary
  restore action; Telegram and cabinet are secondary links.
- Enhanced protection remains functional through Profile instead of competing
  with the Home connect action.

Verification:

- `flutter analyze` in `packages/app_shell`
- `flutter test` in `packages/app_shell`
- `flutter build windows --release` in `apps/windows_shell`

## P1 Implementation Notes

Implemented locally on 2026-06-05:

- Profile first layer now behaves like grouped settings: access, recovery,
  bonuses, support, device/app, and advanced are separate quiet rows instead
  of one dense account dashboard.
- Redeem moved from always-visible fields into a compact `Код активации`
  sheet, preserving the native app-first redeem endpoint.
- Bonus wheel, calendar, achievements, referrals, promo slots, and history now
  open from one `Бонусы и история` row. The first layer keeps only refresh and
  hub entry.
- Home status opens a connection-details sheet for secondary runtime details;
  the Home first layer still avoids paragraph-style explanation.
- Rewards history remains available in the hub through compact settings rows.

Verification:

- `flutter test test/pokrov_seed_app_test.dart` in `packages/app_shell`
- `flutter analyze` in `packages/app_shell`
- `flutter test` in `packages/app_shell`

## P2 Implementation Notes

Implemented locally on 2026-06-05:

- Home status now exposes a dedicated animated status-dot primitive alongside
  the existing 180 ms fade/slide status label.
- Home chips now use a stable label-motion box with fade/slide label changes,
  so route-mode changes feel deliberate and do not yank the first layer around.
- The Home route chip reserves width for the longer selected-apps mode while
  keeping the location chip compact.
- Design-system tests now lock status-dot motion, chip label motion, tactile row
  feedback, and reduced-motion token behavior.
- Shell tests now confirm the Protection screen actually renders the status-dot
  and chip-label motion primitives.

Verification:

- `flutter test test/design_system_contract_test.dart` in `packages/app_shell`
- `flutter analyze` in `packages/app_shell`
- `flutter test` in `packages/app_shell`
- `flutter build windows --release` in `apps/windows_shell`
