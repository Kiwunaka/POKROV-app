# POKROV App Beta Evidence `0.2.0-beta.1+20260425`

Status: metadata-only paid beta evidence.

This folder records the W07 beta handoff contract for the active `POKROV-app` lane. It does not contain newly built binaries.

## Scope

- Android: internal beta only; public release blocked.
- Windows: gated unsigned beta artifact metadata; public release blocked.
- Version line: `0.2.0-beta.1`.

## Android Status

- APK distribution is allowed only to approved beta users.
- Public Android availability remains blocked until trusted signing and the physical-device localhost/control-surface audit pass.
- No Play or public mirror URL is approved in this metadata pass.

## Windows Status

- Windows artifact naming moves to `pokrov-windows-beta-x64-{version}` and `pokrov_windows_beta.exe`.
- The bundle is unsigned until a trusted code-signing certificate and timestamping path are provided.
- Beta users must see a Microsoft Defender SmartScreen or unknown-publisher warning before download/install.

## Client Contract Notes

- The client no longer sends caller-controlled `trial_days`; the backend owns trial duration.
- Checkout, cabinet downloads, support, community, feedback, and redeem actions hand off to safe external destinations.
- Selected apps is labeled as beta-limited route sync while picker and OS enforcement work remains open.

