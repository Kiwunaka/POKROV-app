# P6 Overload UX Consilium

Date: 2026-06-05
Status: design correction / implementation input
Owner: POKROV-app/main

## Purpose

This note records the follow-up consilium after owner-side early feedback on
the P6 client build:

- too overloaded;
- unclear how to connect on the Home screen;
- inconsistent alignment;
- too many settings and recovery paths visible at once.

The pass compared the current implementation with the approved P5 application
map and the local P5/P6 design contracts.

Raw OpenCode outputs are retained as local scratch:

- `.tmp/p6-overload-review-minimax-m3.txt`
- `.tmp/p6-overload-review-qwen37max.txt`
- `.tmp/p6-overload-review-mimo25pro.txt`
- `.tmp/p6-overload-review-glm51.txt`
- `.tmp/p6-overload-review-deepseekv4pro.txt`

## Verdict

P6 drifted from the approved design map.

The implementation added many requested product surfaces, but the first layer
now reads like a feature panel instead of a calm premium connect client. The
map asked for one central connect object, one short status, and at most two
chips. Current Home carries brand, status, connect disc, three chips,
enhanced-protection tile, and a status paragraph.

This is not primarily a code-quality issue. It is an information-architecture
issue: advanced and account-adjacent decisions became visible before the
primary action.

## What The Map Had That P6 Lost

- One unmistakable connect disc as the only large action.
- One short status line, not a status paragraph.
- Maximum two Home chips; overflow belongs in a detail sheet.
- Enhanced protection as a quiet gated state, not a full Home tile.
- iOS Settings-like rows for Account, Rules, Locations, Rewards, and Support.
- Motion that clarifies action state: press scale, finite ring sweep, settle,
  status crossfade, skeletons, and row feedback.
- Desktop shell where the centered connect stage remains dominant at every
  width.

## Confirmed Problems

### Home

Current Home has too many first-layer elements:

1. brand lockup;
2. status dot label;
3. connect orb;
4. location chip;
5. route-mode chip;
6. platform chip;
7. enhanced-protection tile;
8. status summary text.

The platform chip is not a Home decision. The enhanced-protection tile competes
with the connect disc. The status summary turns the Home screen into product
documentation.

### First Launch

The first-launch choice screen blocks the connect moment. On a narrow Windows
capture, the title text is horizontally clipped. That makes the first
interaction feel both bureaucratic and fragile.

The question is product-valid, but the presentation is too heavy:

- large question;
- explanatory subtitle;
- two large option cards;
- restore path with input, primary action, Telegram/cabinet actions, and a
  warning panel.

### Account And Settings

Account currently exposes too many flows at the same level. Restore code,
Telegram, cabinet, email, bonuses, device information, support, and advanced
network behavior need a row hierarchy with nested sheets/screens.

### Windows Responsiveness

The current shell has breakpoints, but the narrow behavior still permits
content clipping and alignment drift. The app needs a strict responsive
contract from `360` through desktop widths, with no horizontal clipping.

## P0 Correction

### Home First Layer

The Home screen should show only:

1. compact brand/header;
2. one status line;
3. central connect disc;
4. two chips:
   - location;
   - route mode.

Move away from Home:

- platform chip -> Account / Device;
- enhanced-protection tile -> Advanced or a quiet state chip only when
  genuinely relevant;
- status summary -> connection details bottom sheet;
- recovery, Telegram, cabinet, email, bonuses -> Account.

Acceptance:

- first Home viewport has no paragraph text;
- Home has no more than two chips;
- no full-width enhanced-protection module on Home;
- tapping the disc is the obvious way to connect or disconnect;
- no separate filled connect button competes with the disc.

### First Launch

The first launch should not stand between the user and the connect moment.

Preferred P0 direction:

- show Home immediately;
- let the primary disc start the trial/new-user path;
- expose returning-user restore as a small banner, text link, or bottom sheet;
- restore screen/sheet contains one input and one primary action;
- Telegram and cabinet become secondary links, not equal CTAs;
- warnings move behind help text unless the user enters a raw key/manual mode.

Acceptance:

- at `360px` and `493px` width, no title or row clips horizontally;
- first screen makes the connect action visible;
- returning-user path remains discoverable but does not dominate new users.

### Responsive Baseline

Required widths:

- `360`;
- `493`;
- `700`;
- `900`;
- `1024`;
- `1180`;
- `1440`.

Acceptance:

- no horizontal scrolling;
- no clipped headings;
- Home stage remains centered;
- rows keep a consistent left grid;
- Windows drawer/sidebar state does not push the connect stage off-screen.

## P1 Correction

### Account / Settings IA

Use grouped rows with values and chevrons.

Recommended first-layer Account groups:

- Access:
  - subscription status;
  - renewal/payment;
  - cabinet.
- Recovery:
  - enter recovery code;
  - email;
  - Telegram link/bonus.
- Device:
  - current device;
  - device slots;
  - downloads.
- Help:
  - support chat;
  - diagnostics.
- Advanced:
  - enhanced protection;
  - compatibility core;
  - manual key/raw rules.

Rules:

- one title and one value per row;
- no inline long explanations on the first layer;
- dangerous/manual controls require an Advanced gate;
- chevrons indicate deeper screens or sheets.

### Rules And Locations

Rules and Locations should read as product rows, not explanatory cards.

- mode choice remains visible;
- explanations move to info sheets;
- selected-app picker gets its own route/sheet;
- locations list uses row rhythm with selected state, ping/load only when real.

## P2 Correction

### Motion And Premium Feel

Motion should clarify state, not decorate a crowded screen.

Keep:

- connect-disc press scale;
- finite ring sweep;
- connected/error settle;
- status crossfade;
- row/chip tactile feedback;
- geometry-matched skeletons;
- calm bottom-sheet transitions.

Avoid:

- permanent idle motion;
- decorative particles;
- broad shimmer everywhere;
- layout-property animation in hot paths;
- active-looking enhanced-protection states before proof.

Acceptance:

- connect transition is understandable without reading text;
- status changes do not resize or jump;
- skeletons match final row/card sizes;
- reduced-motion settings are respected.

## Implementation Order

1. Cut Home down to the connect disc, one status line, and two chips.
2. Replace first-launch full-screen gate with Home-first onboarding.
3. Add strict responsive checks and fix the `493px` clipping case.
4. Rebuild Account/Settings first layer as grouped rows.
5. Move enhanced protection to Advanced/bottom sheet unless it is a quiet state
   chip backed by current state.
6. Add motion polish only after the layout is quiet.

## Non-Negotiable Design Rule

The first thing a normal user must understand is:

> Tap the center disc to connect.

Everything else is secondary and must either be a small value chip, a row in
Account/Settings, or a bottom sheet opened by intent.
