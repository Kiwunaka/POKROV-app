# Branding Assets

This lane carries repo-local generated brand assets for launcher and host icon
use.

Current source contract:

- platform manifest: `shared/redesign-assets.json` in the platform repository
- source id: `pokrov-vector-mark-2026-04-24`
- local in-app transparent mark: `pokrov-mark.png`
- launcher, tray, and Windows ICO exports are generated from the same root
  raster master with the calm rounded app-icon background applied during export
- root export matched by this file:
  `marketing/public/redesign/brand/pokrov-app-icon-1024.png`
- vector masters named by the manifest:
  `logo/logoclear.svg` and `logo/logowithtext.svg`

Keep future launcher/icon regeneration aligned to the platform manifest unless
the product team replaces the public POKROV mark.
