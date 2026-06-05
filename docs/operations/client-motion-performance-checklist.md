# Client Motion Performance Checklist

Last updated: 2026-06-05

Use this checklist when refreshing the `1.0.0-beta` Android/Windows client after motion or connect-ritual changes.

## Scope

- Android outside-store APK visual QA.
- Windows unsigned beta visual QA.
- Shared Flutter shell surfaces: Protection, Locations, Rules, Profile, Support chat, Rewards, WARP / enhanced privacy tile.

## Required Viewports

- Android narrow: `360` logical px wide.
- Android wide/tablet preview: `700` logical px wide.
- Windows compact: `700` and `900` px wide.
- Windows desktop: `1024`, `1180`, and `1440` px wide.

## Connect Ritual

- Press feedback scales the connect disc immediately and settles without layout shift.
- Busy state uses a finite sweep, not an unbounded spinner.
- Connected state settles into `connect-disc-connected-settle`.
- Error/degraded state settles into `connect-disc-error-settle` with calm warning color.
- Reduced-motion mode keeps labels and state changes understandable without decorative movement.
- Connect disc animated region remains inside a `RepaintBoundary`.

## Shell Motion

- Sidebar collapse changes width and label opacity without shifting page content unexpectedly.
- Rows and chips use tactile feedback only on real interactive controls.
- Skeletons match final content geometry and do not resize surrounding layout.
- Disabled WARP, rewards, wheel, and calendar states stay muted and do not look like active CTAs.

## Evidence Notes

- Record platform, build type, viewport width, and changed screen.
- Keep screenshots free of raw configs, subscription links, keys, hostnames, or hidden topology.
- If performance tooling is available, capture whether animation stays near 60 FPS during connect, sidebar collapse, support chat open, and rewards hub open.
- If a check requires a physical device, record it as `MANUAL_OWNER_TEST` rather than blocking local code review.
