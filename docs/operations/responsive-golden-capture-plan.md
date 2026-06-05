# Responsive Golden Capture Plan

Last updated: 2026-06-05

This is the capture plan for the POKROV `1.0.0-beta` client shell before a
downloadable Android/Windows refresh. It complements widget responsive tests;
it does not replace manual device/runtime proof.

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
- Automated screenshot/golden export: planned for the release-evidence slice.
- Android/Windows real artifact captures: `MANUAL_OWNER_TEST`.
