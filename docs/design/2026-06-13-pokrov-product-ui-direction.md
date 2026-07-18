# POKROV Product UI Direction

Status: active  
Date: 2026-06-13  
Scope: design-system foundation and product UI direction for the Android and
Windows app-shell pass

This note records the owner decisions that govern the app-shell UI pass. It
supersedes older generated variant copy when there is a conflict, while
preserving the selected visual references from
`docs/design/generated/2026-06-09-app-screen-variants/OWNER_SELECTION.md`.

## Owner Decisions

1. Android and Windows are equally important product surfaces. The shared shell
   must support mobile density and Windows resize behavior from the same design
   foundation.
2. POKROV is presented as a VPN. Public app UI may use `VPN` plainly when it
   helps the user understand the action.
3. Home sells one primary action: enable POKROV VPN. WARP, access/trial status,
   and Telegram bonus support that action instead of competing with it.
4. WARP is called `WARP` in the product UI. It is explained as additional
   protection, not as a second confusing VPN.
   The default user path is client-local: the app may offer WARP from the
   bundled runtime defaults even when the backend has not returned managed WARP
   material yet. Backend endpoints remain useful for consent, lifecycle events,
   and optional managed material.
5. Telegram bonus remains a promotion mechanic. The tone is soft reward/gold,
   not casino, urgency, neon, or pressure.
6. News and admin promotions exist as backend-owned surfaces, but render only
   when explicitly visible. No empty news placeholder belongs on the normal
   Home surface.
7. Rewards remain important. Roulette and calendar stay in the product plan,
   but the visual system must make them calm loyalty features rather than
   gambling-like UI.
8. Dark mode is mandatory. Dark tokens must use off-black surfaces and never
   pure black.
9. The visual style is flat, iOS-like, quiet, and consumer-first: grouped
   sections, list rows, thin separators, restrained emerald accent, soft gold
   rewards, no glow/neon/glass, no card-in-card piles.
10. Support is a separate screen, not a fifth tab. Diagnostics opens as a
    bottom sheet from support or relevant error states.
11. Beta status belongs in diagnostics only, not in the first-layer sidebar,
    footer, profile header, or Home UI.
12. First launch starts with the new/returning choice:
    `Я новый пользователь` and `У меня уже есть доступ`.

## Design-System Foundation

The shared primitives should keep feature screens visually quiet, flat, and
predictable across Android and Windows.

Required foundation:

- light and dark palette tokens exposed through the design system
- no pure black in app tokens
- calm emerald as the primary action/accent family
- soft gold/reward tokens for Telegram and rewards
- flat shared primitives for grouped app surfaces:
  `PokrovSurface`, `PokrovGroupedSection`, `PokrovListRow`,
  `PokrovPromoCard`, `PokrovStatusPill`, `PokrovInfoBanner`,
  `PokrovTrialBanner`, `PokrovTelegramBonusCard`, and
  `PokrovWarpToggleRow`
- one shared status pill direction instead of per-screen `_StatusPill`
  duplication in future feature-screen phases
- surfaces should group content directly; do not place cards inside cards

## Implemented Surface Direction

The reusable primitives live under `packages/app_shell/lib/src/design_system/`.
The first feature pass applies them to Home, onboarding, Profile, Rewards,
WARP, Support, Locations, Rules, and the shared shell.

Expected first-layer behavior:

- Home explains `POKROV VPN`, WARP, trial/access status, and Telegram bonus
  without a pile of competing cards.
- Home keeps WARP visible as a compact control and shows a short confirmation
  after the user enables or disables it.
- Support opens as a separate screen; diagnostics is a safe bottom sheet.
- Profile is grouped like Settings: access, recovery, support, settings,
  bonuses, and diagnostics.
- Rewards keeps Telegram, referral, promo, history, roulette, and calendar as
  calm loyalty mechanics; disabled backend features do not render dead cards.
- Rules uses consumer labels and hides raw app/process identifiers by default.
- Locations starts with automatic selection and uses human quality labels.
- The shell keeps four top-level sections and lazy-builds non-Home tabs.

The first contract coverage lives in
`packages/app_shell/test/design_system_contract_test.dart` and checks the
light/dark token contract, no-pure-black rule, and the existence of the shared
flat controls. Additional widget and copy contracts live in
`packages/app_shell/test/pokrov_seed_app_test.dart` and
`packages/app_shell/test/ui_copy_contract_test.dart`.

## 2026-07 Implementation Reconciliation

The completed motion/HIG pass is retained as implementation evidence in
`docs/design/2026-07-13-agent-uiux-backlog.md`; it is not a second active
design owner. The current implementation keeps:

- one status dialect: `Подключаемся…`, `Подключено`, `Отключаем…`,
  `Не защищено`;
- directional busy copy while preserving the shared connect-disc handoff and
  reduced-motion behavior;
- one mobile navigation haptic and silent desktop pointer navigation;
- Windows compact/drawer behavior at 700 and 900 px;
- Android adaptive launcher/splash assets and edge-to-edge system chrome tied
  to the existing POKROV brand source.
