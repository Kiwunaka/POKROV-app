# Premium Client AI Assistant Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** turn the current `1.0.0-beta` Android/Windows client from a completed beta contour into a high-class, lightweight, platform-native POKROV client with a maintainable motion/design foundation, honest WARP lifecycle, and an in-app AI support/settings assistant.

**Architecture:** keep the existing Flutter shared shell and hiddify-core runtime lane, but stop growing the monolithic `app_shell.dart`. Extract design, motion, responsive shell, WARP, support, and assistant contracts into small internal modules with focused tests before changing visible behavior.

**Tech Stack:** Flutter/Dart shared shell, Android/Windows host runners, existing `pokrov_runtime_engine`, app-first platform APIs, ticket/support API, existing WARP backend contracts, GitHub prerelease beta artifacts.

---

## Source Inputs

- `docs/implementation/2026-06-04-decisions-implementation-map.md`
- `docs/specs/2026-06-05-p5-warp-approved-design.md`
- `docs/design/2026-06-03-client-premium-shell-v2-brief.md`
- `docs/design/2026-06-03-client-chat-responsive-warp-motion-brief.md`
- root `AGENTS.md` and platform release gate docs
- OpenCode-go consilium synthesis from 2026-06-05

## Non-Negotiables

- Do not claim stable `1.0.0`, store readiness, trusted Windows signing, RU-origin readiness, anonymity, ad-free behavior, or production WARP until evidence exists.
- Do not expose raw configs, keys, subscription URLs, hostnames, protocol internals, or WARP material in normal UI, diagnostics, logs, screenshots, or support payloads.
- Do not make AI a fake operator. AI is a helper/copilot; operator escalation stays ticket-backed.
- Do not add more first-layer text. Home stays one primary connect focus plus compact status chips.
- Hot-path motion uses transform/opacity, finite durations, and reduced-motion fallback.
- Xray remains advanced fallback only.

## Phase 0: Architecture And Motion Foundation

- [x] Add internal design-system modules under `packages/app_shell/lib/src/design_system/`.
- [x] Move public palette and motion contracts out of private top-level declarations while preserving current UI constants.
- [x] Add tests for motion token values, reduced-motion duration collapse, and palette parity.
- [x] Keep existing private `_SeedPalette`, `_MotionTokens`, and `_MotionScope` as compatibility adapters for the first slice.
- [x] Run focused app-shell tests and analyze.

## Phase 1: Shell Decomposition Without UX Rewrite

- [x] Extract the brand mark into internal widgets with an official raster asset contract test.
- [x] Extract skeleton primitives into internal widgets with stable key and geometry contract tests.
- [x] Extract rows/chips and status transitions into internal widgets.
- [x] Add contract tests for remaining stable keys, reduced-motion behavior, and no layout-shift geometry.
- [x] Extract desktop sidebar behavior into a dedicated shell module with width/label-opacity/focus tests.
- [x] Keep Home/Locations/Rules/Account behavior unchanged while reducing `app_shell.dart` responsibility.

## Phase 2: Connect Ritual And Performance Guardrails

- [x] Isolate connect-disc state machine: idle, preparing, connecting, connected, disconnecting, reconnecting, error.
- [x] Add tests for finite sweep, press scale, connected settle, error settle, and reduced-motion fallback.
- [x] Wrap expensive animated regions in `RepaintBoundary`.
- [x] Add a local performance checklist for Windows and Android visual QA.

## Phase 3: In-App AI Assistant Contract

- [x] Define app-facing assistant contract as support-scoped, not a fifth top-level tab.
- [x] Add client models for assistant session, message, suggestion, diagnostic attachment, escalation, and safe action confirmation.
- [x] Add backend API plan for assistant sessions/messages/stream/status/escalate/actions if existing ticket APIs are not enough.
- [x] Add redaction and prompt-safety rules: no raw config, no keys, no hidden topology, no autonomous destructive actions.
- [x] Integrate support-scoped AI helper suggestions inside Support chat; live endpoint wiring remains a backend implementation slice.

## Phase 4: WARP Working-Feature Hardening

- [x] Keep public wording as `Расширенная защита` / `Расширенная приватность`; literal `WARP` stays advanced/support/internal unless clarity requires it.
- [x] Finish client-side WARP state machine: not ready, ready to consent, consented, active, degraded, fallback, revoked, error.
- [x] Persist consent through backend status plus safe local cache.
- [x] Ensure revoke clears local enabled state and restages the baseline route on the next connect; staged-material deletion proof remains in the runtime checklist.
- [x] Add support diagnostics redaction proof for WARP states and errors.
- [x] Add Android and Windows runtime proof checklist before any production-working claim.

## Phase 5: Premium UX Pass

- [x] Trim Account/Rewards/Rules first-layer text into Settings-style rows with values and chevrons.
- [x] Add skeletons that match final geometry for async account, rewards, locations, and support content.
- [x] Add tactile feedback on real rows/chips only.
- [x] Add Windows keyboard shortcuts and focus polish for navigation and support composer.
- [x] Add responsive/golden capture plan for `360`, `700`, `900`, `1024`, `1180`, `1440`.

## Phase 6: Release-Beta Evidence Refresh

- [x] Run focused Flutter tests for changed packages.
- [x] Run root client gate smoke where affected.
- [x] Rebuild Android APK and Windows unsigned beta artifacts only after implementation phases are green.
- [x] Update `docs/operations/cutover-readiness.md` and release handoff metadata with honest evidence.
- [x] Upload refreshed artifacts after the owner-approved downloadable prerelease request.

Phase 6 closed on `2026-06-05` for local code/docs/release evidence. Remaining
work is limited to accepted skips and manual gates: production Android signing,
trusted Windows signing, live install/app-session smoke, raw Android physical
audit replacement evidence, RU-origin proof if claimed, and production WARP
runtime proof.

## First Implementation Slice

Start with Phase 0 only:

1. [x] Add failing design-system contract tests.
2. [x] Add `PokrovPalette`, `PokrovMotionTokens`, and `PokrovMotionScope`.
3. [x] Update the existing shell to delegate private compatibility adapters to the new public contracts.
4. [x] Run focused tests.
5. [x] Mark Phase 0 progress in this plan and the docs index.
