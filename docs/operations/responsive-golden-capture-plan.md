# Responsive Golden Capture Plan

Last updated: 2026-08-27

Registry class: `ACTIVE_EXECUTION`.

This is the current capture gate for the POKROV `1.2.0+34`
`PRE_CANDIDATE_LOCAL` Android/Windows line. It complements widget responsive
tests; it does not replace exact-candidate device/runtime proof. A retained
release or an older capture cannot close this gate.

## Width Matrix

Capture the app shell at these widths:

- `360`: Android narrow phone, bottom navigation, no text clipping.
- `700`: Android large phone / small tablet, bottom navigation, compact cards.
- `900`: Windows narrow desktop, hamburger drawer shell.
- `1024`: Windows compact desktop, icon rail.
- `1180`: Windows standard desktop, expanded sidebar.
- `1440`: Windows wide desktop, expanded sidebar with centered content.

## Required Screens

- Protection: idle, preparing, connected, degraded/fallback, enhanced
  protection available, enhanced protection consented.
- Locations: before profile materialization skeleton, after profile
  materialization list.
- Rules: route mode rows, rules preset rows, selected-apps editor, app picker
  sheet.
- Profile: compact account layer, rewards loading skeleton, rewards hub,
  subscription/details sheets.
- Support: loading skeleton, ready chat, diagnostics preview, diagnostics
  queued, operator reply/offline state.

## Pass Criteria

- No text overlap, no clipped button labels, no card-in-card nesting.
- Sidebar width and label opacity animate without layout jumps.
- Skeletons match the geometry of the content they replace.
- Press feedback applies only to real interactive rows/chips/buttons.
- Literal `WARP`, raw config, tokens, hostnames, subscription URLs, and private
  keys do not appear in user screenshots.
- Captures are attached to the release evidence folder or marked
  `MANUAL_OWNER_TEST` when a real device/runtime surface is unavailable.

## Current Local Status

- Widget width matrix: implemented in `pokrov_seed_app_test.dart`.
- Critical 200% text-scale paths: locally proved for first session, Home,
  Locations and Support in `pokrov_seed_app_test.dart`.
- Automated widget goldens: tracked for idle light, first route-scope dark,
  verified dark and degraded light at `390 x 844`; exact Windows and Ubuntu
  baselines are separate because host rasterization differs. The test disables
  animation, clears inherited image-cache state once before the matrix and
  compares all four files without update mode in the normal suite.
- Android/Windows real artifact captures: `MANUAL_OWNER_TEST`.

## Retained History

The superseded beta-target wording is preserved in
[2026-08-22-responsive-golden-capture-plan-snapshot.md](history/2026-08-22-responsive-golden-capture-plan-snapshot.md).
