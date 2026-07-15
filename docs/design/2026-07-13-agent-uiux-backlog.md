# Agent UI/UX Backlog — 12 Motion Concepts + HIG Critique (20)

Date: 2026-07-13
Status: active design backlog / working note (not in docs/README.md registry)
Owner: design/app-onboarding-uiux

## Provenance

Produced by agent critics in the 2026-07-12/13 design session ("отполирована по
агентским критикам"). The session summary reported ~12 of 32 items implemented;
the two source lists (12 motion concepts + 20 HIG improvements) lived only in
that session's context and are preserved verbatim below so the remaining items
with their file:line pointers are not lost.

Caveat: file:line references inside the verbatim lists describe the tree
*before* commit `10e98ee` (feat: polish shell to iOS-grade hero and chrome
fidelity) and have shifted slightly. The status table below was re-verified
against the worktree at `10e98ee` with current line numbers.

NTU = needs-test-update.

## Status @ 10e98ee + follow-up commits 2026-07-13 (verified in code)

Backlog complete: 20/20 HIG items and 12/12 motion concepts landed.

### HIG critique — 20 done

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Disc press compression (AnimatedScale) | DONE | shared/shell_widgets.dart:382 |
| 2 | Disc shadow / layering | DONE | shared/shell_widgets.dart:401 |
| 3 | Connected morph green inner plate | DONE | shared/shell_widgets.dart:450-456 |
| 4 | Haptics discipline (tap()=selectionClick, drop _emitPhaseHaptics) | DONE | resolved inside motion concept 1 (5cc1d01) as deferred: _emitPhaseHaptics deleted; the disc's whole phase budget is one success() at arc landing + a quiet tap() at rest, errors stay with snacks; _selectRouteMode got the standard selection tick |
| 5 | Hint pulse on sine | DONE | features/home/home_surface.dart |
| 6 | Busy not-warning + true ellipsis | DONE | both sites; no test pins |
| 7 | Status pill chevron (+ overflow fix) | DONE | features/home/home_surface.dart |
| 8 | Access label rendered twice | DONE | subtitle param removed — _HomeBrandHeader is a pure lockup; _HomeAccessStrip owns the label |
| 9 | Access badge gold → accent | DONE | features/home/home_surface.dart |
| 10 | Profile group inset separators | DONE | _SettingsRowDivider (indent 46) interleaved in account/support/settings/bonus groups, access overview and diagnostics sheet |
| 11 | Action rows accent verb values | DONE | PokrovSettingsRow.valueIsAction → accent+w600; applied to Привязать/Добавить/Управлять/Ввести/Продлить/Получить |
| 12 | Rules checkmarks instead of chevrons (NTU) | DONE | check_rounded morph in _RouteModeSegment (PokrovCheckRow recipe); test pin updated: check findsOneWidget, chevron findsNothing |
| 13 | Busy location rows dimming | DONE | IgnorePointer + Opacity(PokrovListRow.disabledOpacity) in _ClientLocationCityRow and _SmartConnectNodeRow |
| 14 | Sheet brisk exit (200ms easeInCubic) | DONE | shared/info_sheet.dart |
| 15 | Dark sheets elevation lift | DONE | bottomSheetTheme elevation 20 + Colors.black shadowColor (0.55 dark / 0.16 light), surfaceTintColor stays transparent |
| 16 | Dark tab bar black shadow | DONE | shell/navigation_shell.dart |
| 17 | Shield glyph + M3 pill | DONE | shield + transparent indicator |
| 18 | Skeletons instead of LinearProgressIndicator | DONE | first catalog load → _MotionSkeletonList(rows: 3); refresh-with-data and node apply → 16px CupertinoActivityIndicator trailing in the auto card |
| 19 | Onboarding choice tiles → compact rows | DONE | compact branch renders minHeight-72 rows (44 icon · title/subtitle · chevron); wide branch keeps cards; keys/strings unchanged |
| 20 | Referral card retint + action wrap + type tiers | DONE | reward tint 0.10/0.20; actions on their own Wrap row (survives 320pt); _SectionCard titles → titleMedium/w600 |

Verification for the 2026-07-13 follow-up waves: flutter analyze clean,
app_shell 162/162 green per wave (incl. updated rules and refresh pins).

### Motion concepts — 12 of 12 done (2026-07-13 wave)

| # | Concept | Commit |
| --- | --- | --- |
| 1 | Arc Handoff — busy sweep lands into the connected arc (shortest-path angle, sweep/stroke/color morph; settle constants in PokrovConnectDiscMotion) | 5cc1d01 |
| 2 | Soft Release — arc unwinds into its tail, border and compression spring back, quiet tap at rest | 5cc1d01 |
| 3 | Directional Tab Drift — 8px drift from the side of travel (vertical on desktop rail), tap tick on mobile bar | 4cbe4c2 |
| 4 | Two-Beat Snack — surface enters standard/emphasized, icon spring-pops ~40ms later via Interval | ae553af |
| 5 | Living Days Counter — profile pill and subscription sheet count old→new with per-frame RU plurals and a landing pulse | 8c86e7f |
| 6 | Claim Settle Bloom — bonus tile relaxes reward→surface, send→check morph, access badge spring bloom keyed on data | ae553af |
| 7 | Welcome Handover — reveal parked while the gate is up; gate exits fade+1.02 (user-driven only), reveal rises 80ms in | 0d9cfc4 |
| 8 | Signature-Arc Refresh — CupertinoSliverRefreshControl drawing the connected arc in profile and rewards | 12b21b4 |
| 9 | Pointer Grammar — material hover (tint+hairline border, no scale), sidebar indicator 20→24 spring, disc rim lift + focus ring | 6cbe931 |
| 10 | Status Ping — one expanding ring per phase-family change, keyed on color, no boot ping | 4cbe4c2 |
| 11 | Sheet Cascade — _SheetReveal (30ms stagger, cap 5) in info and subscription sheets | 8c86e7f |
| 12 | Consent Settle — WARP shield springs in on consent, off direction fades only, selection tick on tile taps | ae553af |

Suggested build order from the critique was honored: 1 → 7 → 4 → 6 → 2 → 9 → 5 → 3 → 10 → 12 → 11 → 8.
Commit `5ac80ac` (staged first-launch welcome reveal) was the pre-existing
groundwork for concept 7.

---

## Verbatim: 12 Motion Concepts

Research context: DESIGN.md, motion tokens, copy contract, connect disc
(state + painter), home surface, nav shell, snack/haptics, rewards, profile,
onboarding, controls. 12 concepts, all token-bound, loop-gated,
reduced-motion-safe, no new haptic tiers beyond the existing PokrovHaptics
wrappers (feature files never touch heavyImpact()).

### 1. Arc Handoff — connect morph · shell_widgets.dart (_ConnectDiscRimPainter, _ConnectOrbButtonState)

- (b) On connecting→connected: the spinning busy arc doesn't get swapped — it lands. Capture current sweep rotation, animate start-angle → connectedArcStartAngle (shortest path), sweep 0.86π→1.24π, stroke 3.2→3.1, color Color.lerp(accent → connectedGreen). standard 240, emphasized. Haptic: existing PokrovHaptics.success() at landing (already emitted on phase change — no double).
- (c) One-shot AnimationController armed only in didUpdateWidget on that specific transition; painter gains a settleT param + lerps. Finite forward() — safe under pumpAndSettle; reduced motion jumps to final arc.
- (d) The progress indicator becomes the connected state (Dynamic-Island-style continuity); connectedGreen arrives via the one sanctioned surface.
- (e) Angle wrap math (mod 2π shortest delta); ensure shouldRepaint covers settleT.

### 2. Soft Release — disconnect · same files

- (b) On connected→disconnecting: connected arc unwinds 1.24π→0 into its tail over standard 240 emphasized (visual overlay only, never delays real state), then existing busy sweep. On landing idle: single scale settle 0.985→1.0 with spring, border alpha eases 0.54→0.34. Haptic: PokrovHaptics.tap() on idle — an exhale, not a celebration.
- (c) Reuse concept-1 settle controller reversed; border via TweenAnimationBuilder<double> on running flip. All finite.
- (d) Disconnect currently just vanishes; a deliberate release reads intentional, and deliberately quieter than connect — honest hierarchy.
- (e) Runtime stop can resolve in <240ms; overlay must be cancelable mid-flight (animate from current value, never queue).

### 3. Directional Tab Drift — tab physics · navigation_shell.dart (_TabTransition)

- (b) Keep fade 0.92→1, short 180 emphasized, but offset becomes directional: mobile enters 8px from the side of travel (sign(new-old) * 8 * (1-t) horizontal); desktop sidebar uses the same 8px vertically. Add PokrovHaptics.tap() in onDestinationSelected.
- (c) _TabTransition stores oldIndex in didUpdateWidget; same single AnimationController. Zero new loops.
- (d) Motion confirms the spatial model of the tab row/rail (iPadOS sidebar feel) instead of a placeless rise; ≤8px keeps it fade-dominant, not a carousel.
- (e) Cheap-looking if amplitude creeps up — hard-cap 8px; instant under reduced motion (already handled).

### 4. Two-Beat Snack — snack entrance · pokrov_snack.dart

- (b) Beat 1: surface enters with AnimationStyle(duration: standard 240, curve: emphasized) via showSnackBar's snackBarAnimationStyle, exit quick 120 ease. Beat 2: the tone icon scale-springs 0.6→1 (short 180, spring) starting ~40ms after mount. Haptics unchanged (success/danger already tiered).
- (c) TweenAnimationBuilder around the leading Icon inside content (finite); AnimationStyle param on the messenger call.
- (d) Surface-then-content layered timing is the core Apple choreography trick; icon overshoot gives tactility with zero extra ink.
- (e) snackBarAnimationStyle needs Flutter ≥3.22 — pubspec only pins Dart ≥3.0; verify toolchain, else ship icon-spring only (works everywhere).

### 5. Living Days Counter — subscription moment · profile_surface.dart (_ProfileAccessOverview pill + Осталось дней in _showSubscriptionSheet)

- (b) First time Profile becomes visible per session (and whenever daysLeft changes, e.g. +10 claim): count old→new over homeReveal 480 emphasized, then one 1.0→1.04→1.0 pulse (quick 120, spring) on the final digit. No haptic (passive display).
- (c) TweenAnimationBuilder<double> keyed by target value, Text('${value.round()}') recomputing ruDays per tick; guard with last-animated value in state so rebuilds don't replay. Static under reduced motion.
- (d) Screen-Time/Fitness-style count-up makes the entitlement feel alive and owned — the number is real, only its arrival is staged (copy-contract clean).
- (e) RU plural form must track the interpolated value each frame, not the target; keep count-up off when value is 0 (never dramatize bad news).

### 6. Claim Settle Bloom — rewards claim · home_surface.dart (_HomeTelegramBonusTile, _HomeAccessStrip), seed_shell.dart claim paths

- (b) When channelBonusClaimedAt flips empty→set (or wheel/calendar days land): tile background reward-tint→surface via AnimatedContainer standard 240 emphasized; leading icon morphs send→check with the existing _copyMorphIcon recipe (quick 120 in, spring); the +10 дней pill does one spring overshoot scale (240, spring — the curve's 1.36 overshoot is the bloom). Haptic: none extra — success snack already fires PokrovHaptics.success().
- (c) AnimatedSwitcher + AnimatedContainer + one TweenAnimationBuilder; key replay-guard on the claimed-at string in shell state.
- (d) The surface you acted on acknowledges in place — reward without casino energy, exactly what the copy contract polices for.
- (e) Claim resolves while the rewards sheet is popping; the settle must key off data change, not tap, so it plays wherever the tile is visible.

### 7. Welcome Handover — first launch → home · seed_shell.dart (~line 2355) + home_surface.dart (_HomeStageState)

- (b) Today the gate is removed instantly and the 480ms home reveal already burned at boot underneath it. Fix: (1) hold _revealController at 0 while _firstLaunchStep != ready (new bool prop into _HomeStage); (2) gate exits via fade + 1.0→1.02 scale, standard 240 emphasized; (3) home's staggered homeReveal 480 starts ~80ms into the exit. Welcome card's _BrandLockup and _HomeBrandHeader are the same lockup near the same top-center position — the crossfade reads as one brand mark persisting (hero-without-Hero).
- (c) Wrap the gate slot in AnimatedSwitcher (fade+scale builder); arm reveal in didUpdateWidget when the prop flips. All finite.
- (d) Onboarding→product continuity is the single strongest "expensive" signal (Apple setup flows never hard-cut); the disc rising right after the promise "включите VPN за один шаг" lands the narrative.
- (e) Both paths (new user + restore success) must route through the same exit; don't start reveal before the gate scrim is ≥50% gone or the disc pops through frosted canvas.

### 8. Signature-Arc Refresh — pull-to-refresh · profile_surface.dart, rewards_hub.dart

- (b) Replace stock RefreshIndicator with the product's own arc: while dragging, a 22px arc draws in proportionally (sweep = drag% × 1.24π — same geometry as the connected arc); armed → arc rotates (existing 1250ms sweep pattern) until the real Future completes; settle: arc fades quick 120. PokrovHaptics.tap() at the arm threshold.
- (c) CustomScrollView + CupertinoSliverRefreshControl(builder:) painting via PokrovConnectDiscMotion constants (physics are already Bouncing everywhere); rotation loop behind PokrovLoopingMotion.enabled (progress, not decoration — still collapses under test).
- (d) One signature shape (the connect arc) becomes the refresh language app-wide — Apple's activity-ring consistency trick; the drag-proportional draw-in is direct manipulation.
- (e) Highest effort: Profile's _SeedContentList ListView→sliver refactor; keep the rewards sheet on a restyled stock indicator if scope bites.

### 9. Pointer Grammar — Windows hover · pokrov_controls.dart (PokrovSettingsRow, PokrovListRow), pokrov_sidebar.dart, shell_widgets.dart (disc)

- (b) Unified rules, all quick 120 standardEase: big surfaces (rows/cards) get tint (+2% ink bg) and border→accent@0.18 — no scale on large areas; chips/buttons keep existing 1.01 (PokrovHomeChip, PokrovPressable already do this); sidebar item's 2px indicator grows 20→24px with spring; connect disc hover raises rim base alpha +0.06 and shows a hairline focus ring at −4px inset. No haptics (pointer).
- (c) MouseRegion + AnimatedContainer following the existing PokrovHomeChip hover pattern; PokrovSettingsRow currently has cursor-only MouseRegion — extend it. No loops.
- (d) macOS grammar: material responds, geometry barely moves — hover-scale on large cards is precisely what looks gimmicky.
- (e) Touch-only devices unaffected (Flutter routes hover correctly); keep row hit-targets unchanged.

### 10. Status Ping — state-change pulse · pokrov_controls.dart (PokrovStatusDotLabel) via home_surface.dart

- (b) When the status phase-family changes (idle↔connected↔attention), the 8px dot emits one ring: scale 1→2.2, opacity 0.4→0, standard 240 emphasized; label crossfades with the existing fade-slide. No haptic (disc already owns that moment).
- (c) TweenAnimationBuilder keyed by a phase-family key (not the raw label string — headlines churn); ring in a Stack behind the dot. Single pass, no gate needed.
- (d) AirPods-connect language: a single soft ping says "state changed" without a persistent blinker.
- (e) Must not fire on text-only headline updates; key strictly on color/phase.

### 11. Sheet Cascade — sheet content stagger · info_sheet.dart + profile_surface.dart sheets

- (b) Sheet slides in per existing sheet 280 emphasized; rows inside fade + rise 6px, staggered 30ms per row (cap at 5 rows), each short 180 emphasized. No haptics.
- (c) Generalize onboarding's _FirstLaunchReveal into a _SheetReveal(order:) (TweenAnimationBuilder + Interval) — already proven finite/test-safe in this codebase.
- (d) Apple Wallet/App Store sheet feel: the container arrives, then content settles into it; makes dense subscription data feel curated.
- (e) Stagger tail must never exceed ~460ms total or sheets feel laggy; cap order and skip entirely under reduced motion.

### 12. Consent Settle — WARP toggle micro-moment · home_surface.dart (_HomeWarpTile)

- (b) On consent→on: tile tint animates (already AnimatedContainer 180) and the icon container does one 0.9→1.0 scale with spring over short 180 as blur_on→verified_user swaps; PokrovHaptics.tap() on toggle. Off-direction: fade only, no spring (again: quieter for downgrades).
- (c) AnimatedSwitcher around the icon Container with ScaleTransition (spring in-curve) — mirrors the rewards copy-morph recipe.
- (d) The switch track already carries connectedGreen; the icon settle makes the promise ("включится при следующем подключении") feel committed, honestly — nothing claims it's active yet.
- (e) Trivial; only guard against replay while busy flips during apply.

Cross-cutting note: concepts 1+2 share one settle controller; 5+6 share the
replay-guard pattern (animate on data delta, not rebuild); every duration/curve
above is an existing PokrovMotionTokens value, so nothing new enters the token
file except possibly the arc-settle constants, which belong in
PokrovConnectDiscMotion. Suggested build order by payoff/effort:
1 → 7 → 4 → 6 → 2 → 9 → 5 → 3 → 10 → 12 → 11 → 8.

---

## Verbatim: POKROV HIG Critique — 20 improvements

Paths relative to packages/app_shell/lib/src/. NTU = needs-test-update.
Line numbers as of the pre-10e98ee tree.

### Connect-disc hero

1. Disc press snaps instead of compressing — shared/shell_widgets.dart:365-378. _pressed flips Transform.scale 1.0→0.97 in a raw rebuild (the AnimatedBuilder only listens to breath/sweep). Wrap the disc Container (line 379) in AnimatedScale(scale: _pressed ? PokrovConnectDiscMotion.pressScale : 1, duration: motion.duration(PokrovMotionTokens.quick), curve: _pressed ? Curves.easeIn : PokrovMotionTokens.spring) and drop pressed from PokrovConnectDiscMotion.scale. HIG: buttons feel physical — compression eases in, releases with spring; the app's #1 affordance is its only unanimated press. Risk: NTU — design_system_contract_test.dart:396-405 pins scale(pressed:). **[DONE @ 10e98ee]**
2. Disc is flat — no layering — shared/shell_widgets.dart:382-390. Add to the decoration: boxShadow: [BoxShadow(color: (running ? accent : p.ink).withValues(alpha: isDark ? 0.35 : (running ? 0.20 : 0.08)), blurRadius: 30, offset: Offset(0, 12))] (black-based in dark). HIG: depth communicates the primary interactive layer; hero controls float above the canvas. Risk: safe. **[DONE @ 10e98ee]**
3. Connected morph is a hairline, not a moment — shared/shell_widgets.dart:424-431. Inner circle stays p.canvas in every phase. Make it AnimatedContainer (_MotionTokens.standard, ease): running ? Color.alphaBlend(p.connectedGreen.withValues(alpha: 0.10), p.canvas) : p.canvas. Canon-legal (disc is the sanctioned connectedGreen surface). HIG: state must be glanceable, not forensic. Risk: safe. **[DONE @ 10e98ee]**
4. Haptics off-discipline — shared/shell_widgets.dart:347 fires lightImpact per tap; :205-228 fires mediumImpact/heavyImpact on phase change (shared/pokrov_haptics.dart:14-20). Replace tap with PokrovHaptics.tap() (selectionClick), delete _emitPhaseHaptics, and add the missing HapticFeedback.selectionClick() to _selectRouteMode (shell/seed_shell.dart:542-547) to match theme (:52) and location (:556) picks. HIG: haptics sparse and same-class-consistent; selectionClick only per canon ("calm, not casino"). Risk: safe (heavyImpact( literal leaves the codebase entirely). **[DONE — resolved inside motion concept 1 (5cc1d01): one success() at landing, quiet tap() at rest, errors stay with snacks]**
5. Hint pulse pops each loop — features/home/home_surface.dart:1472-1487. opacity: (1 - progress) * 0.35 starts at 0.35 hard every 2.4 s. Use opacity: math.sin(math.pi * progress) * 0.35. HIG motion: continuous, no discontinuities in an attention loop. Risk: safe. **[DONE @ 10e98ee]**

### Status discipline

6. Busy state dressed as a warning — features/home/home_surface.dart:66-72. runtimeBusy ? p.warning paints normal progress amber. Use p.muted (transitional = neutral); reserve warning for degraded/error. Also replace three-dot 'Подключается...' with true ellipsis 'Подключается…' at :74 and :1112. HIG: warning hues mean problems; … is baseline typographic polish. Risk: safe (Подключается absent from pokrov_seed_app_test.dart pins — re-grep before merge). **[DONE — :74 @ 10e98ee; :1126 fixed in follow-up]**
7. Status pill hides its tappability — features/home/home_surface.dart:652-665. InkWell (key home-connection-details-action) shows only dot+label. Append Icon(Icons.chevron_right_rounded, size: 16, color: p.muted.withValues(alpha: 0.6)) inside the padding row. HIG: interactive elements must look interactive. Risk: safe (key/strings kept). **[DONE @ 10e98ee + overflow fix]**
8. Access label rendered twice on one screen — features/home/home_surface.dart:283-286 (_HomeBrandHeader(subtitle: widget.accessLabel)) duplicates _HomeAccessStrip's title (:356-360). Pass subtitle: null on mobile. HIG: economy of information; calm means saying it once. Risk: safe. **[DONE — follow-up 2026-07-13; subtitle param removed entirely]**
9. Amber creep — features/home/home_surface.dart:786. Access badge tone: _SectionTone.reward puts a third gold element above the fold. Change to _SectionTone.accent; keep reward tint solely on the Telegram bonus tile. HIG: one color = one meaning. Risk: safe. **[DONE @ 10e98ee]**

### Grouped-list fidelity

10. Profile groups have no separators — features/profile/profile_surface.dart:180-233 (and every _SectionCard child Column): rows butt together. Interleave Divider(height: 1, thickness: 1, indent: 46, color: p.line) (34 icon + 12 gap), the exact pattern already in design_system/pokrov_controls.dart:120-127. HIG: grouped tables use inset hairlines aligned to text, not blank stacking. Risk: safe. **[DONE — follow-up 2026-07-13; _SettingsRowDivider, also in diagnostics sheet]**
11. Action rows look disabled — design_system/pokrov_controls.dart:827-836. Verb values ('Привязать', 'Ввести', 'Управлять') render muted w400 — the visual grammar of inert text. Add valueIsAction → color: tokens.accent, fontWeight: FontWeight.w600 when onTap != null and value is a verb. HIG: iOS Settings tints actionable text with the app accent. Risk: safe (color only). **[DONE — follow-up 2026-07-13; valueIsAction opt-in]**
12. Route-mode rows lie with chevrons — features/rules/rules_surface.dart:242-248. Radio-style choices show chevron_right_rounded (= navigation). Replace with the PokrovCheckRow morph (pokrov_controls.dart:540-554): AnimatedScale 0.4→1 spring + fade Icons.check_rounded accent, reserving 22 px. HIG: chevron promises a push; checkmark states a selection. Risk: NTU — pokrov_seed_app_test.dart:3924-3930 pins the chevron inside rules-mode-row-allExceptRu. **[DONE — follow-up 2026-07-13; pin updated: check findsOneWidget + chevron findsNothing]**
13. Busy location rows go silently dead — features/locations/locations_surface.dart:466-469 and :565-568: if (disabled) return content; with zero dimming. Return IgnorePointer(child: Opacity(opacity: PokrovListRow.disabledOpacity, child: content)). HIG: never leave live-looking dead controls. Risk: safe. **[DONE — follow-up 2026-07-13]**

### Sheets & dark elevation

14. Sheet exit mirrors its entrance — shared/info_sheet.dart:23-28. 280 ms emphasized both ways. Set reverseDuration: Duration(milliseconds: 200), reverseCurve: Curves.easeInCubic. HIG: present gently, dismiss briskly — symmetric sheets feel sluggish. Risk: safe. **[DONE @ 10e98ee]**
15. Dark sheets don't lift — shell/seed_shell.dart:268-274. surfaceElevated #182019 vs surface #161D1A is ~invisible and elevation: 0. Keep palette (contract-locked); add elevation: 20, shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.16) with surfaceTintColor still transparent. HIG dark mode: elevated layers must visibly separate. Risk: safe. **[DONE — follow-up 2026-07-13]**
16. White "shadow" under dark tab bar — shell/navigation_shell.dart:193-199. BoxShadow(color: p.ink.withValues(alpha: 0.06)) — ink is near-white in dark, producing a glow. Use (isDark ? Colors.black : p.ink).withValues(alpha: isDark ? 0.35 : 0.06). HIG: shadows darken; they never emit. Risk: safe. **[DONE @ 10e98ee]**

### Chrome & tabs

17. M3 pill + wrong protection glyph — shell/seed_shell.dart:174-175: set indicatorColor: Colors.transparent (selection reads from the already-themed accent icon + ink label, :177-195) — iOS tab bars mark selection by tint, not a stadium. And shell/navigation_shell.dart:206-211 + :256-261: flash_on says "boost", not "Защита"; swap to Icons.shield_outlined/Icons.shield_rounded (keys nav-protection unchanged; no byIcon(flash_on) pins). Risk: safe. **[DONE — shield @ 10e98ee; indicator transparent in follow-up]**

### Loading / empty / onboarding / rewards / type

18. Material progress bars in an iOS shell — features/locations/locations_surface.dart:134-137 and :360-363. Empty + busy → _MotionSkeletonList(rows: 3); refreshing-with-data → 16 px CupertinoActivityIndicator trailing in the auto card. HIG: indeterminate linear bars are foreign to iOS; skeletons also stay loop-gated under flutter test (the indeterminate bar never settles). Risk: safe (no byType(LinearProgressIndicator) pins). **[DONE — follow-up 2026-07-13; skeleton on first load, Cupertino spinner on refresh]**
19. Onboarding choice tiles are hollow towers on phones — features/onboarding/onboarding_flow.dart:426 (minHeight: 150) + :464 (fixed SizedBox(height: 34)). In the compact branch render rows: Row(44 icon, 12, Expanded(title titleMedium + subtitle bodySmall), chevron), minHeight: 72, spacer removed. HIG: choices on phones are comfortable rows within thumb reach, not dead-space cards. Risk: safe (keys first-launch-new-user/-returning-user and pinned strings unchanged). **[DONE — follow-up 2026-07-13; compact branch only, wide keeps cards]**
20. Referral card: warning tint + 3 inline actions — features/rewards/rewards_hub.dart:889-897 amber p.warning container for a reward feature; :898-961 icon+code+button+2 icon-buttons in one row overflows near 320 pt. Retint to p.reward.withValues(alpha: 0.10) / border 0.20; move the three keyed actions to a second Wrap(spacing: 8) row. Bonus tier fix: shared/shell_widgets.dart:51-56 — card titles titleLarge(19/w700) sit 1 px under page headers headlineSmall(20); drop card titles to titleMedium(16/w600) for two honest tiers. HIG: color semantics, resilient layout, distinct type hierarchy. Risk: safe (rewards-referral-copy-action copy→check morph widgets preserved, test :2408-2430). **[DONE — follow-up 2026-07-13; all three parts incl. titleMedium card tier]**

Sharpest wins for "premium in one day" (per the critique): 1, 2, 3 (the hero
finally feels alive), 10, 12 (grouped-list honesty), 15, 16 (dark mode stops
looking web-made). All closed as of 2026-07-13; the haptics item (4) landed
with the Arc Handoff wave the same day.
