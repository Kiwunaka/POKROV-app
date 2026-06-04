# Hiddify, Karing, And Happ Client Base Review

Date: 2026-06-03
Status: recommended direction
Decision owner: owner/operator

## Purpose

Record the first local source/material review after the owner added the original
Hiddify, Karing, and Happ materials under `C:/Users/kiwun/Documents/ai`.

This document updates the `2026-06-02` Karing base reopen gate with the new
local evidence. It does not import code, change the active client lane, or claim
that a new app has been built.

## Product Constraints

- POKROV remains consumer-first and app-first.
- Public `v1` scope remains Android and Windows.
- Default runtime core remains `sing-box`.
- `xray` is an advanced compatibility fallback, not the default product path.
- First-layer UX must stay simple; raw profiles, hostnames, ports, config
  editors, and transport internals stay out of the normal user path.
- Power-user controls are still required behind progressive disclosure:
  rulesets, WARP-like chain options, diagnostics, per-app routing, DNS, logs,
  and compatibility fallback controls.

## Reviewed Inputs

Local materials:

- `C:/Users/kiwun/Documents/ai/hiddify original app`
- `C:/Users/kiwun/Documents/ai/hiddify original app/hiddify-core`
- `C:/Users/kiwun/Documents/ai/karing original app`
- `C:/Users/kiwun/Documents/ai/happ apk/Happ.apk`
- `C:/Users/kiwun/Documents/ai/happ exe/setup-Happ.x64.exe`

External reviewer note:

- Two `opencode-go` model checks were run from a temp directory with only a
  compact fact packet. They were used as critique only, not as product or source
  authority.

## Recommendation

Use Hiddify as the primary fork/base candidate.

Use Karing as a feature and interaction reference, especially for rules, DNS,
diagnostics, novice mode, per-app routing, backup/sync, and network checks.

Use Happ as a UX, packaging, and platform-behavior reference only. Its APK/EXE
can inform what a polished consumer app exposes, but the inspected binaries are
closed and Xray-centric, so they should not become the POKROV source base.

## Why Hiddify Is The Best Base

Hiddify has the closest match to the POKROV technical contract:

- Flutter Android and Windows app structure already exists.
- The runtime boundary is centered on `hiddify-core`, which is built on
  `sing-box`.
- `useXrayCoreWhenPossible` already exists and defaults to `false`, matching the
  POKROV rule that Xray is fallback-only.
- WARP and chain-style options already exist in the settings model.
- Profile parsing is mature and covers subscription URLs, local content, remote
  expansion, metadata headers, WARP enablement, fragmentation hints, and many
  common protocol links.
- Connection flow is already separated through repository/service boundaries:
  setup, config option application, start, stop, restart, status stream, and
  active-profile reconnect behavior.
- Route rules are already modeled as structured data, including rulesets,
  packages, processes, networks, ports, protocols, IP CIDRs, domains, suffixes,
  keywords, and regexes.

The most important product opportunity is the rule engine. Hiddify's raw route
rule surface is too advanced for normal POKROV users, but it gives a strong
backend model for POKROV-specific rule preset buttons.

## Hiddify Risks

- `hiddify-core/bin` is currently missing runtime artifacts in the local source
  tree. The core build path must be proven before treating the fork as runnable.
- Windows core work likely needs Go `1.25.6` plus MinGW for
  `x86_64-w64-mingw32-gcc`.
- The existing UI is still a generic proxy utility. POKROV needs a new
  first-layer shell, not a light rebrand.
- Sentry, updater paths, public links, deep links, app identifiers, release
  metadata, and inherited Hiddify naming must be stripped or replaced.
- Advanced settings must be aggressively reorganized so normal users see a
  simple connect/product flow and support sees diagnostics when needed.

## Why Karing Is Not The Base

Karing still has excellent feature ideas, but the local source tree does not pass
the base gate:

- `pubspec.yaml` depends on a sibling `../vpn-service/` package that is not
  present locally.
- The local tree has many missing internal imports and private/local files.
- It is therefore not a reliable build base without additional upstream material.

Karing remains valuable as a reference for:

- diversion/ruleset grouping
- DNS auto setup and latency tests
- per-app routing screens
- network check screens
- novice mode
- backup/sync concepts
- WARP account surfaces
- TV/desktop utility affordances

Do not mix Karing code into a Hiddify-based lane without a separate GPL and
derivative-work decision. Use the feature ideas and rebuild them against the
chosen POKROV/Hiddify architecture.

## What Happ Teaches

Static inspection of the APK/EXE shows a polished platform product shape:

- signed Windows installer metadata
- Android VPN service, proxy-only service, anti-filter service, test/download
  services, boot receiver, Quick Settings tile, widget, and TV/Leanback support
- user-facing surfaces for VPN settings, routing, per-app proxy, subscriptions,
  logs, scanners, FAQ/support/report, and language/UI/settings screens
- imported config/file handling for `.json` and `.happ`

Runtime signals are Xray-centric:

- `xray_config.json`
- `xray_config_with_tun.json`
- `libtun2socks.so`
- large Go/JNI and core native libraries

This makes Happ a strong reference for UX completeness and platform packaging,
but a poor source-base match for POKROV's sing-box-first direction.

## First Implementation Slices

1. Provenance and license packet:
   record owner-held permissions, GPL obligations, upstream notices, and what may
   be copied, forked, or only studied.

2. Hiddify runtime gate:
   obtain or build `hiddify-core` artifacts, verify the Android and Windows
   start/stop/status path, and keep Xray fallback testable but non-default.

3. POKROV shell cut:
   replace the first-layer Hiddify UI with the POKROV daily-use shell:
   Protection, Locations, Rules, Profile, simple connect state, subscription
   status, support entry, and app-first activation.

4. Provisioning cut:
   replace generic import-first behavior with POKROV managed onboarding and
   backend-owned profile delivery. Manual import remains recovery/advanced only.

5. Ruleset preset layer:
   map POKROV user-facing buttons onto Hiddify route-rule structures. Keep the
   raw editor behind advanced/support tooling.

6. WARP and compatibility cut:
   expose a simple WARP-like mode only where it makes product sense. Keep Xray
   fallback behind advanced compatibility settings and test it early.

7. Diagnostics cut:
   build a consumer-safe support diagnostics panel inspired by Karing/Happ:
   route mode, DNS state, current core, app version, profile freshness, ruleset
   version, logs export, and connectivity checks without leaking raw secrets.

## Avoid

- Do not spend time making the current Karing source tree buildable unless the
  missing `vpn-service` and private files are supplied.
- Do not merge Karing source into a Hiddify fork as a shortcut.
- Do not make Happ's Xray/TUN architecture the default POKROV architecture.
- Do not expose Hiddify's raw rules/profile/config surfaces to normal users.
- Do not begin public copy, release, or stability claims until the new fork has
  its own build and runtime evidence.

## Current Decision

Proceed with a Hiddify-based spike as the primary client-base direction.

Keep the current clean-room POKROV-app lane intact until the Hiddify spike proves:

- buildable core artifacts
- working Android and Windows runtime loop
- POKROV-managed provisioning
- acceptable rebrand/telemetry/deeplink cleanup scope
- a simple first-layer UI that can hide advanced proxy utility complexity
